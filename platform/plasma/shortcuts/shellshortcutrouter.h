// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QList>
#include <QObject>
#include <QPointer>

namespace Plasma
{
class Corona;
}
class SystemTray;
class QAction;
class QQuickItem;

// Own the global actions for the shell session, not for any one panel.
// Only clients with completed QML representations receive themed actions.
class ShellShortcutRouter final : public QObject
{
    Q_OBJECT

public:
    static ShellShortcutRouter *attach(Plasma::Corona *shell, SystemTray *client, QQuickItem *representation);
    void detach(SystemTray *client);

private:
    explicit ShellShortcutRouter(Plasma::Corona *shell);
    void ensureActions();
    SystemTray *target() const;
    void showClipboard();
    void showRun();

    struct Client {
        QPointer<SystemTray> tray;
        QPointer<QQuickItem> representation;
    };
    QList<Client> m_clients;
    QAction *m_clipboard = nullptr;
    QAction *m_run = nullptr;
};
