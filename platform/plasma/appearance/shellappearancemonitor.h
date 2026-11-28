// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QPointer>
#include <QProcess>
#include <QTimer>

#include <KConfigWatcher>

namespace Plasma
{
class Corona;
}
class WallpaperAccentSource;

// One event-driven appearance pipeline per shell, regardless of panel count.
// Lookup and invocation cross independent Plasma plugin binaries via QObject
// child names and QMetaObject slots, avoiding per-plugin staticMetaObject casts.
class Q_DECL_HIDDEN ShellAppearanceMonitor final : public QObject
{
    Q_OBJECT

public:
    static QObject *ensureForShell(Plasma::Corona *shell);
    static QObject *startForShell(Plasma::Corona *shell);
    static void requestSyncForShell(Plasma::Corona *shell);
    ~ShellAppearanceMonitor() override;

public Q_SLOTS:
    void start();
    void requestSync();

private Q_SLOTS:
    void scheduleWallpaperAccentSync();

private:
    explicit ShellAppearanceMonitor(Plasma::Corona *shell);
    void refreshWallpaperWatch();
    void launchSync();
    void finishSync(int exitCode, bool normalExit);

    KConfigWatcher::Ptr m_configWatcher;
    QFileSystemWatcher m_wallpaperWatch;
    QPointer<WallpaperAccentSource> m_wallpaperAccentSource;
    QTimer m_timer;
    QProcess m_process;
    int m_retries = 0;
    bool m_started = false;
    bool m_dirty = false;
    bool m_running = false;
    bool m_automaticWallpaperAccent = false;
    bool m_configWallpaperParent = false;
};
