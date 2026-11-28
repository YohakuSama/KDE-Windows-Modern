// SPDX-FileCopyrightText: 2015 Marco Martin <mart@kde.org>
// SPDX-License-Identifier: GPL-2.0-or-later
#include "panelpopupcontroller.h"

#include <QGuiApplication>
#include <QMetaObject>
#include <QVariant>
#include <utility>

using namespace Qt::StringLiterals;

PanelPopupController::PanelPopupController()
{
    // A single focus group per panel; never close Start just because a
    // different window in the same group receives keyboard focus.
    m_shellPopupDismissTimer.setSingleShot(true);
    m_shellPopupDismissTimer.setInterval(180);
    connect(qGuiApp, &QGuiApplication::focusWindowChanged, this,
            [this](QWindow *) { scheduleShellPopupDismissal(); });
    connect(&m_shellPopupDismissTimer, &QTimer::timeout, this, [this] {
        if (shellPopupHasFocus())
            return;
        // A panel button's release may be the actual activation. Let that
        // gesture finish before deciding whether this was an outside click.
        if (QGuiApplication::mouseButtons() != Qt::NoButton) {
            scheduleShellPopupDismissal();
            return;
        }
        // Closing a QML window may synchronously register a new popup.
        // Iterate a guarded snapshot, and skip any role replaced meanwhile.
        const auto popups = m_shellPopups;
        for (auto it = popups.cbegin(); it != popups.cend(); ++it) {
            auto *window = it.value().data();
            if (m_shellPopups.value(it.key()).data() != window)
                continue;
            if (window && window->isVisible() && !window->property("wmKeepOnDeactivate").toBool())
                dismissShellPopup(window);
        }
    });
}

bool PanelPopupController::shellPopupHasFocus() const
{
    // Native submenus may own a transient window. Preserve the same
    // focus group through their parent chain, not unrelated shell windows.
    for (auto *focus = QGuiApplication::focusWindow(); focus; focus = focus->transientParent()) {
        for (const auto &entry : m_shellPopups) {
            if (entry && entry->isVisible() && entry.data() == focus)
                return true;
        }
    }
    return false;
}

void PanelPopupController::scheduleShellPopupDismissal()
{
    m_shellPopupDismissTimer.stop();
    if (shellPopupHasFocus())
        return;
    for (const auto &entry : std::as_const(m_shellPopups)) {
        if (entry && entry->isVisible() && !entry->property("wmKeepOnDeactivate").toBool()) {
            m_shellPopupDismissTimer.start();
            return;
        }
    }
}

void PanelPopupController::dismissShellPopup(QWindow *window)
{
    if (!window || !window->isVisible())
        return;
    // The QML owner updates its own route/state before hiding the window.
    if (!QMetaObject::invokeMethod(window, "closeCoordinatedPopup", Qt::DirectConnection))
        window->hide();
}

void PanelPopupController::prepareShellPopup(const QString &role, QWindow *window)
{
    if (!window || (role != u"start"_s && role != u"tray"_s && role != u"clock"_s))
        return;
    m_shellPopups.insert(role, window);
    if (role == u"tray"_s)
        dismissShellPopup(m_shellPopups.value(u"clock"_s).data());
    else if (role == u"clock"_s)
        dismissShellPopup(m_shellPopups.value(u"tray"_s).data());
    // Explicit activation is in progress; focusWindowChanged will settle
    // the next real focus transition after the new window is mapped.
    m_shellPopupDismissTimer.stop();
}

void PanelPopupController::restoreShellPopupFocus()
{
    for (const auto &role : {u"start"_s, u"clock"_s, u"tray"_s}) {
        auto *window = m_shellPopups.value(role).data();
        if (window && window->isVisible()) {
            m_shellPopupDismissTimer.stop();
            window->requestActivate();
            return;
        }
    }
    m_shellPopupDismissTimer.stop();
}

void PanelPopupController::dismissAllPopups()
{
    m_shellPopupDismissTimer.stop();
    const auto popups = m_shellPopups;
    for (auto it = popups.cbegin(); it != popups.cend(); ++it) {
        auto *window = it.value().data();
        if (m_shellPopups.value(it.key()).data() != window)
            continue;
        if (window && window->isVisible())
            dismissShellPopup(window);
    }
}
