/*
    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "backend.h"

#include "log_settings.h"
#include "panelpopuphost.h"
#include "shellappearancemonitor.h"
#include "shellshortcutrouter.h"

#include <Plasma/Applet>
#include <Plasma/Containment>
#include <Plasma/Corona>
#include <KActionCollection>
#include <KConfigGroup>
#include <KGlobalAccel>
#include <KDesktopFile>
#include <KFileItem>
#include <KFilePlacesModel>
#include <KLocalizedString>
#include <KNotificationJobUiDelegate>
#include <KProtocolInfo>
#include <KService>
#include <KServiceAction>
#include <KWindowEffects>
#include <KWindowSystem>

#include <KApplicationTrader>
#include <KIO/ApplicationLauncherJob>

#include <QAction>
#include <QActionGroup>
#include <QApplication>
#include <QJsonArray>
#include <QIcon>
#include <QImage>
#include <QImageReader>
#include <QFileInfo>
#include <QDateTime>
#include <QHash>
#include <QPainter>
#include <QPalette>
#include <QRegularExpression>
#include <QPixmap>
#include "panelicon.h"
#include <QMenu>
#include <QQuickItem>
#include <QQuickWindow>
#include <QStandardPaths>
#include <QTimer>
#include <QVersionNumber>

#include <mutex>

#include <PlasmaActivities/Consumer>
#include <PlasmaActivities/Stats/Cleaning>
#include <PlasmaActivities/Stats/ResultSet>
#include <PlasmaActivities/Stats/Terms>

#include <processcore/process.h>
#include <processcore/processes.h>

namespace KAStats = KActivities::Stats;

using namespace KAStats;
using namespace KAStats::Terms;

static constexpr int NoApplications = 2; // kactivitymanager StatsPlugin WhatToRemember.

QVector<Backend *> Backend::s_instances;

Backend::Backend(QObject *parent)
    : QObject(parent)
    , m_actionGroup(new QActionGroup(this))
    , m_activityManagerPluginsSettingsWatcher(KConfigWatcher::create(m_activityManagerPluginsSettings.sharedConfig()))
{
    connect(m_activityManagerPluginsSettingsWatcher.get(),
            &KConfigWatcher::configChanged,
            this,
            [this](const KConfigGroup &group, const QByteArrayList &names) {
                if (group.name() == QLatin1String("Plugin-org.kde.ActivityManager.Resources.Scoring")
                    && names.contains(QByteArrayLiteral("what-to-remember"))) {
                    m_activityManagerPluginsSettings.load();
                }
            });

    s_instances.append(this);
    setupShortcuts();
}

QVariant Backend::normalizedPanelIcon(const QVariant &decoration) const
{
    QIcon original;
    if (decoration.canConvert<QIcon>()) {
        original = decoration.value<QIcon>();
    } else if (decoration.metaType().id() == QMetaType::QString) {
        original = QIcon::fromTheme(decoration.toString());
    }
    if (original.isNull()) {
        return decoration;
    }
    const QImage canvas = WindowsModern::normalizedPanelImage(original.pixmap(QSize(96, 96), 1.0).toImage());
    if (canvas.isNull()) {
        return decoration;
    }
    return QVariant::fromValue(QIcon(QPixmap::fromImage(canvas)));
}

// Use the same private importer as the desktop context menu. A QIcon
// returned to PlasmaExtras is already tinted; no inherited theme lookup
// can replace a missing Windows role with a KDE icon.
QVariant Backend::nativeMenuIcon(const QString &role) const
{
    static const QRegularExpression validRole(QStringLiteral("^(actions|status|devices|apps)/[A-Za-z0-9_.+-]+$"));
    if (!validRole.match(role).hasMatch())
        return QVariant::fromValue(QIcon());

    const auto path = QStandardPaths::locate(QStandardPaths::GenericDataLocation,
        QStringLiteral("windows-modern/native-assets/icons/") + role + QStringLiteral(".svg"));
    const QFileInfo info(path);
    if (!info.isFile() || info.isSymLink())
        return QVariant::fromValue(QIcon());

    const QPalette palette = QApplication::palette("QMenu");
    const QColor foreground = palette.color(QPalette::Active, QPalette::WindowText);
    const QColor disabled = palette.color(QPalette::Disabled, QPalette::WindowText);
    const QColor selected = palette.color(QPalette::Active, QPalette::HighlightedText);
    const QString key = path + QString::number(info.lastModified().toMSecsSinceEpoch())
        + foreground.name(QColor::HexArgb) + disabled.name(QColor::HexArgb)
        + selected.name(QColor::HexArgb);
    static QHash<QString, QIcon> cache;
    const auto cached = cache.constFind(key);
    if (cached != cache.constEnd())
        return QVariant::fromValue(cached.value());

    QIcon icon;
    for (const qreal dpr : {1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0}) {
        const int size = qRound(16 * dpr);
        QImageReader reader(path);
        reader.setScaledSize(QSize(size, size));
        const QImage mask = reader.read().convertToFormat(QImage::Format_ARGB32_Premultiplied);
        if (mask.isNull())
            continue;
        const auto add = [&](const QColor &color, QIcon::Mode mode) {
            QImage image = mask;
            QPainter painter(&image);
            painter.setCompositionMode(QPainter::CompositionMode_SourceIn);
            painter.fillRect(image.rect(), color);
            painter.end();
            QPixmap pixmap = QPixmap::fromImage(image);
            pixmap.setDevicePixelRatio(dpr);
            icon.addPixmap(pixmap, mode);
        };
        add(foreground, QIcon::Normal);
        add(disabled, QIcon::Disabled);
        add(selected, QIcon::Selected);
    }
    if (!icon.isNull()) {
        if (cache.size() >= 128)
            cache.clear();
        cache.insert(key, icon);
    }
    return QVariant::fromValue(icon);
}

Backend::~Backend()
{
    s_instances.removeAll(this);
}

QObject *Backend::applet() const
{
    return m_applet.data();
}

void Backend::setApplet(QObject *appletObject)
{
    if (m_applet.data() == appletObject) {
        return;
    }
    if (auto *previous = qobject_cast<Plasma::Applet *>(m_applet.data())) {
        disconnect(previous, &Plasma::Applet::containmentChanged, this, &Backend::attachShellCapabilities);
        disconnect(previous, &Plasma::Applet::destroyedChanged, this, &Backend::attachShellCapabilities);
    }
    m_applet = appletObject;
    if (auto *current = qobject_cast<Plasma::Applet *>(appletObject)) {
        connect(current, &Plasma::Applet::containmentChanged, this, &Backend::attachShellCapabilities);
        connect(current, &Plasma::Applet::destroyedChanged, this, &Backend::attachShellCapabilities);
    }
    attachShellCapabilities();
    Q_EMIT appletChanged();
}

void Backend::attachShellCapabilities()
{
    auto *applet = qobject_cast<Plasma::Applet *>(m_applet.data());
    if (!applet || applet->destroyed()) {
        return;
    }
    auto *panel = PanelPopupHost::panelForApplet(applet);
    if (panel) {
        PanelPopupHost::ensureForPanel(panel);
    }
    auto *shell = panel ? panel->corona()
                        : (applet->containment() ? applet->containment()->corona() : nullptr);
    if (shell) {
        PanelPopupHost::installForShell(shell);
        ShellAppearanceMonitor::startForShell(shell);
        ShellShortcutRouter::ensureForShell(shell);
    }
}

void Backend::requestAppearanceSync()
{
    auto *applet = qobject_cast<Plasma::Applet *>(m_applet.data());
    if (!applet || applet->destroyed()) {
        return;
    }
    auto *panel = PanelPopupHost::panelForApplet(applet);
    auto *shell = panel ? panel->corona()
                        : (applet->containment() ? applet->containment()->corona() : nullptr);
    if (shell) {
        ShellAppearanceMonitor::requestSyncForShell(shell);
    }
}

bool Backend::isDestroyedApplet() const
{
    const auto *applet = qobject_cast<const Plasma::Applet *>(m_applet.data());
    return applet && applet->destroyed();
}

int Backend::screen() const
{
    return m_screen;
}

void Backend::setScreen(int screen)
{
    if (m_screen != screen) {
        m_screen = screen;
        Q_EMIT screenChanged();
    }
}

bool Backend::hasActiveTask() const
{
    return m_hasActiveTask;
}

void Backend::setHasActiveTask(bool active)
{
    if (m_hasActiveTask != active) {
        m_hasActiveTask = active;
        Q_EMIT hasActiveTaskChanged();
    }
}

bool Backend::showsOnlyCurrentScreen() const
{
    return m_showsOnlyCurrentScreen;
}

void Backend::setShowsOnlyCurrentScreen(bool shows)
{
    if (m_showsOnlyCurrentScreen != shows) {
        m_showsOnlyCurrentScreen = shows;
        Q_EMIT showsOnlyCurrentScreenChanged();
    }
}


QUrl Backend::tryDecodeApplicationsUrl(const QUrl &launcherUrl)
{
    if (launcherUrl.isValid() && launcherUrl.scheme() == QLatin1String("applications")) {
        const KService::Ptr service = KService::serviceByMenuId(launcherUrl.path());

        if (service) {
            return QUrl::fromLocalFile(service->entryPath());
        }
    }

    return launcherUrl;
}

QStringList Backend::applicationCategories(const QUrl &launcherUrl)
{
    const QUrl desktopEntryUrl = tryDecodeApplicationsUrl(launcherUrl);

    if (!desktopEntryUrl.isValid() || !desktopEntryUrl.isLocalFile() || !KDesktopFile::isDesktopFile(desktopEntryUrl.toLocalFile())) {
        return QStringList();
    }

    KDesktopFile desktopFile(desktopEntryUrl.toLocalFile());

    // Since we can't have dynamic jump list actions, at least add the user's "Places" for file managers.
    return desktopFile.desktopGroup().readXdgListEntry(QStringLiteral("Categories"));
}

QVariantList Backend::jumpListActions(const QUrl &launcherUrl, QObject *parent)
{
    QVariantList actions;

    if (!parent) {
        return actions;
    }

    QUrl desktopEntryUrl = tryDecodeApplicationsUrl(launcherUrl);

    if (!desktopEntryUrl.isValid() || !desktopEntryUrl.isLocalFile() || !KDesktopFile::isDesktopFile(desktopEntryUrl.toLocalFile())) {
        return actions;
    }

    const KService::Ptr service = KService::serviceByDesktopPath(desktopEntryUrl.toLocalFile());
    if (!service) {
        return actions;
    }

    if (service->storageId() == QLatin1String("systemsettings.desktop")) {
        actions = systemSettingsActions(parent);
        if (!actions.isEmpty()) {
            return actions;
        }
    }

    const auto jumpListActions = service->actions();

    for (const KServiceAction &serviceAction : jumpListActions) {
        if (serviceAction.noDisplay()) {
            continue;
        }

        QAction *action = new QAction(parent);
        action->setText(serviceAction.text());
        action->setIcon(QIcon::fromTheme(serviceAction.icon()));
        if (serviceAction.isSeparator()) {
            action->setSeparator(true);
        }

        connect(action, &QAction::triggered, this, [serviceAction]() {
            auto *job = new KIO::ApplicationLauncherJob(serviceAction);
            auto *delegate = new KNotificationJobUiDelegate;
            delegate->setAutoErrorHandlingEnabled(true);
            job->setUiDelegate(delegate);
            job->start();
        });

        actions << QVariant::fromValue<QAction *>(action);
    }

    return actions;
}

QVariantList Backend::systemSettingsActions(QObject *parent) const
{
    QVariantList actions;

    if (m_activityManagerPluginsSettings.whatToRemember() == NoApplications) {
        return actions;
    }

    auto query = AllResources | Agent(QStringLiteral("org.kde.systemsettings")) | HighScoredFirst | Limit(5);

    ResultSet results(query);

    QStringList ids;
    for (const ResultSet::Result &result : results) {
        ids << QUrl(result.resource()).path();
    }

    if (ids.count() < 5) {
        // We'll load the default set of settings from its jump list actions.
        return actions;
    }

    for (const QString &id : std::as_const(ids)) {
        KService::Ptr service = KService::serviceByStorageId(id);
        if (!service || !service->isValid()) {
            continue;
        }

        QAction *action = new QAction(parent);
        action->setText(service->name());
        action->setIcon(QIcon::fromTheme(service->icon()));

        connect(action, &QAction::triggered, this, [service]() {
            auto *job = new KIO::ApplicationLauncherJob(service);
            auto *delegate = new KNotificationJobUiDelegate;
            delegate->setAutoErrorHandlingEnabled(true);
            job->setUiDelegate(delegate);
            job->start();
        });

        actions << QVariant::fromValue<QAction *>(action);
    }
    return actions;
}

QVariantList Backend::placesActions(const QUrl &launcherUrl, bool showAllPlaces, QObject *parent)
{
    if (!parent) {
        return QVariantList();
    }

    QUrl desktopEntryUrl = tryDecodeApplicationsUrl(launcherUrl);

    if (!desktopEntryUrl.isValid() || !desktopEntryUrl.isLocalFile() || !KDesktopFile::isDesktopFile(desktopEntryUrl.toLocalFile())) {
        return QVariantList();
    }

    QVariantList actions;

    // Since we can't have dynamic jump list actions, at least add the user's "Places" for file managers.
    if (!applicationCategories(launcherUrl).contains(QLatin1String("FileManager"))) {
        return actions;
    }

    QString previousGroup;
    QMenu *subMenu = nullptr;

    std::unique_ptr<KFilePlacesModel> placesModel(new KFilePlacesModel());
    for (int i = 0; i < placesModel->rowCount(); ++i) {
        QModelIndex idx = placesModel->index(i, 0);

        if (placesModel->isHidden(idx)) {
            continue;
        }

        const QString &title = idx.data(Qt::DisplayRole).toString();
        const QIcon &icon = idx.data(Qt::DecorationRole).value<QIcon>();
        const QUrl &url = idx.data(KFilePlacesModel::UrlRole).toUrl();

        QAction *placeAction = new QAction(icon, title, parent);

        connect(placeAction, &QAction::triggered, this, [url, desktopEntryUrl] {
            KService::Ptr service = KService::serviceByDesktopPath(desktopEntryUrl.toLocalFile());
            if (!service) {
                return;
            }

            auto *job = new KIO::ApplicationLauncherJob(service);
            auto *delegate = new KNotificationJobUiDelegate;
            delegate->setAutoErrorHandlingEnabled(true);
            job->setUiDelegate(delegate);

            job->setUrls({url});
            job->start();
        });

        const QString &groupName = idx.data(KFilePlacesModel::GroupRole).toString();
        if (previousGroup.isEmpty()) { // Skip first group heading.
            previousGroup = groupName;
        }

        // Put all subsequent categories into a submenu.
        if (previousGroup != groupName) {
            QAction *subMenuAction = new QAction(groupName, parent);
            subMenu = new QMenu();
            // Breeze and Oxygen have rounded corners on menus. They set this attribute in polish()
            // but at that time the underlying surface has already been created where setting this
            // flag makes no difference anymore (Bug 385311)
            subMenu->setAttribute(Qt::WA_TranslucentBackground);
            // Cannot parent a QMenu to a QAction, need to delete it manually.
            connect(parent, &QObject::destroyed, subMenu, &QObject::deleteLater);
            subMenuAction->setMenu(subMenu);

            actions << QVariant::fromValue(subMenuAction);

            previousGroup = groupName;
        }

        if (subMenu) {
            subMenu->addAction(placeAction);
        } else {
            actions << QVariant::fromValue(placeAction);
        }
    }

    // There is nothing more frustrating than having a "More" entry that ends up showing just one or two
    // additional entries. Therefore we truncate to max. 5 entries only if there are more than 7 in total.
    if (!showAllPlaces && actions.count() > 7) {
        const int totalActionCount = actions.count();

        while (actions.count() > 5) {
            actions.removeLast();
        }

        QAction *action = new QAction(parent);
        action->setIcon(nativeMenuIcon(QStringLiteral("actions/view-more-symbolic")).value<QIcon>());
        action->setText(i18ncp("Show all user Places", "%1 more Place…", "%1 more Places…", totalActionCount - actions.count()));
        connect(action, &QAction::triggered, this, &Backend::showAllPlaces);
        actions << QVariant::fromValue(action);
    }

    return actions;
}

QVariantList Backend::recentDocumentActions(const QUrl &launcherUrl, QObject *parent)
{
    QVariantList actions;
    if (!parent) {
        return actions;
    }

    if (m_activityManagerPluginsSettings.whatToRemember() == NoApplications) {
        return actions;
    }

    QUrl desktopEntryUrl = tryDecodeApplicationsUrl(launcherUrl);

    if (!desktopEntryUrl.isValid() || !desktopEntryUrl.isLocalFile() || !KDesktopFile::isDesktopFile(desktopEntryUrl.toLocalFile())) {
        return QVariantList();
    }

    QString desktopName = desktopEntryUrl.fileName();
    QString storageId = desktopName;

    if (storageId.endsWith(QLatin1String(".desktop"))) {
        storageId = storageId.left(storageId.length() - 8);
    }

    auto query = UsedResources | RecentlyUsedFirst | Agent(storageId) | Type::any() | Activity::current();

    ResultSet results(query);

    ResultSet::const_iterator resultIt = results.begin();

    int actionCount = 0;

    bool allFolders = true;
    bool allDownloads = true;
    bool allRemoteWithoutFileName = true;
    const QString downloadsPath = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);

    while (actionCount < 5 && resultIt != results.end()) {
        const QString resource = (*resultIt).resource();
        const QString mimetype = (*resultIt).mimetype();
        const QUrl url = (*resultIt).url();
        ++resultIt;

        if (!url.isValid()) {
            continue;
        }

        allFolders = allFolders && mimetype == QLatin1String("inode/directory");
        allDownloads = allDownloads && url.toLocalFile().startsWith(downloadsPath);
        allRemoteWithoutFileName = allRemoteWithoutFileName && !url.isLocalFile() && url.fileName().isEmpty();

        QString name;

        if (url.isLocalFile() && !url.fileName().isEmpty()) {
            name = url.fileName();
        } else {
            name = url.toDisplayString();
        }

        QAction *action = new QAction(parent);
        action->setText(name);
        action->setIcon(QIcon::fromTheme(KIO::iconNameForUrl(url)));
        action->setProperty("agent", storageId);
        action->setProperty("entryPath", desktopEntryUrl);
        action->setProperty("mimeType", mimetype);
        action->setData(url);
        connect(action, &QAction::triggered, this, &Backend::handleRecentDocumentAction);

        actions << QVariant::fromValue<QAction *>(action);

        ++actionCount;
    }

    if (actionCount > 0) {
        // Overrides section heading on QML side
        if (allDownloads) {
            actions.prepend(i18n("Recent Downloads"));
        } else if (allRemoteWithoutFileName) {
            actions.prepend(i18n("Recent Connections"));
        } else if (allFolders) {
            actions.prepend(i18n("Recent Places"));
        }

        QAction *separatorAction = new QAction(parent);
        separatorAction->setSeparator(true);
        actions << QVariant::fromValue<QAction *>(separatorAction);

        QAction *action = new QAction(parent);
        if (allDownloads) {
            action->setText(i18nc("@action:inmenu", "Forget Recent Downloads"));
        } else if (allRemoteWithoutFileName) {
            action->setText(i18nc("@action:inmenu", "Forget Recent Connections"));
        } else if (allFolders) {
            action->setText(i18nc("@action:inmenu", "Forget Recent Places"));
        } else {
            action->setText(i18nc("@action:inmenu", "Forget Recent Files"));
        }
        // KDE-specific history cleanup has no verified Windows shell role.
        action->setProperty("agent", storageId);
        connect(action, &QAction::triggered, this, &Backend::handleRecentDocumentAction);
        actions << QVariant::fromValue<QAction *>(action);
    }

    return actions;
}

void Backend::handleRecentDocumentAction() const
{
    const QAction *action = qobject_cast<QAction *>(sender());

    if (!action) {
        return;
    }

    const QString agent = action->property("agent").toString();

    if (agent.isEmpty()) {
        return;
    }

    const QString desktopPath = action->property("entryPath").toUrl().toLocalFile();
    const QUrl url = action->data().toUrl();

    if (desktopPath.isEmpty() || url.isEmpty()) {
        auto query = UsedResources | Agent(agent) | Type::any() | Activity::current();

        KAStats::forgetResources(query);

        return;
    }

    KService::Ptr service = KService::serviceByDesktopPath(desktopPath);

    if (!service) {
        return;
    }

    // prevents using a service file that does not support opening a mime type for a file it created
    // for instance spectacle
    const auto mimetype = action->property("mimeType").toString();
    if (!mimetype.isEmpty() && mimetype != QLatin1String("application/octet-stream")) {
        if (!service->hasMimeType(mimetype)) {
            // needs to find the application that supports this mimetype
            service = KApplicationTrader::preferredService(mimetype);

            if (!service) {
                // no service found to handle the mimetype
                return;
            } else {
                qCWarning(TASKMANAGER_DEBUG) << "Preventing the file to open with " << service->desktopEntryName() << "no alternative found";
            }
        }
    }

    auto *job = new KIO::ApplicationLauncherJob(service);
    auto *delegate = new KNotificationJobUiDelegate;
    delegate->setAutoErrorHandlingEnabled(true);
    job->setUiDelegate(delegate);
    job->setUrls({url});
    job->start();
}

void Backend::setActionGroup(QAction *action) const
{
    if (action) {
        action->setActionGroup(m_actionGroup);
    }
}

QRect Backend::globalRect(QQuickItem *item) const
{
    if (!item || !item->window()) {
        return QRect();
    }

    QRect iconRect(item->x(), item->y(), item->width(), item->height());
    iconRect.moveTopLeft(item->parentItem()->mapToScene(iconRect.topLeft()).toPoint());
    iconRect.moveTopLeft(item->window()->mapToGlobal(iconRect.topLeft()));

    return iconRect;
}

bool Backend::isApplication(const QUrl &url) const
{
    if (!url.isValid() || !url.isLocalFile()) {
        return false;
    }

    const QString &localPath = url.toLocalFile();

    if (!KDesktopFile::isDesktopFile(localPath)) {
        return false;
    }

    KDesktopFile desktopFile(localPath);
    return desktopFile.hasApplicationType();
}

qint64 Backend::parentPid(qint64 pid) const
{
    KSysGuard::Processes procs;
    procs.updateOrAddProcess(pid);

    KSysGuard::Process *proc = procs.getProcess(pid);
    if (!proc) {
        return -1;
    }

    int parentPid = proc->parentPid();
    if (parentPid != -1) {
        procs.updateOrAddProcess(parentPid);

        KSysGuard::Process *parentProc = procs.getProcess(parentPid);
        if (!parentProc) {
            return -1;
        }

        if (!proc->cGroup().isEmpty() && parentProc->cGroup() == proc->cGroup()) {
            return parentProc->pid();
        }
    }

    return -1;
}

void Backend::setupShortcuts()
{
    static std::once_flag once;
    std::call_once(once, [] {
        auto *collection = new KActionCollection(QCoreApplication::instance());

        auto *activatePreviousTaskAction = collection->addAction(QStringLiteral("activate previous task manager entry"));
        QObject::connect(activatePreviousTaskAction, &QAction::triggered, collection, [](bool) {
            dispatchActivatePreviousTask();
        });
        activatePreviousTaskAction->setText(i18n("Activate Previous Task Manager Entry"));
        KGlobalAccel::self()->setGlobalShortcut(activatePreviousTaskAction, QList<QKeySequence>() << QKeySequence(Qt::META | Qt::CTRL | Qt::Key_PageUp));

        auto *activateNextTaskAction = collection->addAction(QStringLiteral("activate next task manager entry"));
        QObject::connect(activateNextTaskAction, &QAction::triggered, collection, [](bool) {
            dispatchActivateNextTask();
        });
        activateNextTaskAction->setText(i18n("Activate Next Task Manager Entry"));
        KGlobalAccel::self()->setGlobalShortcut(activateNextTaskAction, QList<QKeySequence>() << QKeySequence(Qt::META | Qt::CTRL | Qt::Key_PageDown));

        auto *moveTaskBackwardAction = collection->addAction(QStringLiteral("move active task to left"));
        QObject::connect(moveTaskBackwardAction, &QAction::triggered, collection, [](bool) {
            dispatchMoveActiveTaskBackward();
        });
        moveTaskBackwardAction->setText(i18n("Move Active Task Manager Entry Backward"));
        KGlobalAccel::self()->setGlobalShortcut(moveTaskBackwardAction,
                                                QList<QKeySequence>() << QKeySequence(Qt::META | Qt::CTRL | Qt::SHIFT | Qt::Key_PageUp));

        auto *moveTaskForwardAction = collection->addAction(QStringLiteral("move active task to right"));
        QObject::connect(moveTaskForwardAction, &QAction::triggered, collection, [](bool) {
            dispatchMoveActiveTaskForward();
        });
        moveTaskForwardAction->setText(i18n("Move Active Task Manager Entry Forward"));
        KGlobalAccel::self()->setGlobalShortcut(moveTaskForwardAction,
                                                QList<QKeySequence>() << QKeySequence(Qt::META | Qt::CTRL | Qt::SHIFT | Qt::Key_PageDown));

        for (int i = 0; i < 10; ++i) {
            const int entryNumber = i + 1;
            const auto key = static_cast<Qt::Key>(Qt::Key_0 + (entryNumber % 10));

            QAction *action = collection->addAction(QStringLiteral("activate task manager entry %1").arg(QString::number(entryNumber)));
            action->setText(i18n("Activate Task Manager Entry %1", entryNumber));
            KGlobalAccel::setGlobalShortcut(action, entryNumber < 10 ? QKeySequence(Qt::META | key) : QKeySequence());
            QObject::connect(action, &QAction::triggered, collection, [i](bool) {
                dispatchActivateTaskAtIndex(i);
            });
        }
    });
}

Backend *Backend::findTargetBackend()
{
    // Prefer a bar that shows tasks from all screens so that cycling
    // shortcuts can see the full task list.  Screen-filtered bars are
    // only used as fallback when no full-view bar has the active task.
    // This avoids trapping shortcuts on a screen-filtered bar that may
    // only have a single task to cycle through (e.g. when a grouped app
    // has its only visible child on that screen).

    Backend *fallback = nullptr;

    for (auto *instance : std::as_const(s_instances)) {
        if (instance->isDestroyedApplet() || !instance->m_hasActiveTask) {
            continue;
        }
        if (!instance->m_showsOnlyCurrentScreen) {
            return instance;
        }
        if (!fallback) {
            fallback = instance;
        }
    }

    return fallback;
}

void Backend::dispatchActivateTaskAtIndex(int index)
{
    // Prefer the same priority order as the other task shortcuts:
    // 1. Non-screen-filtered taskbar with the active task
    // 2. Screen-filtered taskbar with the active task
    if (auto *target = findTargetBackend()) {
        Q_EMIT target->activateTaskAtIndexRequested(index);
        return;
    }

    // If no task is active on any taskmanager (e.g. the user wants to
    // launch a pinned app), fallback: prefer a non-screen-filtered
    // instance, then the first available instance.
    Backend *fallback = nullptr;
    for (auto *instance : std::as_const(s_instances)) {
        if (instance->isDestroyedApplet()) {
            continue;
        }
        if (!instance->m_showsOnlyCurrentScreen) {
            Q_EMIT instance->activateTaskAtIndexRequested(index);
            return;
        }
        if (!fallback) {
            fallback = instance;
        }
    }
    if (fallback) {
        Q_EMIT fallback->activateTaskAtIndexRequested(index);
    }
}

void Backend::dispatchActivatePreviousTask()
{
    if (auto *target = findTargetBackend()) {
        Q_EMIT target->activatePreviousTaskRequested();
    }
}

void Backend::dispatchActivateNextTask()
{
    if (auto *target = findTargetBackend()) {
        Q_EMIT target->activateNextTaskRequested();
    }
}

void Backend::dispatchMoveActiveTaskBackward()
{
    if (auto *target = findTargetBackend()) {
        Q_EMIT target->moveActiveTaskBackwardRequested();
    }
}

void Backend::dispatchMoveActiveTaskForward()
{
    if (auto *target = findTargetBackend()) {
        Q_EMIT target->moveActiveTaskForwardRequested();
    }
}

#include "moc_backend.cpp"
