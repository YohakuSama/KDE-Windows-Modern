// SPDX-License-Identifier: GPL-3.0-or-later
#include "captionsnapbridge.h"

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QWidget>
#include <QWindow>

namespace
{
const QString ObjectPath = QStringLiteral("/KonsoleChrome");
const QString ShortcutName = QStringLiteral("Windows Modern: Show Konsole Snap Layouts");
}

CaptionSnapBridge::CaptionSnapBridge(QObject *parent)
    : QObject(parent)
    , m_service(QStringLiteral("org.kde.windowsmodern.KonsoleChrome.p%1").arg(QCoreApplication::applicationPid()))
{
}

CaptionSnapBridge::~CaptionSnapBridge()
{
    if (m_registered) {
        auto bus = QDBusConnection::sessionBus();
        bus.unregisterObject(ObjectPath);
        bus.unregisterService(m_service);
    }
}

bool CaptionSnapBridge::ensureRegistered()
{
    if (m_registered)
        return true;
    auto bus = QDBusConnection::sessionBus();
    if (!bus.isConnected() || !bus.registerService(m_service))
        return false;
    if (!bus.registerObject(ObjectPath, this, QDBusConnection::ExportScriptableSlots)) {
        bus.unregisterService(m_service);
        return false;
    }
    m_registered = true;
    return true;
}

void CaptionSnapBridge::request(QWidget *window, QWidget *button)
{
    if (!window || !button || !window->isActiveWindow() || !button->isVisible()
        || !button->underMouse() || window->isFullScreen() || window->isMinimized()
        || !ensureRegistered())
        return;
    m_window = window;
    m_button = button;
    m_requestedAt.start();

    auto message = QDBusMessage::createMethodCall(QStringLiteral("org.kde.kglobalaccel"),
        QStringLiteral("/component/kwin"), QStringLiteral("org.kde.kglobalaccel.Component"),
        QStringLiteral("invokeShortcut"));
    message << ShortcutName << QStringLiteral("default");
    // A disabled or older KWin script is harmless: the one-shot request
    // expires, and maximize/restore continues to work normally.
    QDBusConnection::sessionBus().asyncCall(message, 1000);
}

void CaptionSnapBridge::reset()
{
    m_window.clear();
    m_button.clear();
    m_requestedAt.invalidate();
}

void CaptionSnapBridge::cancel(QWidget *window)
{
    if (m_window.data() == window)
        reset();
}

QString CaptionSnapBridge::takeAnchor()
{
    // Only the running KWin session may consume the short-lived request.
    if (!calledFromDBus())
        return {};
    auto *interface = connection().interface();
    if (!interface)
        return {};
    const QDBusReply<QString> owner = interface->serviceOwner(QStringLiteral("org.kde.KWin"));
    if (!owner.isValid() || owner.value() != message().service())
        return {};
    const auto window = m_window;
    const auto button = m_button;
    const bool recent = m_requestedAt.isValid() && m_requestedAt.elapsed() <= 1000;
    reset(); // Always consume once, even when the window has changed.
    if (!recent || !window || !button || !window->isActiveWindow()
        || !window->windowHandle() || window->isFullScreen() || window->isMinimized()
        || !window->windowFlags().testFlag(Qt::FramelessWindowHint)
        || !button->isVisibleTo(window.data()) || !button->underMouse()
        || button->window() != window.data())
        return {};
    const QPoint origin = button->mapTo(window.data(), QPoint(0, 0));
    QJsonObject anchor{
        {QStringLiteral("x"), origin.x()}, {QStringLiteral("y"), origin.y()},
        {QStringLiteral("width"), button->width()}, {QStringLiteral("height"), button->height()},
        {QStringLiteral("windowWidth"), window->width()}, {QStringLiteral("windowHeight"), window->height()}
    };
    return QString::fromUtf8(QJsonDocument(anchor).toJson(QJsonDocument::Compact));
}
