/*
    SPDX-FileCopyrightText: 2015 Marco Martin <mart@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "shellappearancemonitor.h"

#include <cmath>
#include <limits>
#include <optional>
#include <utility>

#include <QDBusConnection>
#include <QDebug>
#include <QDir>
#include <QEvent>
#include <QFileInfo>
#include <QImageReader>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QHash>
#include <QMetaMethod>
#include <QMetaObject>
#include <QMetaProperty>
#include <QQuickItem>
#include <QQuickWindow>
#include <QScreen>
#include <QSet>
#include <QStandardPaths>
#include <QUrl>
#include <QUrlQuery>
#include <QVariant>

#include <KConfigGroup>
#include <KPackage/Package>
#include <KPackage/PackageLoader>
#include <KSharedConfig>

#include <Plasma/Containment>
#include <Plasma/Corona>

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
    explicit WallpaperAccentSource(Plasma::Corona *shell, QObject *parent)
        : QObject(parent), m_shell(shell)
    {
        setObjectName(u"windowsModernWallpaperAccentSource"_s);
        connect(shell, &Plasma::Corona::containmentAdded, this, &WallpaperAccentSource::refresh, Qt::QueuedConnection);
        connect(shell, &Plasma::Corona::configSynced, this, &WallpaperAccentSource::refresh);
        // Reconnect to newly created nested QML objects before notifying
        // the monitor, even when automatic mode has no snapshot in flight.
        connect(this, &WallpaperAccentSource::structureChanged,
                this, &WallpaperAccentSource::refresh, Qt::QueuedConnection);
        refreshConnections();
    }

    static WallpaperAccentSource *create(Plasma::Corona *shell, QObject *parent)
    {
        auto *source = new WallpaperAccentSource(shell, parent);
        if (!QDBusConnection::sessionBus().registerObject(
                u"/WindowsModernWallpaper"_s, source, QDBusConnection::ExportScriptableSlots)) {
            delete source;
            return nullptr;
        }
        return source;
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
};

ShellAppearanceMonitor *ShellAppearanceMonitor::forShell(Plasma::Corona *shell)
{
    if (!shell)
        return nullptr;
    if (auto *existing = shell->findChild<ShellAppearanceMonitor *>(
            u"windowsModernShellAppearance"_s, Qt::FindDirectChildrenOnly)) {
        return existing;
    }
    return new ShellAppearanceMonitor(shell);
}

ShellAppearanceMonitor::ShellAppearanceMonitor(Plasma::Corona *shell)
    : QObject(shell)
{
    setObjectName(u"windowsModernShellAppearance"_s);
    // The shell owns the monitor for its session. Removing a panel must
    // not interrupt wallpaper observations or an accepted transaction.

    m_timer.setSingleShot(true);
    m_timer.setInterval(350);
    connect(&m_timer, &QTimer::timeout, this, &ShellAppearanceMonitor::launchSync);
    // The helper retains its existing lock, stale-snapshot checks and
    // transaction implementation. Do not run a second helper while busy.
    m_process.setStandardOutputFile(QProcess::nullDevice());
    connect(&m_process, &QProcess::finished, this,
            [this](int exitCode, QProcess::ExitStatus status) {
        finishSync(exitCode, status == QProcess::NormalExit);
    });
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            qWarning() << "Windows Modern appearance helper could not start:" << m_process.errorString();
            finishSync(-1, false);
        }
    });

    auto config = KSharedConfig::openConfig(QStringLiteral("kdeglobals"), KConfig::NoGlobals);
    m_configWatcher = KConfigWatcher::create(config);
    connect(m_configWatcher.data(), &KConfigWatcher::configChanged, this,
            [this](const KConfigGroup &group, const QByteArrayList &names) {
        if (group.name() == u"General"
            && (names.contains(QByteArrayLiteral("AccentColor"))
                || names.contains(QByteArrayLiteral("accentColorFromWallpaper"))
                || names.contains(QByteArrayLiteral("ColorScheme")))) {
            requestSync();
        } else if ((group.name() == u"WindowsModernAccent" && names.contains(QByteArrayLiteral("Palette")))
                   || (group.name() == u"WindowsModernMaterial" && names.contains(QByteArrayLiteral("Sample")))) {
            refreshWallpaperWatch();
        }
    });

    m_wallpaperAccentSource = WallpaperAccentSource::create(shell, this);
    if (m_wallpaperAccentSource) {
        connect(m_wallpaperAccentSource.data(), &WallpaperAccentSource::changed,
                this, &ShellAppearanceMonitor::scheduleWallpaperAccentSync);
    } else {
        qWarning("Windows Modern: could not register live wallpaper source");
    }
    connect(shell, &Plasma::Corona::configSynced, this, &ShellAppearanceMonitor::scheduleWallpaperAccentSync);
    connect(shell, &Plasma::Corona::screenAdded, this, &ShellAppearanceMonitor::scheduleWallpaperAccentSync);
    connect(shell, &Plasma::Corona::screenRemoved, this, &ShellAppearanceMonitor::scheduleWallpaperAccentSync);
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

ShellAppearanceMonitor::~ShellAppearanceMonitor()
{
    m_timer.stop();
    // Avoid process callbacks during member destruction at shell shutdown.
    disconnect(&m_process, nullptr, this, nullptr);
    if (m_wallpaperAccentSource)
        QDBusConnection::sessionBus().unregisterObject(u"/WindowsModernWallpaper"_s);
}

void ShellAppearanceMonitor::start()
{
    m_started = true;
    requestSync();
}

void ShellAppearanceMonitor::requestSync()
{
    if (!m_started)
        return;
    m_dirty = true;
    m_retries = 0;
    m_timer.start();
}

void ShellAppearanceMonitor::launchSync()
{
    if (!m_started || !m_dirty || m_running)
        return;
    m_dirty = false;
    const auto script = QStandardPaths::locate(QStandardPaths::GenericDataLocation,
        u"plasma/look-and-feel/org.kde.windowsmodern.dark/contents/scripts/switch-mode.sh"_s);
    if (script.isEmpty())
        return;
    m_running = true;
    m_process.start(u"bash"_s, {script, u"--sync-accent"_s});
}

void ShellAppearanceMonitor::finishSync(int exitCode, bool normalExit)
{
    if (!m_running)
        return;
    m_running = false;
    const auto error = QString::fromUtf8(m_process.readAllStandardError()).trimmed();
    if (normalExit && exitCode == 75 && !m_dirty && m_retries < 3) {
        ++m_retries;
        m_dirty = true;
    } else if (!normalExit || exitCode != 0) {
        qWarning() << "Windows Modern accent synchronization failed:" << exitCode << error;
    } else if (!error.isEmpty()) {
        qWarning() << "Windows Modern accent synchronization:" << error;
    }
    if (m_dirty)
        m_timer.start();
}

void ShellAppearanceMonitor::scheduleWallpaperAccentSync()
{
    // Material follows the wallpaper even when the accent is manual or
    // native. The existing shell helper checks the transparency preference.
    if (m_automaticWallpaperAccent || m_wallpaperAccentSource) {
        requestSync();
    }
}

void ShellAppearanceMonitor::refreshWallpaperWatch()
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

#include "shellappearancemonitor.moc"
