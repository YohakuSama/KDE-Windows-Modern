// SPDX-License-Identifier: GPL-2.0-or-later
#include "shellshortcutrouter.h"
#include "systemtray.h"

#include <QAction>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QKeySequence>
#include <QQuickItem>
#include <QDebug>

#include <KGlobalAccel>
#include <KIO/ApplicationLauncherJob>
#include <KLocalizedString>
#include <KNotificationJobUiDelegate>
#include <KService>

#include <Plasma/Corona>

using namespace Qt::StringLiterals;

ShellShortcutRouter::ShellShortcutRouter(Plasma::Corona *shell)
    : QObject(shell)
{
    setObjectName(u"windowsModernShellShortcuts"_s);
}

ShellShortcutRouter *ShellShortcutRouter::attach(Plasma::Corona *shell, SystemTray *client, QQuickItem *representation)
{
    if (!shell || !client || !representation)
        return nullptr;
    auto *router = shell->findChild<ShellShortcutRouter *>(
        u"windowsModernShellShortcuts"_s, Qt::FindDirectChildrenOnly);
    if (!router)
        router = new ShellShortcutRouter(shell);

    for (auto &entry : router->m_clients) {
        if (entry.tray.data() == client) {
            // A new representation can become ready before the old one is
            // destroyed. Only the current representation controls routing.
            entry.representation = representation;
            router->ensureActions();
            return router;
        }
    }
    router->m_clients.append(Client{QPointer<SystemTray>(client), QPointer<QQuickItem>(representation)});
    connect(client, &Plasma::Containment::screenChanged,
            router, &ShellShortcutRouter::ensureActions);
    router->ensureActions();
    return router;
}

void ShellShortcutRouter::detach(SystemTray *client)
{
    disconnect(client, &Plasma::Containment::screenChanged,
               this, &ShellShortcutRouter::ensureActions);
    m_clients.removeIf([client](const Client &entry) {
        return !entry.tray || entry.tray.data() == client;
    });
    // Keep the existing action identities and user bindings even if all
    // tray representations disappear. Native fallbacks remain available
    // until another representation attaches or the Corona is destroyed.
}

SystemTray *ShellShortcutRouter::target() const
{
    SystemTray *secondary = nullptr;
    for (const auto &entry : m_clients) {
        auto *client = entry.tray.data();
        if (!client || !entry.representation)
            continue;
        const int screen = static_cast<int>(client->screen());
        if (screen == 0)
            return client;
        if (screen >= 0 && !secondary)
            secondary = client;
    }
    return secondary;
}

void ShellShortcutRouter::ensureActions()
{
    // Don't offer an action for initial installer migration until at
    // least one eligible panel has completed its representation.
    if (!target())
        return;

    if (!m_clipboard) {
        m_clipboard = new QAction(i18n("Open clipboard history"), this);
        m_clipboard->setObjectName(u"show-history"_s);
        m_clipboard->setProperty("componentName", u"org.kde.windowsmodern.clipboard"_s);
        m_clipboard->setProperty("componentDisplayName", u"Windows Modern"_s);
        connect(m_clipboard, &QAction::triggered, this, &ShellShortcutRouter::showClipboard);
        KGlobalAccel::self()->setShortcut(m_clipboard, QList<QKeySequence>{});
    }
    if (!m_run) {
        m_run = new QAction(i18n("Open Run dialog"), this);
        m_run->setObjectName(u"show-run"_s);
        m_run->setProperty("componentName", u"org.kde.windowsmodern.run"_s);
        m_run->setProperty("componentDisplayName", u"Windows Modern"_s);
        connect(m_run, &QAction::triggered, this, &ShellShortcutRouter::showRun);
        KGlobalAccel::self()->setShortcut(m_run, QList<QKeySequence>{});
    }
}

void ShellShortcutRouter::showClipboard()
{
    if (auto *client = target(); client &&
        client->appletForPluginId(u"org.kde.plasma.clipboard"_s)) {
        Q_EMIT client->clipboardHistoryRequested();
        return;
    }
    // The native clipboard backend is also the fallback used when its
    // child applet is disabled. Never invent a separate clipboard store.
    QDBusConnection::sessionBus().asyncCall(QDBusMessage::createMethodCall(
        u"org.kde.klipper"_s, u"/klipper"_s,
        u"org.kde.klipper.klipper"_s, u"showKlipperPopupMenu"_s));
}

void ShellShortcutRouter::showRun()
{
    if (auto *client = target()) {
        Q_EMIT client->runDialogRequested();
        return;
    }
    // Same native application used by the installer's fallback binding.
    const auto service = KService::serviceByDesktopName(u"org.kde.krunner"_s);
    if (!service) {
        qWarning("Windows Modern: native Run fallback is unavailable");
        return;
    }
    auto *job = new KIO::ApplicationLauncherJob(service);
    job->setUiDelegate(new KNotificationJobUiDelegate(KJobUiDelegate::AutoHandlingEnabled));
    job->start();
}
