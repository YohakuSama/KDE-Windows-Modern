// SPDX-FileCopyrightText: 2015 Marco Martin <mart@kde.org>
// SPDX-License-Identifier: GPL-2.0-or-later
#include "popupeffects.h"

#include <cmath>

#include <QDir>
#include <QFileInfo>
#include <QPainterPath>
#include <QQuickItem>
#include <QQuickWindow>
#include <QRegion>
#include <QSet>
#include <QStandardPaths>

#include <KConfig>
#include <KConfigGroup>
#include <KSharedConfig>
#include <KWindowEffects>

using namespace Qt::StringLiterals;

bool PopupEffects::transparencyEffectsEnabled()
{
    const QString dataDir = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    for (const QString &candidate : {
        dataDir.isEmpty() ? QString() : dataDir + u"/windows-modern/transparency-off"_s,
        QDir::homePath() + u"/.local/share/windows-modern/transparency-off"_s,
    }) {
        if (candidate.isEmpty())
            continue;
        const QFileInfo info(candidate);
        if (info.exists() || info.isSymLink())
            return false;
    }
    return true;
}

void PopupEffects::refreshTransparencyWatch()
{
    QSet<QString> wanted;
    const QString dataDir = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    for (const QString &base : {dataDir, QDir::homePath() + u"/.local/share"_s}) {
        if (base.isEmpty())
            continue;
        const QString wmDir = base + u"/windows-modern"_s;
        const QString marker = wmDir + u"/transparency-off"_s;
        if (QFileInfo(marker).isFile())
            wanted.insert(marker);
        if (QFileInfo(wmDir).isDir())
            wanted.insert(wmDir);
        else if (QFileInfo(base).isDir())
            wanted.insert(base);
    }
    const auto current = m_transparencyWatcher.files() + m_transparencyWatcher.directories();
    for (const auto &path : current) {
        if (!wanted.remove(path))
            m_transparencyWatcher.removePath(path);
    }
    if (!wanted.isEmpty())
        m_transparencyWatcher.addPaths(wanted.values());
}

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
    auto onTransparencyChanged = [this](const QString &) {
        refreshTransparencyWatch();
        Q_EMIT preferencesChanged();
    };
    connect(&m_transparencyWatcher, &QFileSystemWatcher::fileChanged, this, onTransparencyChanged);
    connect(&m_transparencyWatcher, &QFileSystemWatcher::directoryChanged, this, onTransparencyChanged);
    refreshTransparencyWatch();
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
    // Honor both the Windows Modern transparency-off marker and the actual
    // compositor/user blur setting. Never advertise Acrylic when disabled.
    KConfig config(QStringLiteral("kwinrc"), KConfig::NoGlobals);
    enabled = enabled && transparencyEffectsEnabled()
        && KConfigGroup(&config, QStringLiteral("Plugins")).readEntry("blurEnabled", true)
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
