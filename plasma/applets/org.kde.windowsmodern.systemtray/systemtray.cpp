/*
    SPDX-FileCopyrightText: 2015 Marco Martin <mart@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include <optional>
#include <utility>

#include "debug.h"
#include "systemtray.h"
#include "panelglyph.h"

#include "plasmoidregistry.h"
#include "sortedsystemtraymodel.h"
#include "statusnotifieritemhost.h"
#include "statusnotifieritemsource.h"
#include "systemtraymodel.h"
#include "systemtraysettings.h"

#include <QAction>
#include <QCursor>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QGuiApplication>
#include <QFileInfo>
#include <QImageReader>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSet>
#include <QStandardPaths>
#include <QUrl>
#include <QMenu>
#include <QPainterPath>
#include <QRegion>
#include <QMetaMethod>
#include <QMetaObject>
#include <QPointer>
#include <QQueue>
#include <QQuickItem>
#include <QQuickWindow>
#include <QScreen>
#include <QTimer>

#include <Plasma/Applet>
#include <Plasma/Corona>
#include <Plasma/PluginLoader>

#include <KAcceleratorManager>
#include <KAuthorized>
#include <KGlobalAccel>
#include <KIconLoader>
#include <QRegularExpression>
#include <KLocalizedString>
#include <KIO/ApplicationLauncherJob>
#include <KIO/CommandLauncherJob>
#include <KNotificationJobUiDelegate>
#include <KPluginMetaData>
#include <KService>
#include <KSycoca>
#include <KActionCollection>
#include <KSharedConfig>
#include <KWindowSystem>
#include <KWindowEffects>

using namespace Qt::StringLiterals;

SystemTray::SystemTray(QObject *parent, const KPluginMetaData &data, const QVariantList &args)
    : Plasma::Containment(parent, data, args)
{
    connect(KSycoca::self(), &KSycoca::databaseChanged, this, &SystemTray::castAvailabilityChanged);
    setHasConfigurationInterface(true);
    setContainmentDisplayHints(Plasma::Types::ContainmentDrawsPlasmoidHeading | Plasma::Types::ContainmentForcesSquarePlasmoids);

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
        for (const auto &entry : std::as_const(m_shellPopups)) {
            auto *window = entry.data();
            if (window && window->isVisible() && !window->property("wmKeepOnDeactivate").toBool())
                dismissShellPopup(window);
        }
    });
}

bool SystemTray::shellPopupHasFocus() const
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

void SystemTray::scheduleShellPopupDismissal()
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

void SystemTray::dismissShellPopup(QWindow *window)
{
    if (!window || !window->isVisible())
        return;
    // The QML owner updates its own route/state before hiding the window.
    if (!QMetaObject::invokeMethod(window, "closeCoordinatedPopup", Qt::DirectConnection))
        window->hide();
}

void SystemTray::prepareShellPopup(const QString &role, QWindow *window)
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

void SystemTray::restoreShellPopupFocus()
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

void SystemTray::registerClipboardShortcut()
{
    // Plasma's primary panel is screen 0 (the same convention used by
    // the installer for Win+A and Win+N). Do not register duplicates on
    // secondary panels. The action is owned by the tray, not by plasmashell.
    static QPointer<QAction> action;
    if (action || screen() != 0) {
        return;
    }
    action = new QAction(i18n("Open clipboard history"), this);
    action->setObjectName(QStringLiteral("show-history"));
    action->setProperty("componentName", QStringLiteral("org.kde.windowsmodern.clipboard"));
    action->setProperty("componentDisplayName", QStringLiteral("Windows Modern"));
    connect(action, &QAction::triggered, this, [this] {
        if (appletForPluginId(QStringLiteral("org.kde.plasma.clipboard"))) {
            Q_EMIT clipboardHistoryRequested();
        } else {
            // Preserve the native history even if the tray applet was disabled.
            QDBusConnection::sessionBus().asyncCall(QDBusMessage::createMethodCall(
                QStringLiteral("org.kde.klipper"), QStringLiteral("/klipper"),
                QStringLiteral("org.kde.klipper.klipper"), QStringLiteral("showKlipperPopupMenu")));
        }
    });
    // Register a real live action. The installer migrates Meta+V only
    // after finding it and checking for competing bindings.
    KGlobalAccel::self()->setShortcut(action, QList<QKeySequence>{});
}

void SystemTray::registerRunShortcut()
{
    // Like clipboard history, only the primary tray owns this action.
    static QPointer<QAction> action;
    if (action || screen() != 0) {
        return;
    }
    action = new QAction(i18n("Open Run dialog"), this);
    action->setObjectName(QStringLiteral("show-run"));
    action->setProperty("componentName", QStringLiteral("org.kde.windowsmodern.run"));
    action->setProperty("componentDisplayName", QStringLiteral("Windows Modern"));
    connect(action, &QAction::triggered, this, &SystemTray::runDialogRequested);
    KGlobalAccel::self()->setShortcut(action, QList<QKeySequence>{});
}

QRect SystemTray::runDialogArea(QQuickItem *anchor) const
{
    auto *output = QGuiApplication::screenAt(QCursor::pos());
    if (!output && anchor && anchor->window()) {
        output = anchor->window()->screen();
    }
    if (!output) {
        output = QGuiApplication::primaryScreen();
    }
    return output ? output->availableGeometry() : QRect();
}

bool SystemTray::runCommand(const QString &command)
{
    const QString value = command.trimmed();
    // Match KRunner's shell runner authorization checks.
    if (value.isEmpty() || !KAuthorized::authorize(QStringLiteral("run_command"))
        || !KAuthorized::authorize(KAuthorized::SHELL_ACCESS)) {
        return false;
    }
    auto *job = new KIO::CommandLauncherJob(value, this);
    job->setUiDelegate(new KNotificationJobUiDelegate(KJobUiDelegate::AutoHandlingEnabled));
    job->start();
    return true;
}

bool SystemTray::accessibilityAvailable() const
{
    return KPluginMetaData::findPluginById(u"plasma/kcms/systemsettings"_s, u"kcm_access"_s).isValid();
}

bool SystemTray::castAvailable() const
{
    return bool(KService::serviceByDesktopName(u"org.gnome.NetworkDisplays"_s));
}

void SystemTray::openCast()
{
    const auto service = KService::serviceByDesktopName(u"org.gnome.NetworkDisplays"_s);
    if (!service) {
        return;
    }
    auto *job = new KIO::ApplicationLauncherJob(service);
    job->setUiDelegate(new KNotificationJobUiDelegate(KJobUiDelegate::AutoErrorHandlingEnabled));
    job->start();
}

QRectF SystemTray::panelGlyphBounds(const QString &source)
{
    const QRectF full(0, 0, 1, 1);
    const QUrl url(source);
    QString path = url.isLocalFile() ? url.toLocalFile() : source;
    // Resolve legitimate theme names as well as direct Windows theme paths.
    // Never fetch a URL or decode an arbitrary remote resource.
    static const QRegularExpression iconName(QStringLiteral("^[A-Za-z0-9_.-]+$"));
    if (!path.startsWith(QLatin1Char('/')) && iconName.match(path).hasMatch())
        path = KIconLoader::global()->iconPath(path, -16, true);
    if (!path.startsWith(QLatin1Char('/')) ||
        (!path.endsWith(QStringLiteral(".svg"), Qt::CaseInsensitive) &&
         !path.endsWith(QStringLiteral(".svgz"), Qt::CaseInsensitive)))
        return full;
    const auto cached = m_panelGlyphBounds.constFind(path);
    if (cached != m_panelGlyphBounds.constEnd()) return cached.value();
    const QFileInfo file(path);
    if (!file.isFile() || file.size() > 2 * 1024 * 1024) return full;
    const QRectF bounds = WindowsTray::panelGlyphFileBounds(path);
    // The set of tray roles is small. Bound the cache even for changing
    // icon files; source changes recalculate, frames and DPI changes do not.
    if (m_panelGlyphBounds.size() >= 128) m_panelGlyphBounds.clear();
    m_panelGlyphBounds.insert(path, bounds);
    return bounds;
}

void SystemTray::setNotificationPopupSlide(QQuickItem *content)
{
    // Keep the native shell positioning and let KWin animate the actual
    // window. Only the notification flyout uses this independent edge.
    if (auto *window = content ? content->window() : nullptr) {
        KWindowEffects::slideWindow(window, KWindowEffects::RightEdge, -1);
    }
}

bool SystemTray::setSplitPopupBlur(QQuickItem *content, QQuickItem *first, QQuickItem *second,
                                   qreal radius, bool enabled)
{
    auto *window = content ? content->window() : nullptr;
    if (!window || !window->isVisible()) {
        return false;
    }
    // Honor the actual compositor/user setting. Never advertise an
    // acrylic surface when blur is unavailable or disabled.
    KConfig config(QStringLiteral("kwinrc"), KConfig::NoGlobals);
    enabled = enabled && KConfigGroup(&config, QStringLiteral("Plugins")).readEntry("blurEnabled", true)
        && KWindowEffects::isEffectAvailable(KWindowEffects::BlurBehind);
    QRegion mask;
    if (enabled) {
        for (auto *item : {first, second}) {
            if (!item || item->window() != window || !item->isVisible()
                || item->width() <= 0 || item->height() <= 0) {
                enabled = false;
                break;
            }
            QPainterPath path;
            path.addRoundedRect(item->mapRectToScene(item->boundingRect()), radius, radius);
            mask |= QRegion(path.toFillPolygon().toPolygon(), Qt::WindingFill);
        }
    }
    // An empty QRegion means whole-window blur in KWindowEffects.
    // Explicitly disable in that case so the desktop gap stays clear.
    enabled = enabled && !mask.isEmpty();
    KWindowEffects::enableBlurBehind(window, enabled, enabled ? mask : QRegion());
    return enabled;
}

SystemTray::~SystemTray()
{
    delete m_settings;
}

void SystemTray::init()
{
    migrateFromSystrayContainer();

    Containment::init();

    initSettingsAndRegistry();

    connect(this, &Containment::appletAdded, this, [this](Plasma::Applet *applet) {
        disconnect(applet, &Applet::activated, this, &Applet::activated);
    });

    auto config = KSharedConfig::openConfig(QStringLiteral("kdeglobals"), KConfig::NoGlobals);
    if (KWindowSystem::isPlatformWayland()) {
        KConfigGroup kscreenGroup = config->group(QStringLiteral("KScreen"));
        m_xwaylandClientsScale = kscreenGroup.readEntry("XwaylandClientsScale", true);
    }

    m_configWatcher = KConfigWatcher::create(config);
    connect(m_configWatcher.data(), &KConfigWatcher::configChanged, this, [this](const KConfigGroup &group, const QByteArrayList &names) {
        if (KWindowSystem::isPlatformWayland() && group.name() == u"KScreen" && names.contains(QByteArrayLiteral("XwaylandClientsScale"))) {
            m_xwaylandClientsScale = group.readEntry("XwaylandClientsScale", true);
        } else if (group.name() == u"General"
                   && (names.contains(QByteArrayLiteral("AccentColor"))
                       || names.contains(QByteArrayLiteral("accentColorFromWallpaper"))
                       || names.contains(QByteArrayLiteral("ColorScheme")))) {
            // Native preferences may change without a different highlight
            // color. Use the existing debounced accent sync in the applet.
            Q_EMIT accentPreferencesChanged();
        } else if (group.name() == u"WindowsModernAccent" && names.contains(QByteArrayLiteral("Palette"))) {
            refreshWallpaperWatch(group);
        }
    });

    // Use the existing tray and debounced sync rather than a polling process.
    // Wallpaper changes through the shell API and ordinary desktop config
    // saves both reach this path, as do activity and screen changes.
    if (auto *shell = corona()) {
        connect(shell, &Plasma::Corona::configSynced, this, &SystemTray::scheduleWallpaperAccentSync);
        connect(shell, &Plasma::Corona::screenAdded, this, &SystemTray::scheduleWallpaperAccentSync);
        connect(shell, &Plasma::Corona::screenRemoved, this, &SystemTray::scheduleWallpaperAccentSync);
    }
    auto bus = QDBusConnection::sessionBus();
    bus.connect(u"org.kde.plasmashell"_s, u"/PlasmaShell"_s, u"org.kde.PlasmaShell"_s,
                u"wallpaperChanged"_s, this, SLOT(scheduleWallpaperAccentSync()));
    bus.connect(u"org.kde.ActivityManager"_s, u"/ActivityManager/Activities"_s, u"org.kde.ActivityManager.Activities"_s,
                u"CurrentActivityChanged"_s, this, SLOT(scheduleWallpaperAccentSync()));
    auto rearm = [this] {
        auto globals = KSharedConfig::openConfig(QStringLiteral("kdeglobals"), KConfig::NoGlobals);
        refreshWallpaperWatch(globals->group(QStringLiteral("WindowsModernAccent")));
    };
    connect(&m_wallpaperWatch, &QFileSystemWatcher::fileChanged, this, [this, rearm](const QString &) {
        rearm();
        scheduleWallpaperAccentSync();
    });
    connect(&m_wallpaperWatch, &QFileSystemWatcher::directoryChanged, this, [this, rearm](const QString &path) {
        auto before = m_wallpaperWatch.files();
        before.sort();
        rearm();
        auto after = m_wallpaperWatch.files();
        after.sort();
        // Ignore unrelated writes in the config directory (including our
        // own kdeglobals transactions). A reappearing watched file is relevant.
        if (path != QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) || before != after) {
            scheduleWallpaperAccentSync();
        }
    });
    refreshWallpaperWatch(config->group(QStringLiteral("WindowsModernAccent")));
}

void SystemTray::scheduleWallpaperAccentSync()
{
    if (m_automaticWallpaperAccent) {
        Q_EMIT accentPreferencesChanged();
    }
}

void SystemTray::refreshWallpaperWatch(const KConfigGroup &group)
{
    const auto state = QJsonDocument::fromJson(group.readEntry("Palette", QString()).toUtf8()).object();
    m_automaticWallpaperAccent = state.value(u"source"_s).toString() == u"automatic";
    QSet<QString> wanted;
    if (m_automaticWallpaperAccent) {
        // Some wallpaper KCM paths sync the containment config directly
        // rather than emitting the shell's wallpaperChanged signal.
        const auto configDir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
        if (!configDir.isEmpty() && QFileInfo(configDir).isDir()) {
            wanted.insert(configDir);
            const auto appletConfig = configDir + u"/plasma-org.kde.plasma.desktop-appletsrc"_s;
            if (QFileInfo(appletConfig).isFile()) {
                wanted.insert(appletConfig);
            }
        }
        const auto images = state.value(u"wallpapers"_s).toArray();
        if (images.size() <= 16) {
            for (const auto &image : images) {
                const QFileInfo file(image.toObject().value(u"path"_s).toString());
                if (!file.isAbsolute()) {
                    continue;
                }
                if (file.isFile()) {
                    wanted.insert(file.absoluteFilePath());
                }
                // Watch the parent as well so an atomic replacement or
                // temporary deletion can be detected and the file rearmed.
                if (QFileInfo(file.absolutePath()).isDir()) {
                    wanted.insert(file.absolutePath());
                }
            }
        }
    }
    const auto current = m_wallpaperWatch.files() + m_wallpaperWatch.directories();
    for (const auto &path : current) {
        if (!wanted.remove(path)) {
            m_wallpaperWatch.removePath(path);
        }
    }
    if (!wanted.isEmpty()) {
        m_wallpaperWatch.addPaths(wanted.values());
    }
}

void SystemTray::initSettingsAndRegistry()
{
    if (!m_settings) {
        m_settings = new SystemTraySettings(configScheme(), this);
        connect(m_settings, &SystemTraySettings::enabledPluginsChanged, this, &SystemTray::onEnabledAppletsChanged);
    }

    if (!m_plasmoidRegistry) {
        m_plasmoidRegistry = new PlasmoidRegistry(m_settings, this);
        connect(m_plasmoidRegistry, &PlasmoidRegistry::plasmoidEnabled, this, &SystemTray::startApplet);
        connect(m_plasmoidRegistry, &PlasmoidRegistry::plasmoidStopped, this, &SystemTray::stopApplet);
    }
}

void SystemTray::migrateFromSystrayContainer()
{
    KConfigGroup rootCg(corona()->config(), QStringLiteral("Containments"));
    KConfigGroup ownCg = KConfigGroup(config());
    KConfigGroup oldAppletCg(&ownCg, QStringLiteral("Configuration"));
    const uint oldSystrayId = oldAppletCg.readEntry(QStringLiteral("SystrayContainmentId"), 0);

    if (oldSystrayId == 0) {
        return;
    }

    KConfigGroup oldContCg = KConfigGroup(&rootCg, QString::number(oldSystrayId));

    QQueue<QPair<KConfigGroup, KConfigGroup>> queue;
    queue.enqueue(qMakePair(oldContCg, ownCg));
    while (!queue.isEmpty()) {
        QPair<KConfigGroup, KConfigGroup> current = queue.dequeue();
        const KConfigGroup &currentSource = current.first;
        KConfigGroup &currentDest = current.second;

        const QMap<QString, QString> entries = currentSource.entryMap();
        for (auto it = entries.constBegin(); it != entries.constEnd(); ++it) {
            currentDest.writeEntry(it.key(), currentSource.readEntry(it.key(), QString()));
        }

        const QStringList groups = currentSource.groupList();
        for (const QString &group : groups) {
            KConfigGroup sourceSubGroup = currentSource.group(group);
            KConfigGroup destSubGroup = currentDest.group(group);
            queue.enqueue(qMakePair(sourceSubGroup, destSubGroup));
        }
    }

    for (Plasma::Containment *cont : corona()->containments()) {
        if (cont->id() == oldSystrayId) {
            delete cont;
            break;
        }
    }
    rootCg.deleteGroup(QString::number(oldSystrayId));

    oldAppletCg.deleteEntry(QStringLiteral("SystrayContainmentId"));

    for (Applet *a : applets()) {
        a->configChanged();
    }
}

void SystemTray::restoreContents(KConfigGroup &group)
{
    if (!isContainment()) {
        qCWarning(SYSTEM_TRAY) << "Loaded as an applet, this shouldn't have happened";
        return;
    }

    KConfigGroup shortcutConfig(&group, u"Shortcuts"_s);
    QString shortcutText = shortcutConfig.readEntryUntranslated("global", QString());
    if (!shortcutText.isEmpty()) {
        setGlobalShortcut(QKeySequence(shortcutText));
    }

    KConfigGroup cg = group.group(u"Applets"_s);
    for (const QString &group : cg.groupList()) {
        KConfigGroup appletConfig(&cg, group);
        QString plugin = appletConfig.readEntry("plugin");
        if (!plugin.isEmpty()) {
            m_configGroupIds[plugin] = group.toInt();
        }
    }

    initSettingsAndRegistry();
    m_plasmoidRegistry->init();
}

void SystemTray::showPlasmoidMenu(QQuickItem *appletInterface, int x, int y)
{
    if (!appletInterface) {
        return;
    }

    auto *applet = appletInterface->property("_plasma_applet").value<Plasma::Applet *>();

    QPointF pos = appletInterface->mapToScene(QPointF(x, y));

    if (appletInterface->window() && appletInterface->window()->screen()) {
        pos = appletInterface->window()->mapToGlobal(pos.toPoint());
    } else {
        pos = QPoint();
    }

    auto *desktopMenu = new QMenu;
    desktopMenu->setAttribute(Qt::WA_TranslucentBackground);
    connect(this, &QObject::destroyed, desktopMenu, &QMenu::close);
    desktopMenu->setAttribute(Qt::WA_DeleteOnClose);

    auto ungrabMouseHack = [appletInterface]() {
        if (appletInterface->window() && appletInterface->window()->mouseGrabberItem()) {
            appletInterface->window()->mouseGrabberItem()->ungrabMouse();
        }
    };

    QTimer::singleShot(0, appletInterface, ungrabMouseHack);

    Q_EMIT applet->contextualActionsAboutToShow();
    const auto contextActions = applet->contextualActions();
    for (QAction *action : contextActions) {
        if (action) {
            desktopMenu->addAction(action);
        }
    }

    if (applet->internalAction(QStringLiteral("configure"))) {
        desktopMenu->addAction(applet->internalAction(QStringLiteral("configure")));
    }

    if (desktopMenu->isEmpty()) {
        delete desktopMenu;
        return;
    }

    KAcceleratorManager::manage(desktopMenu);

    desktopMenu->winId();
    desktopMenu->windowHandle()->setTransientParent(appletInterface->window());
    desktopMenu->popup(pos.toPoint());
}

QPointF SystemTray::popupPosition(QQuickItem *visualParent, int x, int y)
{
    if (!visualParent) {
        return {0, 0};
    }

    QPointF pos = visualParent->mapToScene(QPointF(x, y));

    QQuickWindow *const window = visualParent->window();
    if (window && window->screen()) {
        pos = window->mapToGlobal(pos.toPoint());
    }

    return pos;
}

bool SystemTray::isSystemTrayApplet(const QString &appletId)
{
    if (m_plasmoidRegistry) {
        return m_plasmoidRegistry->isSystemTrayApplet(appletId);
    }
    return false;
}

QQuickItem *SystemTray::appletForPluginId(const QString &pluginId)
{
    if (!m_plasmoidModel || pluginId.isEmpty()) {
        return nullptr;
    }
    const auto roles = m_plasmoidModel->roleNames();
    int itemIdRole = -1, appletRole = -1;
    for (auto it = roles.constBegin(); it != roles.constEnd(); ++it) {
        if (it.value() == QByteArrayLiteral("itemId")) {
            itemIdRole = it.key();
        } else if (it.value() == QByteArrayLiteral("applet")) {
            appletRole = it.key();
        }
    }
    if (itemIdRole < 0 || appletRole < 0) {
        return nullptr;
    }
    for (int i = 0; i < m_plasmoidModel->rowCount(); ++i) {
        const QModelIndex idx = m_plasmoidModel->index(i, 0);
        if (m_plasmoidModel->data(idx, itemIdRole).toString() == pluginId) {
            return m_plasmoidModel->data(idx, appletRole).value<QQuickItem *>();
        }
    }
    return nullptr;
}

SystemTrayModel *SystemTray::systemTrayModel()
{
    if (!m_systemTrayModel) {
        m_systemTrayModel = new SystemTrayModel(this);

        m_plasmoidModel = new PlasmoidModel(m_settings, m_plasmoidRegistry, m_systemTrayModel);
        connect(this, &SystemTray::appletAdded, m_plasmoidModel, &PlasmoidModel::addApplet);
        connect(this, &SystemTray::appletRemoved, m_plasmoidModel, &PlasmoidModel::removeApplet);
        for (auto applet : applets()) {
            m_plasmoidModel->addApplet(applet);
        }

        m_statusNotifierModel = new StatusNotifierModel(m_settings, m_systemTrayModel);

        m_systemTrayModel->addSourceModel(m_plasmoidModel);
        m_systemTrayModel->addSourceModel(m_statusNotifierModel);
        m_systemTrayModel->addSourceModel(new BackgroundAppsFilteredModel(new BackgroundAppsModel(m_settings, m_systemTrayModel), m_systemTrayModel));
    }

    return m_systemTrayModel;
}

QAbstractItemModel *SystemTray::sortedSystemTrayModel()
{
    if (!m_sortedSystemTrayModel) {
        m_sortedSystemTrayModel = new SortedSystemTrayModel(SortedSystemTrayModel::SortingType::SystemTray, this);
        m_sortedSystemTrayModel->setSourceModel(systemTrayModel());
    }
    return m_sortedSystemTrayModel;
}

QAbstractItemModel *SystemTray::configSystemTrayModel()
{
    if (!m_configSystemTrayModel) {
        m_configSystemTrayModel = new SortedSystemTrayModel(SortedSystemTrayModel::SortingType::ConfigurationPage, this);
        m_configSystemTrayModel->setSourceModel(systemTrayModel());
    }
    return m_configSystemTrayModel;
}

void SystemTray::onEnabledAppletsChanged()
{
    const auto appletsList = applets();
    for (Plasma::Applet *applet : appletsList) {
        if (!applet->pluginMetaData().isValid()) {
            applet->config().parent().deleteGroup();
            delete applet;
        } else {
            const QString task = applet->pluginMetaData().pluginId();
            if (!m_settings->isEnabledPlugin(task)) {
                applet->config().parent().deleteGroup();
                delete applet;
                m_configGroupIds.remove(task);
            }
        }
    }
}

void SystemTray::startApplet(const QString &pluginId)
{
    const auto appletsList = applets();
    for (Plasma::Applet *applet : appletsList) {
        if (!applet->pluginMetaData().isValid()) {
            continue;
        }

        if (pluginId == applet->pluginMetaData().pluginId()) {
            if (!applet->destroyed()) {
                return;
            }
        }
    }

    qCDebug(SYSTEM_TRAY) << "Adding applet:" << pluginId;

    if (m_configGroupIds.contains(pluginId)) {
        auto applet = Plasma::PluginLoader::self()->loadApplet(pluginId, m_configGroupIds.value(pluginId), QVariantList());
        if (!applet) {
            qCWarning(SYSTEM_TRAY) << "Unable to find applet" << pluginId;
            return;
        }
        applet->setProperty("org.kde.plasma:force-create", true);
        addApplet(std::move(applet));
    } else {
        Applet *applet = createApplet(pluginId, QVariantList() << u"org.kde.plasma:force-create"_s);
        if (applet) {
            m_configGroupIds[pluginId] = applet->id();
        }
    }
}

void SystemTray::stopApplet(const QString &pluginId)
{
    const auto appletsList = applets();
    for (Plasma::Applet *applet : appletsList) {
        if (applet->pluginMetaData().isValid() && pluginId == applet->pluginMetaData().pluginId()) {
            delete applet;
        }
    }
}

void SystemTray::stackItemBefore(QQuickItem *newItem, QQuickItem *beforeItem)
{
    if (!newItem || !beforeItem) {
        return;
    }
    newItem->stackBefore(beforeItem);
}

void SystemTray::stackItemAfter(QQuickItem *newItem, QQuickItem *afterItem)
{
    if (!newItem || !afterItem) {
        return;
    }
    newItem->stackAfter(afterItem);
}

void SystemTray::activate(const QString &service, QPoint pos, QQuickItem *statusNotifierIcon)
{
    const auto source = StatusNotifierItemHost::self()->itemForService(service);

    if (!source) {
        qCWarning(SYSTEM_TRAY) << "activate: Could not find item for service" << service;
        return;
    }

    // activate() is a D-Bus round trip; the tray delegate can be destroyed
    // (layout change, item hidden) before the reply arrives. Guard it.
    QPointer<QQuickItem> iconGuard(statusNotifierIcon);
    connect(
        source,
        &StatusNotifierItemSource::activateResult,
        this,
        [this, service, pos, iconGuard](bool res) {
            if (!res) {
                openContextMenu(service, pos, iconGuard.data());
            }
        },
        Qt::SingleShotConnection);

    source->activate(pos.x(), pos.y());
}

void SystemTray::secondaryActivate(const QString &service, QPoint pos)
{
    const auto source = StatusNotifierItemHost::self()->itemForService(service);

    if (!source) {
        qCWarning(SYSTEM_TRAY) << "secondaryActivate: Could not find item for service" << service;
        return;
    }

    source->secondaryActivate(pos.x(), pos.y());
}

void SystemTray::openContextMenu(const QString &service, QPoint pos, QQuickItem *statusNotifierIcon)
{
    const auto source = StatusNotifierItemHost::self()->itemForService(service);

    if (!source) {
        qCWarning(SYSTEM_TRAY) << "openContextMenu: Could not find item for service" << service;
        return;
    }

    QPointer<QQuickItem> iconGuard(statusNotifierIcon);
    connect(
        source,
        &StatusNotifierItemSource::contextMenuReady,
        this,
        [this, iconGuard, pos](QMenu *menu) {
            if (menu && !menu->isEmpty()) {
                KAcceleratorManager::manage(menu);

                // The icon may have been destroyed while the menu was fetched
                // over D-Bus; still show the menu, just without a parent.
                QQuickWindow *iconWindow = iconGuard ? iconGuard->window() : nullptr;
                menu->winId();
                if (iconWindow) {
                    menu->windowHandle()->setTransientParent(iconWindow);
                }
                menu->popup(pos);

                if (iconWindow) {
                    if (auto item = iconWindow->mouseGrabberItem()) {
                        item->ungrabMouse();
                    }
                }
            }
        },
        Qt::SingleShotConnection);

    source->contextMenu(pos.x(), pos.y());
}

void SystemTray::scroll(const QString &service, int delta, const QString &direction)
{
    const auto source = StatusNotifierItemHost::self()->itemForService(service);

    if (!source) {
        qCWarning(SYSTEM_TRAY) << "scroll: Could not find item for service" << service;
        return;
    }

    source->scroll(delta, direction);
}

K_PLUGIN_CLASS_WITH_JSON(SystemTray, "metadata.json")

#include "systemtray.moc"

#include "moc_systemtray.cpp"
