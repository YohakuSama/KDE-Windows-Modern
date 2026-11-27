// SPDX-License-Identifier: GPL-3.0-or-later
#include "chromeshadow.h"

#include <QGuiApplication>
#include <QImage>
#include <QWindow>
#include <QtMath>

namespace
{
// Match the existing Aurorae shadow extent and opacity. The compositor
// stretches straight tiles; corners share the same falloff at their seams.
KWindowShadowTile::Ptr tile(int width, int height, int padding, int peak,
                            bool corner, bool flipX, bool flipY)
{
    QImage image(width, height, QImage::Format_ARGB32_Premultiplied);
    for (int y = 0; y < height; ++y) {
        auto *pixels = reinterpret_cast<QRgb *>(image.scanLine(y));
        for (int x = 0; x < width; ++x) {
            const qreal dx = width == 1 ? 0 : (flipX ? x : width - 1 - x);
            const qreal dy = height == 1 ? 0 : (flipY ? y : height - 1 - y);
            const qreal distance = corner ? qSqrt(dx * dx + dy * dy) : qMax(dx, dy);
            const qreal t = qBound(qreal(0), 1 - distance / qMax(1, padding - 1), qreal(1));
            pixels[x] = qRgba(0, 0, 0, qRound(peak * t * t));
        }
    }
    auto result = KWindowShadowTile::Ptr::create();
    result->setImage(image);
    return result;
}
}

void ChromeShadow::clear()
{
    m_shadow.destroy();
    m_shadow.setWindow(nullptr);
    m_window.clear();
    m_attempted = false;
    m_padding = 0;
}

void ChromeShadow::update(QWindow *window, bool visible, bool active)
{
    if (!window || !visible || !window->isExposed()) {
        if (m_attempted)
            clear();
        return;
    }
    // X11's property is in native pixels. The Wayland shadow protocol uses
    // logical offsets and has no per-tile buffer scale negotiation.
    const qreal scale = QGuiApplication::platformName() == QStringLiteral("xcb")
        ? window->devicePixelRatio() : 1.0;
    const int padding = qMax(2, qRound(12 * scale));
    if (m_attempted && m_window.data() == window && m_padding == padding && m_active == active)
        return;
    clear();
    m_window = window;
    m_padding = padding;
    m_active = active;
    m_attempted = true;
    const int peak = active ? 71 : 41;
    m_shadow.setWindow(window);
    m_shadow.setPadding(QMargins(padding, padding, padding, padding));
    m_shadow.setTopTile(tile(1, padding, padding, peak, false, false, false));
    m_shadow.setBottomTile(tile(1, padding, padding, peak, false, false, true));
    m_shadow.setLeftTile(tile(padding, 1, padding, peak, false, false, false));
    m_shadow.setRightTile(tile(padding, 1, padding, peak, false, true, false));
    m_shadow.setTopLeftTile(tile(padding, padding, padding, peak, true, false, false));
    m_shadow.setTopRightTile(tile(padding, padding, padding, peak, true, true, false));
    m_shadow.setBottomLeftTile(tile(padding, padding, padding, peak, true, false, true));
    m_shadow.setBottomRightTile(tile(padding, padding, padding, peak, true, true, true));
    // On compositors without the protocol, the real window is unaffected.
    m_shadow.create();
}
