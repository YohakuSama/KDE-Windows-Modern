/*
    Windows 11 defaults for which tray icons show, and in what order.

    SPDX-FileCopyrightText: 2026 Jeysef
    SPDX-License-Identifier: GPL-2.0-or-later
*/
#pragma once

#include <Plasma/Plasma>
#include <QDir>
#include <QFile>
#include <QList>
#include <QString>

namespace WindowsTray
{
// Windows 11 ends the tray with these, left to right, right before the clock:
// input language, network, volume, battery.
inline const QList<QString> &tail()
{
    static const QList<QString> ids = {
        QStringLiteral("org.kde.plasma.keyboardlayout"),
        QStringLiteral("org.kde.plasma.networkmanagement"),
        QStringLiteral("org.kde.plasma.volume"),
        QStringLiteral("org.kde.plasma.battery"),
    };
    return ids;
}

// Privacy indicators are distinct from pinned/background applications.
inline bool privacyIndicator(const QString &itemId)
{
    return itemId == QLatin1String("org.kde.plasma.cameraindicator");
}

// Fcitx registers the stable StatusNotifierItem Id "Fcitx".
inline bool inputMethodIndicator(const QString &itemId)
{
    return itemId.compare(QLatin1String("Fcitx"), Qt::CaseInsensitive) == 0
        || itemId.compare(QLatin1String("Fcitx5"), Qt::CaseInsensitive) == 0;
}

// -1: ordinary visible applications/devices; 0: privacy; 1+: fixed core.
inline int systemOrder(const QString &itemId)
{
    if (privacyIndicator(itemId)) return 0;
    if (inputMethodIndicator(itemId)) return 1;
    const int index = tail().indexOf(itemId);
    return index < 0 ? -1 : index + 1;
}

// True on laptops: the kernel lists a system battery (not a mouse's or a
// headset's, whose scope is "Device").
inline bool hasSystemBattery()
{
    static const bool found = [] {
        const QDir supplies(QStringLiteral("/sys/class/power_supply"));
        for (const QString &name : supplies.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
            QFile type(supplies.filePath(name + QStringLiteral("/type")));
            QFile scope(supplies.filePath(name + QStringLiteral("/scope")));
            const bool isBattery = type.open(QIODevice::ReadOnly) && type.readAll().trimmed() == "Battery";
            const bool isPeripheral = scope.open(QIODevice::ReadOnly) && scope.readAll().trimmed() == "Device";
            if (isBattery && !isPeripheral) {
                return true;
            }
        }
        return false;
    }();
    return found;
}

// Always in the tray on Windows while they exist, even when Plasma marks
// them passive (the battery does when full and on the charger). The input
// language is left out: Windows hides it too when there is only one.
inline bool alwaysShown(const QString &itemId)
{
    if (itemId == QLatin1String("org.kde.plasma.battery")) {
        return hasSystemBattery();
    }
    return itemId == QLatin1String("org.kde.plasma.networkmanagement")
        || itemId == QLatin1String("org.kde.plasma.volume");
}

// Icons that appear in the tray without being pinned. Core controls
// have exactly one visible entry; auxiliary apps can live in overflow.
inline bool shownByDefault(const QString &itemId)
{
    // The clock owns notification history, and Quick Settings owns brightness.
    return inputMethodIndicator(itemId) || tail().contains(itemId)
        || itemId == QLatin1String("org.kde.plasma.cameraindicator"); // privacy: camera in use
}
inline Plasma::Types::ItemStatus effectiveStatus(const QString &itemId, Plasma::Types::ItemStatus status,
                                                bool eligible, bool pinned, bool hiddenByUser)
{
    using Status = Plasma::Types::ItemStatus;
    // Do not bury the live privacy indicator in overflow, even if an
    // older saved configuration forced it there. Do not show an idle one.
    if (privacyIndicator(itemId)) {
        return eligible && (status == Status::ActiveStatus || status == Status::NeedsAttentionStatus
                            || status == Status::RequiresAttentionStatus)
            ? Status::ActiveStatus : Status::HiddenStatus;
    }
    if (!eligible) {
        return Status::HiddenStatus;
    }
    // Hide redundant delegates, not the native applets/backends. The
    // notification applet still presents real desktop toast notifications.
    if (itemId == QLatin1String("org.kde.plasma.notifications")
        || itemId == QLatin1String("org.kde.plasma.brightness")) {
        return Status::HiddenStatus;
    }
    if (itemId == QLatin1String("org.kde.plasma.battery")) {
        return hasSystemBattery() ? Status::ActiveStatus : Status::HiddenStatus;
    }
    if (alwaysShown(itemId)) {
        return Status::ActiveStatus;
    }
    if (!pinned && status == Status::HiddenStatus) {
        return Status::HiddenStatus;
    }
    // Passive native device applets are not overflow decorations. Keep
    // their backends loaded; show them when used or explicitly configured.
    const bool idleDevice = itemId == QLatin1String("org.kde.plasma.bluetooth")
        || itemId == QLatin1String("org.kde.plasma.devicenotifier")
        || itemId == QLatin1String("org.kde.plasma.clipboard");
    if (idleDevice && !pinned && !hiddenByUser
        && (status == Status::PassiveStatus || status == Status::UnknownStatus)) {
        return Status::HiddenStatus;
    }
    const bool optionalIdle = itemId == QLatin1String("org.kde.plasma.userswitcher")
        || itemId == QLatin1String("org.kde.plasma.weather")
        || itemId == QLatin1String("org.kde.plasma.keyboardindicator");
    if (optionalIdle && !pinned && !hiddenByUser
        && status != Status::NeedsAttentionStatus && status != Status::RequiresAttentionStatus
        && status != Status::AcceptingInputStatus) {
        return Status::HiddenStatus;
    }
    if (pinned) {
        return Status::ActiveStatus;
    }
    if (hiddenByUser) {
        return Status::PassiveStatus;
    }
    const bool dynamicDevice = itemId == QLatin1String("org.kde.plasma.bluetooth")
        || itemId == QLatin1String("org.kde.plasma.devicenotifier");
    const bool needsAttention = status == Status::NeedsAttentionStatus || status == Status::RequiresAttentionStatus
        || status == Status::AcceptingInputStatus;
    const bool activeDefault = (status == Status::ActiveStatus || status == Status::UnknownStatus) && shownByDefault(itemId);
    if (needsAttention || activeDefault || (dynamicDevice && status == Status::ActiveStatus) || alwaysShown(itemId)) {
        return Status::ActiveStatus;
    }
    return Status::PassiveStatus;
}
}
