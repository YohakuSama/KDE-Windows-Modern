// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QList>
#include <QObject>
#include <QPointer>

namespace Plasma
{
class Containment;
class Corona;
}
class QAction;
class QQuickItem;

// Own the global actions for the shell session, not for any one panel.
// Only clients with completed QML representations receive themed actions;
// cross-plugin callers attach and detach through QMetaObject slots.
class Q_DECL_HIDDEN ShellShortcutRouter final : public QObject
{
    Q_OBJECT

public:
    static QObject *ensureForShell(Plasma::Corona *shell);
    static QObject *attach(Plasma::Corona *shell, Plasma::Containment *client, QQuickItem *representation);
    static void detach(Plasma::Corona *shell, Plasma::Containment *client);
    static void refresh(Plasma::Corona *shell);

public Q_SLOTS:
    void ensureActions();
    void attachClient(QObject *client, QObject *representation);
    void detachClient(QObject *client);

private:
    explicit ShellShortcutRouter(Plasma::Corona *shell);
    Plasma::Containment *target() const;
    void showClipboard();
    void showRun();

    struct Client {
        QPointer<Plasma::Containment> tray;
        QPointer<QQuickItem> representation;
    };
    QList<Client> m_clients;
    QAction *m_clipboard = nullptr;
    QAction *m_run = nullptr;
};
