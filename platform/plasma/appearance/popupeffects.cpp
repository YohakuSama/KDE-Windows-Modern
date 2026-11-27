// SPDX-FileCopyrightText: 2015 Marco Martin <mart@kde.org>
// SPDX-License-Identifier: GPL-2.0-or-later
#include "popupeffects.h"

#include <cmath>

#include <QPainterPath>
#include <QQuickItem>
#include <QQuickWindow>
#include <QRegion>

#include <KConfig>
#include <KConfigGroup>
#include <KSharedConfig>
#include <KWindowEffects>

using namespace Qt::StringLiterals;

void PopupEffects::startMonitoring()
{
    if (m_blurConfigWatcher)
        return;
    // KConfig notifications are event driven; do not alter KWin's settings.
    m_blurConfigWatcher = KConfigWatcher::create(
        KSharedConfig::openConfig(QStringLiteral("kwinrc"), KConfig::NoGlobals));
    connect(m_blurConfigWatcher.data(), &KConfigWatcher::configChanged, this,
            [this](const KConfigGroup &group, const QByteArrayList &names) {
        if (group.name() == u"Plugins" && names.contains(QByteArrayLiteral("blurEnabled"))) {
            Q_EMIT preferencesChanged();
        }
    });
}

void PopupEffects::setNotificationPopupSlide(QQuickItem *content)
{
    // Keep the native shell positioning and let KWin animate the actual
    // window. Only the notification flyout uses this independent edge.
    if (auto *window = content ? content->window() : nullptr) {
        KWindowEffects::slideWindow(window, KWindowEffects::RightEdge, -1);
    }
}

bool PopupEffects::setSplitPopupBlur(QQuickItem *content, QQuickItem *first, QQuickItem *second,
                                   qreal radius, bool enabled)
{
    auto *window = content ? content->window() : nullptr;
    if (!window || !window->isVisible()) {
        return false;
    }
    // Honor the actual compositor/user setting. Never advertise an
    // acrylic surface when blur is unavailable or disabled.
    KConfig config(QStringLiteral("kwinrc"), KConfig::NoGlobals);
    enabled = enabled && KConfigGroup(&config, QStringLiteral("Plugins")).readEntry("blurEnabled", true)
        && KWindowEffects::isEffectAvailable(KWindowEffects::BlurBehind);
    const QRect windowRect(QPoint(0, 0), window->size());
    const QRectF windowBounds(windowRect);
    enabled = enabled && !windowRect.isEmpty() && std::isfinite(radius) && radius >= 0;
    QRegion mask;
    if (enabled) {
        QPainterPath clip;
        clip.addRect(windowBounds);
        for (auto *item : {first, second}) {
            if (!item || item->window() != window || !item->isVisible()) {
                enabled = false;
                break;
            }
            const QRectF bounds = item->mapRectToScene(item->boundingRect());
            if (!bounds.isValid() || !std::isfinite(bounds.left()) || !std::isfinite(bounds.top())
                || !std::isfinite(bounds.right()) || !std::isfinite(bounds.bottom())
                || !bounds.intersects(windowBounds)) {
                enabled = false;
                break;
            }
            // Use window-local logical pixels, including fractional scales.
            // Match Rectangle's radius limit; clip before integer conversion.
            const qreal corner = qMin(radius, qMin(bounds.width(), bounds.height()) / 2);
            QPainterPath path;
            path.addRoundedRect(bounds, corner, corner);
            if (!windowBounds.contains(bounds)) {
                path = path.intersected(clip);
            }
            const QRegion card = QRegion(path.toFillPolygon().toPolygon(), Qt::WindingFill)
                .intersected(windowRect);
            if (card.isEmpty()) {
                enabled = false;
                break;
            }
            mask |= card;
            if (first == second) {
                break;
            }
        }
    }
    // An empty QRegion means whole-window blur in KWindowEffects.
    // Explicitly disable in that case so the desktop gap stays clear.
    enabled = enabled && !mask.isEmpty();
    KWindowEffects::enableBlurBehind(window, enabled, enabled ? mask : QRegion());
    return enabled;
}
