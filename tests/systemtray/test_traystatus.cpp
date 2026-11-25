// SPDX-License-Identifier: GPL-2.0-or-later
#include "../../plasma/applets/org.kde.windowsmodern.systemtray/windowstray.h"
#include <QDebug>
#include <QPainter>
#include "../../plasma/applets/org.kde.windowsmodern.systemtray/panelglyph.h"

int main()
{
    QImage padded(22, 22, QImage::Format_ARGB32);
    padded.fill(Qt::transparent);
    {
        QPainter painter(&padded);
        painter.fillRect(3, 4, 13, 14, Qt::white);
        // Preserve faint volume waves, unlike a threshold at 50% alpha.
        painter.fillRect(16, 4, 3, 14, QColor(255, 255, 255, 51));
    }
    const auto bounds = WindowsTray::panelGlyphBounds(padded);
    if (qAbs(bounds.width() - 16.0/22) > 0.00001
        || qAbs(bounds.center().x() - 0.5) > 0.00001)
        qFatal("Incorrect padded glyph optical bounds");
    QImage full(16, 16, QImage::Format_ARGB32);
    full.fill(Qt::white);
    if (WindowsTray::panelGlyphBounds(full) != QRectF(0, 0, 1, 1)
        || WindowsTray::panelGlyphBounds(QImage()) != QRectF(0, 0, 1, 1))
        qFatal("Incorrect full/empty glyph fallback");
    using Status = Plasma::Types::ItemStatus;
    auto check = [](const QString &id, Status raw, bool eligible, bool pinned, bool hidden, Status expected) {
        const auto actual = WindowsTray::effectiveStatus(id, raw, eligible, pinned, hidden);
        if (actual != expected) {
            qFatal() << id << raw << eligible << pinned << hidden << "expected" << expected << "got" << actual;
        }
    };
    for (const QString &id : {QStringLiteral("org.kde.plasma.bluetooth"), QStringLiteral("org.kde.plasma.devicenotifier")}) {
        check(id, Status::UnknownStatus, true, false, false, Status::HiddenStatus);
        check(id, Status::ActiveStatus, true, false, false, Status::ActiveStatus);
        check(id, Status::PassiveStatus, true, false, false, Status::HiddenStatus);
        check(id, Status::ActiveStatus, true, false, true, Status::PassiveStatus);
        check(id, Status::PassiveStatus, true, true, false, Status::ActiveStatus);
        check(id, Status::ActiveStatus, false, true, false, Status::HiddenStatus);
    }
    const QString clipboard = QStringLiteral("org.kde.plasma.clipboard");
    check(clipboard, Status::PassiveStatus, true, false, false, Status::HiddenStatus);
    check(clipboard, Status::UnknownStatus, true, false, false, Status::HiddenStatus);
    check(clipboard, Status::PassiveStatus, true, false, true, Status::HiddenStatus);
    check(clipboard, Status::PassiveStatus, true, true, false, Status::ActiveStatus);
    check(clipboard, Status::ActiveStatus, true, false, false, Status::PassiveStatus);
    const QString fcitx = QStringLiteral("Fcitx");
    check(fcitx, Status::ActiveStatus, true, false, false, Status::ActiveStatus);
    check(fcitx, Status::ActiveStatus, true, false, true, Status::PassiveStatus);
    Q_ASSERT(WindowsTray::systemOrder(fcitx) == WindowsTray::systemOrder(QStringLiteral("org.kde.plasma.keyboardlayout")));
    Q_ASSERT(WindowsTray::systemOrder(fcitx) < WindowsTray::systemOrder(QStringLiteral("org.kde.plasma.networkmanagement")));
    const QString camera = QStringLiteral("org.kde.plasma.cameraindicator");
    check(camera, Status::ActiveStatus, true, false, true, Status::ActiveStatus);
    check(camera, Status::PassiveStatus, true, true, false, Status::HiddenStatus);
    check(camera, Status::ActiveStatus, false, false, false, Status::HiddenStatus);
    Q_ASSERT(WindowsTray::systemOrder(QStringLiteral("example.sni")) < WindowsTray::systemOrder(camera));
    Q_ASSERT(WindowsTray::systemOrder(camera) < WindowsTray::systemOrder(QStringLiteral("org.kde.plasma.keyboardlayout")));
    check(QStringLiteral("example.sni"), Status::ActiveStatus, true, false, false, Status::PassiveStatus);
    check(QStringLiteral("example.sni"), Status::NeedsAttentionStatus, true, false, false, Status::ActiveStatus);
    check(QStringLiteral("example.sni"), Status::HiddenStatus, true, false, false, Status::HiddenStatus);
    check(QStringLiteral("org.kde.plasma.volume"), Status::PassiveStatus, true, false, false, Status::ActiveStatus);
    check(QStringLiteral("org.kde.plasma.notifications"), Status::NeedsAttentionStatus, true, false, false, Status::HiddenStatus);
    check(QStringLiteral("org.kde.plasma.notifications"), Status::ActiveStatus, true, true, false, Status::HiddenStatus);
    check(QStringLiteral("org.kde.plasma.brightness"), Status::ActiveStatus, true, true, false, Status::HiddenStatus);
    check(QStringLiteral("org.kde.plasma.volume"), Status::PassiveStatus, true, false, true, Status::ActiveStatus);
    check(QStringLiteral("org.kde.plasma.networkmanagement"), Status::PassiveStatus, true, false, true, Status::ActiveStatus);
    check(QStringLiteral("org.kde.plasma.userswitcher"), Status::ActiveStatus, true, false, false, Status::HiddenStatus);
    check(QStringLiteral("org.kde.plasma.weather"), Status::ActiveStatus, true, false, false, Status::HiddenStatus);
    check(QStringLiteral("org.kde.plasma.weather"), Status::ActiveStatus, true, false, true, Status::PassiveStatus);
    check(QStringLiteral("org.kde.plasma.keyboardindicator"), Status::NeedsAttentionStatus, true, false, false, Status::ActiveStatus);
}
