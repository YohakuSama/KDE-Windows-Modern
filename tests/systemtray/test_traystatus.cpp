// SPDX-License-Identifier: GPL-2.0-or-later
#include "../../plasma/applets/org.kde.windowsmodern.systemtray/windowstray.h"
#include <QDebug>

int main()
{
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
    check(QStringLiteral("example.sni"), Status::ActiveStatus, true, false, false, Status::PassiveStatus);
    check(QStringLiteral("example.sni"), Status::NeedsAttentionStatus, true, false, false, Status::ActiveStatus);
    check(QStringLiteral("example.sni"), Status::HiddenStatus, true, false, false, Status::HiddenStatus);
    check(QStringLiteral("org.kde.plasma.volume"), Status::PassiveStatus, true, false, false, Status::ActiveStatus);
    check(QStringLiteral("org.kde.plasma.notifications"), Status::NeedsAttentionStatus, true, false, false, Status::HiddenStatus);
    for (const QString &id : {QStringLiteral("org.kde.plasma.clipboard"), QStringLiteral("org.kde.plasma.mediacontroller"), QStringLiteral("org.kde.plasma.brightness")}) {
        check(id, Status::ActiveStatus, true, false, false, Status::HiddenStatus);
        check(id, Status::ActiveStatus, true, true, false, Status::ActiveStatus);
    }
    if (WindowsTray::effectiveStatus(QStringLiteral("org.kde.plasma.notifications"), Status::ActiveStatus, true, false, false, true) != Status::PassiveStatus
        || WindowsTray::effectiveStatus(QStringLiteral("Plasma_microphone"), Status::ActiveStatus, true, false, false, false, true) != Status::ActiveStatus) {
        qFatal("Live transfer or recording indicator lost");
    }
}
