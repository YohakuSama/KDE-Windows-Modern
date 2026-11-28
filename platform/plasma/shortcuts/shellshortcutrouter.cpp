// SPDX-License-Identifier: GPL-2.0-or-later
#include "shellshortcutrouter.h"

#include <QAction>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDebug>
#include <QKeySequence>
#include <QMetaObject>
#include <QQuickItem>

#include <KGlobalAccel>
#include <KIO/ApplicationLauncherJob>
#include <KLocalizedString>
#include <KNotificationJobUiDelegate>
#include <KService>

#include <Plasma/Applet>
#include <Plasma/Containment>
#include <Plasma/Corona>

using namespace Qt::StringLiterals;

namespace
{
constexpr auto kRouterObjectName = "windowsModernShellShortcuts";
constexpr auto kClipboardComponent = "org.kde.windowsmodern.clipboard";
constexpr auto kClipboardAction = "show-history";
constexpr auto kRunComponent = "org.kde.windowsmodern.run";
constexpr auto kRunAction = "show-run";
}

ShellShortcutRouter::ShellShortcutRouter(Plasma::Corona *shell)
    : QObject(shell)
{
    setObjectName(QString::fromLatin1(kRouterObjectName));
}

QObject *ShellShortcutRouter::ensureForShell(Plasma::Corona *shell)
{
    if (!shell)
        return nullptr;
    if (auto *existing = shell->findChild<QObject *>(
            QString::fromLatin1(kRouterObjectName), Qt::FindDirectChildrenOnly)) {
        QMetaObject::invokeMethod(existing, "ensureActions", Qt::DirectConnection);
        return existing;
    }
    auto *router = new ShellShortcutRouter(shell);
    router->ensureActions();
    return router;
}

QObject *ShellShortcutRouter::attach(Plasma::Corona *shell, Plasma::Containment *client, QQuickItem *representation)
{
    if (!shell || !client || !representation)
        return nullptr;
    auto *router = ensureForShell(shell);
    if (!router)
        return nullptr;
    QMetaObject::invokeMethod(router, "attachClient", Qt::DirectConnection,
                              Q_ARG(QObject *, client),
                              Q_ARG(QObject *, representation));
    return router;
}

void ShellShortcutRouter::detach(Plasma::Corona *shell, Plasma::Containment *client)
{
    if (!shell || !client)
        return;
    if (auto *router = shell->findChild<QObject *>(
            QString::fromLatin1(kRouterObjectName), Qt::FindDirectChildrenOnly)) {
        QMetaObject::invokeMethod(router, "detachClient", Qt::DirectConnection,
                                  Q_ARG(QObject *, client));
    }
}

void ShellShortcutRouter::refresh(Plasma::Corona *shell)
{
    if (!shell)
        return;
    if (auto *router = shell->findChild<QObject *>(
            QString::fromLatin1(kRouterObjectName), Qt::FindDirectChildrenOnly)) {
        QMetaObject::invokeMethod(router, "ensureActions", Qt::DirectConnection);
    }
}

void ShellShortcutRouter::attachClient(QObject *clientObject, QObject *representationObject)
{
    auto *client = qobject_cast<Plasma::Containment *>(clientObject);
    auto *representation = qobject_cast<QQuickItem *>(representationObject);
    if (!client || !representation)
        return;

    for (auto &entry : m_clients) {
        if (entry.tray.data() == client) {
            // A new representation can become ready before the old one is
            // destroyed. Only the current representation controls routing.
            entry.representation = representation;
            ensureActions();
            return;
        }
    }
    m_clients.append(Client{QPointer<Plasma::Containment>(client), QPointer<QQuickItem>(representation)});
    connect(client, &Plasma::Containment::screenChanged,
            this, &ShellShortcutRouter::ensureActions, Qt::UniqueConnection);
    connect(client, &Plasma::Applet::destroyedChanged,
            this, &ShellShortcutRouter::ensureActions, Qt::UniqueConnection);
    ensureActions();
}

void ShellShortcutRouter::detachClient(QObject *clientObject)
{
    auto *client = qobject_cast<Plasma::Containment *>(clientObject);
    if (client) {
        disconnect(client, &Plasma::Containment::screenChanged,
                   this, &ShellShortcutRouter::ensureActions);
        disconnect(client, &Plasma::Applet::destroyedChanged,
                   this, &ShellShortcutRouter::ensureActions);
    }
    m_clients.removeIf([clientObject](const Client &entry) {
        return !entry.tray || static_cast<QObject *>(entry.tray.data()) == clientObject;
    });
    // Keep the existing action identities and user bindings even if all
    // tray representations disappear. Native fallbacks remain available
    // until another representation attaches or the Corona is destroyed.
}

Plasma::Containment *ShellShortcutRouter::target() const
{
    Plasma::Containment *secondary = nullptr;
    for (const auto &entry : m_clients) {
        auto *client = entry.tray.data();
        if (!client || client->destroyed() || !entry.representation)
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
    // On a fresh session without a tray, do not advertise an unbound action
    // for initial installer migration until a tray representation is ready.
    // However, if Win+R or Win+V was already bound to our component in a
    // previous session and the user removed the tray, claim that existing
    // binding immediately on cold start so its native fallback still fires.
    const bool readyTray = target() != nullptr;
    auto *accel = KGlobalAccel::self();

    if (!m_clipboard && (readyTray || !accel->globalShortcut(
            QString::fromLatin1(kClipboardComponent), QString::fromLatin1(kClipboardAction)).isEmpty())) {
        m_clipboard = new QAction(i18n("Open clipboard history"), this);
        m_clipboard->setObjectName(QString::fromLatin1(kClipboardAction));
        m_clipboard->setProperty("componentName", QString::fromLatin1(kClipboardComponent));
        m_clipboard->setProperty("componentDisplayName", u"Windows Modern"_s);
        connect(m_clipboard, &QAction::triggered, this, &ShellShortcutRouter::showClipboard);
        accel->setShortcut(m_clipboard, QList<QKeySequence>{});
    }
    if (!m_run && (readyTray || !accel->globalShortcut(
            QString::fromLatin1(kRunComponent), QString::fromLatin1(kRunAction)).isEmpty())) {
        m_run = new QAction(i18n("Open Run dialog"), this);
        m_run->setObjectName(QString::fromLatin1(kRunAction));
        m_run->setProperty("componentName", QString::fromLatin1(kRunComponent));
        m_run->setProperty("componentDisplayName", u"Windows Modern"_s);
        connect(m_run, &QAction::triggered, this, &ShellShortcutRouter::showRun);
        accel->setShortcut(m_run, QList<QKeySequence>{});
    }
}

void ShellShortcutRouter::showClipboard()
{
    if (auto *client = target()) {
        QQuickItem *clipboardApplet = nullptr;
        const bool resolved = QMetaObject::invokeMethod(
            client, "appletForPluginId", Qt::DirectConnection,
            Q_RETURN_ARG(QQuickItem *, clipboardApplet),
            Q_ARG(QString, u"org.kde.plasma.clipboard"_s));
        if (resolved && clipboardApplet) {
            QMetaObject::invokeMethod(client, "clipboardHistoryRequested", Qt::DirectConnection);
            return;
        }
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
        if (QMetaObject::invokeMethod(client, "runDialogRequested", Qt::DirectConnection))
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
