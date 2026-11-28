// SPDX-License-Identifier: GPL-2.0-or-later
#include "panelpopuphost.h"

#include <Plasma/Applet>
#include <Plasma/Containment>
#include <Plasma/Corona>

using namespace Qt::StringLiterals;

namespace
{
constexpr auto kPanelActionName = "windowsModernPanelPopups";
constexpr auto kShellManagerName = "windowsModernPanelPopupManager";

bool isPanelContainment(const Plasma::Containment *containment)
{
    if (!containment)
        return false;
    const auto type = containment->containmentType();
    return type == Plasma::Containment::Panel || type == Plasma::Containment::CustomPanel;
}

void attachContainmentHost(Plasma::Containment *containment)
{
    if (isPanelContainment(containment))
        PanelPopupHost::ensureForPanel(containment);
}
}

PanelPopupHost::PanelPopupHost(QObject *parent)
    : QAction(parent)
{
    setObjectName(QString::fromLatin1(kPanelActionName));
    setVisible(false);
    connect(&m_popupEffects, &PopupEffects::preferencesChanged,
            this, &PanelPopupHost::popupBlurPreferencesChanged, Qt::UniqueConnection);
    m_popupEffects.startMonitoring();

    if (auto *applet = qobject_cast<Plasma::Applet *>(parent)) {
        connect(applet, &Plasma::Applet::destroyedChanged, this, [this](bool destroyed) {
            if (destroyed)
                m_popupController.dismissAllPopups();
        });
    }
}

Plasma::Containment *PanelPopupHost::panelForApplet(Plasma::Applet *applet)
{
    if (!applet)
        return nullptr;
    if (auto *own = applet->containment(); isPanelContainment(own))
        return own;
    if (auto *parentContainment = qobject_cast<Plasma::Containment *>(applet->parent());
        isPanelContainment(parentContainment)) {
        return parentContainment;
    }
    Plasma::Corona *shell = nullptr;
    if (auto *asContainment = qobject_cast<Plasma::Containment *>(applet))
        shell = asContainment->corona();
    else if (applet->containment())
        shell = applet->containment()->corona();
    if (shell) {
        for (auto *candidate : shell->containments()) {
            if (isPanelContainment(candidate) && candidate->applets().contains(applet))
                return candidate;
        }
    }
    return nullptr;
}

QAction *PanelPopupHost::ensureForPanel(Plasma::Containment *panel)
{
    if (!isPanelContainment(panel))
        return nullptr;
    const QString actionName = QString::fromLatin1(kPanelActionName);
    if (auto *existing = panel->internalAction(actionName))
        return existing;
    auto *host = new PanelPopupHost(panel);
    panel->setInternalAction(actionName, host);
    return host;
}

void PanelPopupHost::installForShell(Plasma::Corona *shell)
{
    if (!shell)
        return;
    const QString managerName = QString::fromLatin1(kShellManagerName);
    if (shell->findChild<QObject *>(managerName, Qt::FindDirectChildrenOnly)) {
        for (auto *containment : shell->containments())
            attachContainmentHost(containment);
        return;
    }

    auto *manager = new QObject(shell);
    manager->setObjectName(managerName);

    auto observeContainment = [manager](Plasma::Containment *containment) {
        if (!containment)
            return;
        attachContainmentHost(containment);
        QObject::connect(containment, &Plasma::Containment::containmentTypeChanged,
                         manager, [containment] { attachContainmentHost(containment); });
    };

    for (auto *containment : shell->containments())
        observeContainment(containment);
    QObject::connect(shell, &Plasma::Corona::containmentAdded, manager, observeContainment);
}

void PanelPopupHost::prepareShellPopup(const QString &role, QWindow *window)
{
    m_popupController.prepareShellPopup(role, window);
}

void PanelPopupHost::restoreShellPopupFocus()
{
    m_popupController.restoreShellPopupFocus();
}

void PanelPopupHost::setNotificationPopupSlide(QQuickItem *content)
{
    m_popupEffects.setNotificationPopupSlide(content);
}

bool PanelPopupHost::setSplitPopupBlur(QQuickItem *content, QQuickItem *first, QQuickItem *second,
                                       qreal radius, bool enabled)
{
    return m_popupEffects.setSplitPopupBlur(content, first, second, radius, enabled);
}
