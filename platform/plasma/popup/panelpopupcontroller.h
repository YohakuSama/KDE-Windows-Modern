// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QHash>
#include <QObject>
#include <QPointer>
#include <QString>
#include <QTimer>
#include <QWindow>

// Panel-local policy only. This controller has no dependency on the tray
// model, applet registry or the QML implementation of a specific flyout.
class Q_DECL_HIDDEN PanelPopupController final : public QObject
{
public:
    PanelPopupController();
    void prepareShellPopup(const QString &role, QWindow *window);
    void restoreShellPopupFocus();
    void dismissAllPopups();

private:
    bool shellPopupHasFocus() const;
    void dismissShellPopup(QWindow *window);
    void scheduleShellPopupDismissal();

    QHash<QString, QPointer<QWindow>> m_shellPopups;
    QTimer m_shellPopupDismissTimer;
};
