/*
    SPDX-FileCopyrightText: 2015 Marco Martin <mart@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include <cmath>
#include <limits>
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
#include <QDir>
#include <QEvent>
#include <QGuiApplication>
#include <QFileInfo>
#include <QImageReader>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSet>
#include <QStandardPaths>
#include <QUrl>
#include <QUrlQuery>
#include <QMenu>
#include <QPainterPath>
#include <QRegion>
#include <QMetaMethod>
#include <QMetaObject>
#include <QMetaProperty>
#include <QPointer>
#include <QQueue>
#include <QQuickItem>
#include <QQuickWindow>
#include <QScreen>
#include <QTimer>
#include <QVariant>

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
#include <KPackage/Package>
#include <KPackage/PackageLoader>
#include <KService>
#include <KSycoca>
#include <KActionCollection>
#include <KSharedConfig>
#include <KWindowSystem>
#include <KWindowEffects>

using namespace Qt::StringLiterals;

// Read-only, shell-local adapter for Plasma 6.8's native image wallpaper.
// Its QML property contract is checked at runtime. An unknown plugin,
// incomplete load or preview must fail closed. Scheduled wallpapers
// contribute their settled native endpoint, never a guessed blend.
class WallpaperAccentSource final : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.WindowsModern.Wallpaper")
public:
    explicit WallpaperAccentSource(Plasma::Corona *shell)
        : QObject(shell), m_shell(shell)
    {
        setObjectName(u"windowsModernWallpaperAccentSource"_s);
        connect(shell, &Plasma::Corona::containmentAdded, this, &WallpaperAccentSource::refresh, Qt::QueuedConnection);
        connect(shell, &Plasma::Corona::configSynced, this, &WallpaperAccentSource::refresh);
        // Reconnect to newly created nested QML objects before notifying
        // the tray, even when automatic mode has no snapshot in flight.
        connect(this, &WallpaperAccentSource::structureChanged,
                this, &WallpaperAccentSource::refresh, Qt::QueuedConnection);
        refreshConnections();
    }

    static WallpaperAccentSource *forShell(Plasma::Corona *shell)
    {
        if (auto *existing = shell->findChild<WallpaperAccentSource *>(
                u"windowsModernWallpaperAccentSource"_s, Qt::FindDirectChildrenOnly)) {
            ++existing->m_users;
            return existing;
        }
        auto *source = new WallpaperAccentSource(shell);
        if (!QDBusConnection::sessionBus().registerObject(
                u"/WindowsModernWallpaper"_s, source, QDBusConnection::ExportScriptableSlots)) {
            delete source;
            return nullptr;
        }
        return source;
    }

    void release()
    {
        if (--m_users == 0) {
            QDBusConnection::sessionBus().unregisterObject(u"/WindowsModernWallpaper"_s);
            delete this;
        }
    }

public Q_SLOTS:
    Q_SCRIPTABLE QString snapshot(const QString &activity)
    {
        return snapshotImpl(activity, false);
    }

    Q_SCRIPTABLE QString primarySnapshot(const QString &activity)
    {
        return snapshotImpl(activity, true);
    }

private:
    QString snapshotImpl(const QString &activity, bool primaryOnly)
    {
        refreshConnections();
        const uint count = m_shell->numScreens();
        if (count == 0 || count > 16) {
            return failure(u"Desktop screen count is unavailable"_s);
        }
        // Global SVG material uses only screen 0. Automatic accent still
        // requires a settled image for every active screen.
        const uint selectedCount = primaryOnly ? 1u : count;
        const bool noActivity = activity.isEmpty()
            || activity == u"00000000-0000-0000-0000-000000000000";
        QHash<uint, Plasma::Containment *> desktops;
        for (auto *containment : m_shell->containments()) {
            if (!isDesktop(containment) || containment->screen() >= selectedCount) {
                continue;
            }
            const auto id = containment->activity();
            if (!id.isEmpty() && (noActivity
                    ? id != u"00000000-0000-0000-0000-000000000000"
                    : id != activity)) {
                continue;
            }
            auto *root = wallpaperRoot(containment);
            if (!root || !root->isVisible() || !root->window() || !root->window()->isVisible()) {
                continue;
            }
            if (desktops.contains(containment->screen())) {
                return failure(u"Ambiguous active desktop wallpaper"_s);
            }
            desktops.insert(containment->screen(), containment);
        }
        QJsonArray images;
        for (uint screen = 0; screen < selectedCount; ++screen) {
            auto *desktop = desktops.value(screen, nullptr);
            if (!desktop) {
                return failure(u"Active wallpaper is not ready on screen %1"_s.arg(screen));
            }
            const auto plugin = desktop->wallpaperPlugin();
            if (plugin != u"org.kde.image" && plugin != u"org.kde.slideshow") {
                return failure(u"Unsupported wallpaper plugin on screen %1"_s.arg(screen));
            }
            auto *root = wallpaperRoot(desktop);
            if (!root || !root->isVisible() || !root->window() || !root->window()->isVisible()) {
                return failure(u"Active wallpaper is not ready on screen %1"_s.arg(screen));
            }
            auto *config = root->property("configuration").value<QObject *>();
            const auto loading = root->property("loading");
            if (!config || !loading.isValid() || loading.toBool()) {
                return failure(u"Wallpaper is loading on screen %1"_s.arg(screen));
            }
            // The image plugin has PreviewImage; the native slideshow
            // plugin intentionally has no such config entry and does not
            // use the preview source in its rendering branch.
            if (plugin == u"org.kde.image") {
                const auto preview = config->property("PreviewImage");
                if (!preview.isValid() || (!preview.toString().isEmpty() && preview.toString() != u"null")) {
                    return failure(u"Wallpaper preview or unknown configuration on screen %1"_s.arg(screen));
                }
            }
            auto *stack = imageStack(root);
            if (!stack || stack->property("pendingImage").value<QObject *>()
                || stack->property("busy").toBool()) {
                return failure(u"Wallpaper image is not settled on screen %1"_s.arg(screen));
            }
            auto *current = stack->property("currentItem").value<QObject *>();
            auto *proxy = stack->property("mediaProxy").value<QObject *>();
            if (!current || !proxy) {
                return failure(u"Wallpaper selection is not ready on screen %1"_s.arg(screen));
            }
            // Plasma deliberately blocks the modelImage notify signal on
            // theme changes. Read MediaProxy directly, as loadImage does,
            // rather than the potentially stale QML binding on the stack.
            const auto selected = proxy->property("modelImage").toUrl();
            // Image.Ready and TransientImage.Ready are both 1. Require the
            // loaded component to agree with the actual native selection.
            if (current->property("status").toInt() != 1
                || current->property("source").toUrl() != selected) {
                return failure(u"Wallpaper selection is changing on screen %1"_s.arg(screen));
            }
            QString path;
            if (selected.fragment() == u"day-night") {
                auto *endpoint = scheduledEndpoint(qobject_cast<QQuickItem *>(current));
                if (!endpoint || !endpoint->window()) {
                    return failure(u"Scheduled wallpaper is between stable images on screen %1"_s.arg(screen));
                }
                const auto source = endpoint->property("source").toUrl();
                const auto requested = (endpoint->size() * endpoint->window()->effectiveDevicePixelRatio()).toSize();
                path = scheduledFile(source, selected, requested);
            } else if (selected.isLocalFile() && (selected.host().isEmpty() || selected.host() == u"localhost")) {
                path = selected.toLocalFile();
            }
            const QFileInfo file(path);
            if (!file.isAbsolute() || !file.isFile()) {
                return failure(u"Selected wallpaper is not a supported local image on screen %1"_s.arg(screen));
            }
            images.append(QJsonObject{{u"screen"_s, int(screen)}, {u"path"_s, file.absoluteFilePath()}});
        }
        return json(QJsonObject{{u"screens"_s, int(selectedCount)}, {u"images"_s, images}});
    }

Q_SIGNALS:
    void changed();
    void structureChanged();

private:
    static bool isDesktop(Plasma::Containment *containment)
    {
        const auto type = containment->containmentType();
        return type == Plasma::Containment::Desktop || type == Plasma::Containment::Custom
            || type == Plasma::Containment::NoContainment;
    }

    static QQuickItem *wallpaperRoot(Plasma::Containment *containment)
    {
        return qobject_cast<QQuickItem *>(containment->property("wallpaperGraphicsObject").value<QObject *>());
    }

    static QQuickItem *imageStack(QQuickItem *root)
    {
        if (!root) {
            return nullptr;
        }
        QQuickItem *result = nullptr;
        for (auto *child : root->childItems()) {
            if (child->property("wallpaperInterface").value<QObject *>() != root
                || !child->property("mediaProxy").value<QObject *>()
                || !child->property("modelImage").isValid()
                || child->metaObject()->indexOfProperty("currentItem") < 0
                || child->metaObject()->indexOfProperty("pendingImage") < 0) {
                continue;
            }
            if (result) {
                return nullptr;
            }
            result = child;
        }
        return result;
    }

    static QQuickItem *dayNightView(QQuickItem *component)
    {
        if (!component) {
            return nullptr;
        }
        QQuickItem *view = nullptr;
        for (auto *child : component->childItems()) {
            const auto *meta = child->metaObject();
            if (meta->indexOfProperty("snapshot") < 0 || meta->indexOfProperty("nextItem") < 0
                || meta->indexOfProperty("currentItem") < 0 || meta->indexOfProperty("busy") < 0) {
                continue;
            }
            if (view) {
                return nullptr;
            }
            view = child;
        }
        return view;
    }

    static QQuickItem *dayNightImage(QQuickItem *view)
    {
        if (!view) {
            return nullptr;
        }
        return qobject_cast<QQuickItem *>(view->property("currentItem").value<QObject *>());
    }

    static QQuickItem *scheduledEndpoint(QQuickItem *component)
    {
        auto *view = dayNightView(component);
        auto *image = dayNightImage(view);
        // Match Plasma 6.8 DayNightView/DayNightImage. Wait until the
        // native stack has committed its item and all blending has ended.
        if (!image || view->property("busy").toBool()
            || view->property("nextItem").value<QObject *>() != image
            || image->property("status").toInt() != 1) {
            return nullptr;
        }
        const auto bottom = image->property("bottomUrl");
        const auto top = image->property("topUrl");
        if (!bottom.isValid() || !top.isValid() || bottom.toUrl().isEmpty() || !top.toUrl().isEmpty()) {
            return nullptr;
        }
        QQuickItem *endpoint = nullptr;
        int mediaCount = 0;
        for (auto *child : image->childItems()) {
            const auto source = child->property("source");
            const auto status = child->property("status");
            if (!source.isValid() || !status.isValid()) {
                continue;
            }
            ++mediaCount;
            if (source.toUrl().isEmpty()) {
                // The former top image must have been cleared by sync().
                if (status.toInt() != 0) {
                    return nullptr;
                }
                continue;
            }
            if (endpoint || source.toUrl() != bottom.toUrl() || status.toInt() != 1
                || !child->window() || child->size().isEmpty() || child->opacity() != 1.0) {
                return nullptr;
            }
            endpoint = child;
        }
        return mediaCount == 2 ? endpoint : nullptr;
    }

    // The scheduled TransientImage receives a package URL, not the chosen
    // file. Follow the Plasma 6.8 package finder using the same KPackage
    // entries, their order, the physical target size and the native score.
    // No directory scan by extension, assumed resolution or guessed variant.
    static QString preferredEntry(const KPackage::Package &package, const QByteArray &folder, const QSize &target)
    {
        QString best;
        double bestScore = std::numeric_limits<double>::max();
        for (const auto &entry : package.entryList(folder)) {
            const auto name = QFileInfo(entry).baseName();
            const auto split = name.indexOf(u'x');
            if (split < 0) {
                continue;
            }
            bool widthOk = false;
            bool heightOk = false;
            const int width = name.left(split).toInt(&widthOk);
            const int height = name.mid(split + 1).toInt(&heightOk);
            if (!widthOk || !heightOk || width <= 0 || height <= 0) {
                continue;
            }
            const double delta = double(width) - target.width();
            const double aspect = double(width) / height - double(target.width()) / target.height();
            const double score = std::abs(aspect) * 25000.0 + (delta < 0 ? -2.0 * delta : delta);
            if (best.isEmpty() || score < bestScore) {
                best = entry;
                bestScore = score;
            }
        }
        return best;
    }

    static QString scheduledFile(const QUrl &source, const QUrl &selected, const QSize &target)
    {
        if (source.scheme() != u"image" || source.host() != u"package" || source.path() != u"/get"
            || !selected.isLocalFile() || (!selected.host().isEmpty() && selected.host() != u"localhost")
            || target.isEmpty()) {
            return {};
        }
        const QUrlQuery query(source);
        const auto dir = query.queryItemValue(u"dir"_s);
        const auto dark = query.queryItemValue(u"darkMode"_s);
        if (!QDir::isAbsolutePath(dir) || QDir::cleanPath(dir) != QDir::cleanPath(selected.toLocalFile())
            || (dark != u"0" && dark != u"1")) {
            return {};
        }
        auto package = KPackage::PackageLoader::self()->loadPackage(u"Wallpaper/Images"_s);
        package.setPath(dir);
        if (!package.isValid()) {
            return {};
        }
        const auto light = preferredEntry(package, "images", target);
        const auto darkEntry = preferredEntry(package, "images_dark", target);
        package.removeDefinition("preferred");
        package.addFileDefinition("preferred", u"images/"_s + light);
        if (!darkEntry.isEmpty()) {
            package.removeDefinition("preferredDark");
            package.addFileDefinition("preferredDark", u"images_dark/"_s + darkEntry);
        }
        if (dark == u"1") {
            // The package can already define preferredDark even when no
            // resolution-named dark entry overrides it.
            const auto path = package.filePath("preferredDark");
            if (!path.isEmpty()) {
                return path;
            }
        }
        return package.filePath("preferred");
    }

    void observe(QObject *object, const char *name, bool rebind = false)
    {
        if (!object) {
            return;
        }
        const auto *meta = object->metaObject();
        const int index = meta->indexOfProperty(name);
        if (index >= 0 && meta->property(index).hasNotifySignal()) {
            const auto signal = rebind ? &WallpaperAccentSource::structureChanged : &WallpaperAccentSource::changed;
            QObject::connect(object, meta->property(index).notifySignal(), this,
                             QMetaMethod::fromSignal(signal), Qt::UniqueConnection);
        }
    }

    bool eventFilter(QObject *watched, QEvent *event) override
    {
        // A scheduled package can select a different image at the same
        // logical size when the output scale changes.
        if (event->type() == QEvent::DevicePixelRatioChange) {
            Q_EMIT changed();
        }
        return QObject::eventFilter(watched, event);
    }

    void refreshConnections()
    {
        for (auto *desktop : m_shell->containments()) {
            if (!isDesktop(desktop)) {
                continue;
            }
            connect(desktop, &Plasma::Containment::wallpaperGraphicsObjectChanged,
                    this, &WallpaperAccentSource::refresh,
                    Qt::ConnectionType(Qt::QueuedConnection | Qt::UniqueConnection));
            connect(desktop, &Plasma::Containment::screenChanged,
                    this, &WallpaperAccentSource::changed, Qt::UniqueConnection);
            auto *root = wallpaperRoot(desktop);
            if (!root) {
                continue;
            }
            connect(root, &QQuickItem::childrenChanged, this, &WallpaperAccentSource::refresh,
                    Qt::ConnectionType(Qt::QueuedConnection | Qt::UniqueConnection));
            connect(root, &QQuickItem::windowChanged, this, &WallpaperAccentSource::refresh,
                    Qt::ConnectionType(Qt::QueuedConnection | Qt::UniqueConnection));
            if (auto *window = root->window(); window &&
                connect(window, &QWindow::screenChanged, this, &WallpaperAccentSource::changed, Qt::UniqueConnection)) {
                window->installEventFilter(this);
                connect(window, &QWindow::visibleChanged, this,
                        &WallpaperAccentSource::changed, Qt::UniqueConnection);
            }
            observe(root, "loading");
            observe(root, "accentColor");
            observe(root, "visible");
            observe(root, "configuration", true);
            observe(root->property("configuration").value<QObject *>(), "PreviewImage");
            auto *stack = imageStack(root);
            observe(stack, "modelImage");
            observe(stack, "currentItem", true);
            observe(stack, "mediaProxy", true);
            observe(stack, "pendingImage");
            observe(stack, "busy");
            if (stack) {
                observe(stack->property("mediaProxy").value<QObject *>(), "modelImage");
                // Re-arm after replacement. TransientImage can enter
                // Loading again during resize, then become Ready later.
                auto *current = qobject_cast<QQuickItem *>(stack->property("currentItem").value<QObject *>());
                observe(current, "status");
                observe(current, "source");
                if (current) {
                    connect(current, &QQuickItem::childrenChanged, this, &WallpaperAccentSource::refresh,
                            Qt::ConnectionType(Qt::QueuedConnection | Qt::UniqueConnection));
                }
                auto *view = dayNightView(current);
                observe(view, "currentItem", true);
                observe(view, "nextItem", true);
                observe(view, "busy");
                observe(view, "status");
                if (auto *image = dayNightImage(view)) {
                    connect(image, &QQuickItem::childrenChanged, this, &WallpaperAccentSource::refresh,
                            Qt::ConnectionType(Qt::QueuedConnection | Qt::UniqueConnection));
                    observe(image, "bottomUrl");
                    observe(image, "topUrl");
                    observe(image, "status");
                    // Do not observe blendFactor: no sampling of the
                    // per-minute crossfade. Wait for topUrl to clear.
                    for (auto *child : image->childItems()) {
                        if (child->property("source").isValid() && child->property("status").isValid()) {
                            observe(child, "source");
                            observe(child, "status");
                            // Package ranking uses the loaded endpoint's
                            // physical size; a resize may keep its URL.
                            observe(child, "width");
                            observe(child, "height");
                        }
                    }
                }
            }
        }
    }

    void refresh()
    {
        refreshConnections();
        Q_EMIT changed();
    }

    static QString json(const QJsonObject &value)
    {
        return QString::fromUtf8(QJsonDocument(value).toJson(QJsonDocument::Compact));
    }

    static QString failure(const QString &message)
    {
        return json(QJsonObject{{u"error"_s, message}});
    }

    Plasma::Corona *const m_shell;
    int m_users = 1;
};

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
    const QRect windowRect(QPoint(0, 0), window->size());
    const QRectF windowBounds(windowRect);
    enabled = enabled && !windowRect.isEmpty() && std::isfinite(radius) && radius >= 0;
    QRegion mask;
    if (enabled) {
        QPainterPath clip;
        clip.addRect(windowBounds);
        for (auto *item : {first, second}) {
            if (!item || item->window() != window || !item->isVisible()) {
                enabled = false;
                break;
            }
            const QRectF bounds = item->mapRectToScene(item->boundingRect());
            if (!bounds.isValid() || !std::isfinite(bounds.left()) || !std::isfinite(bounds.top())
                || !std::isfinite(bounds.right()) || !std::isfinite(bounds.bottom())
                || !bounds.intersects(windowBounds)) {
                enabled = false;
                break;
            }
            // Use window-local logical pixels, including fractional scales.
            // Match Rectangle's radius limit; clip before integer conversion.
            const qreal corner = qMin(radius, qMin(bounds.width(), bounds.height()) / 2);
            QPainterPath path;
            path.addRoundedRect(bounds, corner, corner);
            if (!windowBounds.contains(bounds)) {
                path = path.intersected(clip);
            }
            const QRegion card = QRegion(path.toFillPolygon().toPolygon(), Qt::WindingFill)
                .intersected(windowRect);
            if (card.isEmpty()) {
                enabled = false;
                break;
            }
            mask |= card;
            if (first == second) {
                break;
            }
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
    if (m_wallpaperAccentSource) {
        m_wallpaperAccentSource->release();
    }
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
        } else if ((group.name() == u"WindowsModernAccent" && names.contains(QByteArrayLiteral("Palette")))
                   || (group.name() == u"WindowsModernMaterial" && names.contains(QByteArrayLiteral("Sample")))) {
            refreshWallpaperWatch();
        }
    });

    // KConfig notifications are event driven; do not alter KWin's settings.
    m_blurConfigWatcher = KConfigWatcher::create(
        KSharedConfig::openConfig(QStringLiteral("kwinrc"), KConfig::NoGlobals));
    connect(m_blurConfigWatcher.data(), &KConfigWatcher::configChanged, this,
            [this](const KConfigGroup &group, const QByteArrayList &names) {
        if (group.name() == u"Plugins" && names.contains(QByteArrayLiteral("blurEnabled"))) {
            Q_EMIT popupBlurPreferencesChanged();
        }
    });

    // Use the existing tray and debounced sync rather than a polling process.
    // Wallpaper changes through the shell API and ordinary desktop config
    // saves both reach this path, as do activity and screen changes.
    if (auto *shell = corona()) {
        if (!m_wallpaperAccentSource) {
            m_wallpaperAccentSource = WallpaperAccentSource::forShell(shell);
            if (m_wallpaperAccentSource) {
                connect(m_wallpaperAccentSource.data(), &WallpaperAccentSource::changed,
                        this, &SystemTray::scheduleWallpaperAccentSync);
            } else {
                qWarning("Windows Modern: could not register live wallpaper source");
            }
        }
        connect(shell, &Plasma::Corona::configSynced, this, &SystemTray::scheduleWallpaperAccentSync);
        connect(shell, &Plasma::Corona::screenAdded, this, &SystemTray::scheduleWallpaperAccentSync);
        connect(shell, &Plasma::Corona::screenRemoved, this, &SystemTray::scheduleWallpaperAccentSync);
    }
    auto bus = QDBusConnection::sessionBus();
    bus.connect(u"org.kde.plasmashell"_s, u"/PlasmaShell"_s, u"org.kde.PlasmaShell"_s,
                u"wallpaperChanged"_s, this, SLOT(scheduleWallpaperAccentSync()));
    bus.connect(u"org.kde.ActivityManager"_s, u"/ActivityManager/Activities"_s, u"org.kde.ActivityManager.Activities"_s,
                u"CurrentActivityChanged"_s, this, SLOT(scheduleWallpaperAccentSync()));
    auto rearm = [this] { refreshWallpaperWatch(); };
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
        // Ignore unrelated config writes unless a selected wallpaper
        // also lives here or the watched file inventory changed.
        if (path != QStandardPaths::writableLocation(QStandardPaths::ConfigLocation)
            || before != after || m_configWallpaperParent) {
            scheduleWallpaperAccentSync();
        }
    });
    refreshWallpaperWatch();
}

void SystemTray::scheduleWallpaperAccentSync()
{
    // Material follows the wallpaper even when the accent is manual or
    // native. The existing shell helper checks the transparency preference.
    if (m_automaticWallpaperAccent || m_wallpaperAccentSource) {
        Q_EMIT accentPreferencesChanged();
    }
}

void SystemTray::refreshWallpaperWatch()
{
    auto globals = KSharedConfig::openConfig(QStringLiteral("kdeglobals"), KConfig::NoGlobals);
    const auto accent = QJsonDocument::fromJson(
        globals->group(QStringLiteral("WindowsModernAccent")).readEntry("Palette", QString()).toUtf8()).object();
    const auto material = QJsonDocument::fromJson(
        globals->group(QStringLiteral("WindowsModernMaterial")).readEntry("Sample", QString()).toUtf8()).object();
    m_automaticWallpaperAccent = accent.value(u"source"_s).toString() == u"automatic";
    m_configWallpaperParent = false;
    QSet<QString> wanted;
    if (m_automaticWallpaperAccent || m_wallpaperAccentSource) {
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
        // Import/removal of a local, verified ICC replay also changes the
        // decoder cache identity. Observe its parent for atomic publication.
        const auto dataDir = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
        if (!dataDir.isEmpty()) {
            const auto parent = dataDir + u"/windows-modern"_s;
            const auto reference = parent + u"/icc-replay-v2.bin"_s;
            if (QFileInfo(reference).isFile()) {
                wanted.insert(reference);
            }
            if (QFileInfo(parent).isDir()) {
                wanted.insert(parent);
            } else if (QFileInfo(dataDir).isDir()) {
                // The first import may create the private data directory.
                wanted.insert(dataDir);
            }
        }
        QJsonArray images;
        const auto accentImages = accent.value(u"wallpapers"_s).toArray();
        if (m_automaticWallpaperAccent && accentImages.size() <= 16) {
            images = accentImages;
        }
        const auto materialImages = material.value(u"wallpapers"_s).toArray();
        if (m_wallpaperAccentSource && materialImages.size() == 1) {
            images.append(materialImages.at(0));
        }
        for (const auto &image : images) {
            const auto entry = image.toObject();
            // The selected alias and its resolved file may live in
            // different directories. Watch both when supplied.
            for (const auto &key : {u"path"_s, u"source_path"_s}) {
                const QFileInfo file(entry.value(key).toString());
                if (!file.isAbsolute()) {
                    continue;
                }
                if (file.isFile()) {
                    wanted.insert(file.absoluteFilePath());
                }
                // The parent detects replacement or temporary deletion.
                const auto parent = file.absolutePath();
                if (QFileInfo(parent).isDir()) {
                    wanted.insert(parent);
                    m_configWallpaperParent |= parent == configDir;
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
