// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <KConfigWatcher>

class QQuickItem;

// Native KWin effects and settings observation, independent of popup
// focus policy and the tray's child-applet model.
class Q_DECL_HIDDEN PopupEffects final : public QObject
{
    Q_OBJECT

public:
    void startMonitoring();
    void setNotificationPopupSlide(QQuickItem *content);
    bool setSplitPopupBlur(QQuickItem *content, QQuickItem *first, QQuickItem *second,
                          qreal radius, bool enabled);
    static bool transparencyEffectsEnabled();

Q_SIGNALS:
    void preferencesChanged();

private:
    void refreshTransparencyWatch();

    KConfigWatcher::Ptr m_blurConfigWatcher;
    QFileSystemWatcher m_transparencyWatcher;
};
