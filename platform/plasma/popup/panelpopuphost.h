// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QAction>
#include <QQuickItem>
#include <QString>
#include <QWindow>

#include "panelpopupcontroller.h"
#include "popupeffects.h"

namespace Plasma
{
class Applet;
class Containment;
class Corona;
}

// Panel-owned capability object published as a non-visible internal action
// ("windowsModernPanelPopups") on each Panel/CustomPanel containment.
// Start, Digital Clock and System Tray on the same panel share one focus
// group and KWin split-blur watcher without depending on the tray's lifetime.
class Q_DECL_HIDDEN PanelPopupHost final : public QAction
{
    Q_OBJECT

public:
    explicit PanelPopupHost(QObject *parent = nullptr);

    static Plasma::Containment *panelForApplet(Plasma::Applet *applet);
    static QAction *ensureForPanel(Plasma::Containment *panel);
    static void installForShell(Plasma::Corona *shell);

public Q_SLOTS:
    void prepareShellPopup(const QString &role, QWindow *window);
    void restoreShellPopupFocus();
    void setNotificationPopupSlide(QQuickItem *content);
    bool setSplitPopupBlur(QQuickItem *content, QQuickItem *first, QQuickItem *second,
                           qreal radius, bool enabled);

Q_SIGNALS:
    void popupBlurPreferencesChanged();

private:
    PanelPopupController m_popupController;
    PopupEffects m_popupEffects;
};
