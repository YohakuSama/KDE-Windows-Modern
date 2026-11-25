// SPDX-License-Identifier: GPL-2.0-or-later
#include "../../plasma/applets/org.kde.windowsmodern.systemtray/windowstray.h"
#include <QDebug>
#include <QPainter>
#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include "../../plasma/applets/org.kde.windowsmodern.systemtray/panelglyph.h"

int main(int argc, char **argv)
{
    QCoreApplication application(argc, argv);
    if (argc != 2) qFatal("Expected the bundled status icon directory");
    const QDir status(QString::fromLocal8Bit(argv[1]));
    for (const auto &name : {QStringLiteral("audio-volume-medium-symbolic.svg"),
                            QStringLiteral("audio-volume-high-symbolic.svg"),
                            QStringLiteral("network-wired-symbolic.svg"),
                            QStringLiteral("notifications-disabled-symbolic.svg")}) {
        const QString path = status.filePath(name);
        QImageReader reader(path);
        if (!reader.canRead() || reader.read().isNull())
            qFatal() << "Cannot rasterize bundled tray artwork" << path;
        const QRectF bounds = WindowsTray::panelGlyphFileBounds(path);
        const qreal extent = qMax(bounds.width(), bounds.height());
        if (extent < 0.65 || extent > 1.0001 ||
            qAbs(bounds.center().x() - 0.5) > 0.15 ||
            qAbs(bounds.center().y() - 0.5) > 0.15)
            qFatal() << "Unexpected optical extent or center" << name << bounds;
        // Same scale rule as the QML helper. Check physical ink after Qt
        // rasterization at 100%, 125%, 150%, 175% and 200%.
        const qreal factor = extent < 0.90 ? qMin(1.5, (23.0/24)/extent) : 1;
        for (const qreal scale : {1.0, 1.25, 1.5, 1.75, 2.0}) {
            const int canvas = qRound(16 * scale * factor);
            QImageReader atScale(path);
            const QSize intrinsic = atScale.size();
            atScale.setScaledSize(intrinsic.scaled(canvas, canvas, Qt::KeepAspectRatio));
            const QImage rendered = atScale.read();
            if (rendered.isNull()) qFatal() << "Scaled tray decode failed" << name << scale;
            const auto ink = WindowsTray::panelGlyphBounds(rendered);
            const qreal painted = qMax(ink.width(), ink.height()) * canvas;
            if (painted < 16 * scale * 0.85 - 1 || painted > 16 * scale + 1)
                qFatal() << "Scaled tray ink out of bounds" << name << scale << painted;
        }
    }
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
    for (const auto &id : {QStringLiteral("org.kde.plasma.networkmanagement"),
                           QStringLiteral("org.kde.plasma.volume"),
                           QStringLiteral("org.kde.plasma.battery"),
                           QStringLiteral("org.kde.plasma.notifications")}) {
        if (!WindowsTray::persistentApplet(id)) qFatal() << "Missing persistent applet" << id;
    }
    if (WindowsTray::persistentApplet(QStringLiteral("org.kde.plasma.bluetooth"))
        || WindowsTray::persistentApplet(QStringLiteral("org.kde.plasma.clipboard"))) {
        qFatal("Optional applets must remain optional");
    }
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
    const QString mic = QStringLiteral("org.kde.plasma.volume_microphone");
    const QString portal = QStringLiteral("xdg-desktop-portal-kde");
    const QString record = QStringLiteral("media-record");
    const QString hardware = QStringLiteral("Hardware");
    auto capture = [](const QString &exe, const QString &id, const QString &cat,
                      const QString &icon, bool expected) {
        if (WindowsTray::nativeCaptureIndicator(exe, id, cat, icon) != expected)
            qFatal() << "Incorrect native capture classification" << exe << id << cat << icon;
    };
    capture(QStringLiteral("plasmashell"), mic, hardware, {}, true);
    capture(QStringLiteral(".plasmashell-wrapped"), mic, hardware, {}, true);
    capture(QStringLiteral("plasmashell"), mic, QStringLiteral("ApplicationStatus"), {}, false);
    capture(portal, QStringLiteral("sharing"), {}, record, true);
    capture(QStringLiteral(".xdg-desktop-portal-kde-wrapped"), QStringLiteral("sharing"), {}, QStringLiteral("krfb"), true);
    capture(portal, QStringLiteral("sharing"), {}, QStringLiteral("configure"), false);
    capture(QStringLiteral("example-app"), mic, hardware, record, false);
    for (bool pinned : {false, true}) {
        for (bool hidden : {false, true}) {
            if (WindowsTray::effectiveStatus(mic, Status::ActiveStatus, true, pinned, hidden, true) != Status::ActiveStatus
                || WindowsTray::effectiveStatus(mic, Status::PassiveStatus, true, pinned, hidden, true) != Status::HiddenStatus
                || WindowsTray::effectiveStatus(mic, Status::ActiveStatus, false, pinned, hidden, true) != Status::HiddenStatus)
                qFatal("Incorrect live capture indicator visibility");
        }
    }
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
