// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QDBusContext>
#include <QElapsedTimer>
#include <QObject>
#include <QPointer>
#include <QString>

class QWidget;

// Per-process, one-shot request. KWin owns actual window placement and the
// popup; this object never moves any other window or sends synthetic input.
class CaptionSnapBridge final : public QObject, protected QDBusContext
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.windowsmodern.KonsoleChrome")

public:
    explicit CaptionSnapBridge(QObject *parent);
    ~CaptionSnapBridge() override;

    void request(QWidget *window, QWidget *button);
    void cancel(QWidget *window);

public Q_SLOTS:
    Q_SCRIPTABLE QString takeAnchor();

private:
    bool ensureRegistered();
    void reset();

    QString m_service;
    QPointer<QWidget> m_window;
    QPointer<QWidget> m_button;
    QElapsedTimer m_requestedAt;
    bool m_registered = false;
};
