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

// True on laptops: the kernel lists a system battery (not a mouse's or a
// headset's, whose scope is "Device").
inline bool hasSystemBattery()
{
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

// Pinning is independent of the default home of each shell function.
inline Plasma::Types::ItemStatus effectiveStatus(const QString &itemId, Plasma::Types::ItemStatus status,
                                                bool eligible, bool pinned, bool hiddenByUser,
                                                bool activeJobs = false, bool recording = false)
{
    using Status = Plasma::Types::ItemStatus;
    if (!eligible || (!pinned && status == Status::HiddenStatus)) {
        return Status::HiddenStatus;
    }
    if (pinned) {
        return Status::ActiveStatus;
    }
    if (hiddenByUser) {
        return Status::PassiveStatus;
    }
    if (itemId == QLatin1String("org.kde.plasma.notifications")) {
        // Win+N owns history. Native transfer controls only need a row during a job.
        return activeJobs ? Status::PassiveStatus : Status::HiddenStatus;
    }
    if (itemId == QLatin1String("org.kde.plasma.clipboard")
        || itemId == QLatin1String("org.kde.plasma.brightness")
        || itemId == QLatin1String("org.kde.plasma.mediacontroller")) {
        return Status::HiddenStatus;
    }
    const bool dynamicDevice = recording || itemId == QLatin1String("org.kde.plasma.cameraindicator")
        || itemId == QLatin1String("org.kde.plasma.bluetooth") || itemId == QLatin1String("org.kde.plasma.devicenotifier");
    const bool needsAttention = status == Status::NeedsAttentionStatus || status == Status::RequiresAttentionStatus
        || status == Status::AcceptingInputStatus;
    const bool activeDefault = (status == Status::ActiveStatus || status == Status::UnknownStatus) && tail().contains(itemId);
    if (needsAttention || activeDefault || (dynamicDevice && status == Status::ActiveStatus) || alwaysShown(itemId)) {
        return Status::ActiveStatus;
    }
    return dynamicDevice ? Status::HiddenStatus : Status::PassiveStatus;
}
}
