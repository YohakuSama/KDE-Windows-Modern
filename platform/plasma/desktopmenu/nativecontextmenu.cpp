// SPDX-License-Identifier: GPL-3.0-or-later
#include "menulayout.h"
#include "panelpopuphost.h"
#include "shellappearancemonitor.h"
#include "shellshortcutrouter.h"
#include <KAuthorized>
#include <KConfig>
#include <KConfigGroup>
#include <KPluginFactory>
#include <KService>
#include <KTerminalLauncherJob>
#include <Plasma/Containment>
#include <Plasma/ContainmentActions>
#include <Plasma/Corona>
#include <Plasma/PluginLoader>
#include <QApplication>
#include <QDebug>
#include <QDir>
#include <QEvent>
#include <QFileInfo>
#include <QMetaObject>
#include <QPalette>
#include <QStandardPaths>
#include <QUrl>
#include <memory>

class NativeDesktopMenu final : public Plasma::ContainmentActions
{
    Q_OBJECT
public:
    NativeDesktopMenu(QObject *parent, const QVariantList &args)
        : Plasma::ContainmentActions(parent, args)
        , m_openTerminal(this)
    {
        connect(&m_openTerminal, &QAction::triggered, this, [this] { launchDesktopTerminal(); });
        if (qApp) qApp->installEventFilter(this);
    }
    ~NativeDesktopMenu() override
    {
        if (qApp) qApp->removeEventFilter(this);
    }
    void restore(const KConfigGroup &config) override
    {
        if (auto *desktop = containment(); desktop && desktop->corona()) {
            auto *shell = desktop->corona();
            PanelPopupHost::installForShell(shell);
            ShellAppearanceMonitor::startForShell(shell);
            ShellShortcutRouter::ensureForShell(shell);
        }
        if (!m_native)
            m_native.reset(Plasma::PluginLoader::self()->loadContainmentActions(
                containment(), QStringLiteral("org.kde.contextmenu")));
        if (!m_native) {
            qCritical() << "Windows Modern: native KDE context menu plugin unavailable";
            return;
        }
        m_native->setContainment(containment());
        m_native->restore(config);
    }
    void save(KConfigGroup &config) override
    {
        if (m_native) m_native->save(config);
    }
    QWidget *createConfigurationInterface(QWidget *parent) override
    {
        return m_native ? m_native->createConfigurationInterface(parent) : nullptr;
    }
    void configurationAccepted() override
    {
        if (m_native) m_native->configurationAccepted();
    }
    QList<QAction *> contextualActions() override
    {
        auto *desktop = containment();
        if (!desktop) return {};
        const auto stock = m_native ? m_native->contextualActions() : desktop->contextualActions();
        if (desktop->containmentType() != Plasma::Containment::Desktop) return {};
        // Reuse FolderModel's real refresh action, even though the stock
        // background menu does not expose it. Never add an unconnected row.
        QAction *refresh = nullptr;
        QAction *undo = DesktopMenuLayout::named(stock, QStringLiteral("undo"));
        // The New action may be owned by KNewFileMenu or KActionCollection,
        // not directly by FolderModel. Search its real QObject ownership chain.
        for (const auto &name : {QStringLiteral("newMenu"), QStringLiteral("paste"), QStringLiteral("undo")}) {
            auto *action = DesktopMenuLayout::named(stock, name);
            for (auto *model = action ? action->parent() : nullptr; model; model = model->parent()) {
                if (model->metaObject()->indexOfMethod("action(QString)") < 0) continue;
                if (!refresh)
                    QMetaObject::invokeMethod(model, "action", Qt::DirectConnection,
                        Q_RETURN_ARG(QAction *, refresh), Q_ARG(QString, QStringLiteral("refresh")));
                if (!undo)
                    QMetaObject::invokeMethod(model, "action", Qt::DirectConnection,
                        Q_RETURN_ARG(QAction *, undo), Q_ARG(QString, QStringLiteral("undo")));
                if (refresh && undo) break;
            }
            if (refresh && undo) break;
        }
        return m_layout.build(stock, refresh, desktop->internalAction(QStringLiteral("configure")),
                              undo, terminalAvailable() ? &m_openTerminal : nullptr);
    }
protected:
    bool eventFilter(QObject *object, QEvent *event) override
    {
        auto *menu = qobject_cast<QMenu *>(object);
        if (menu && qApp) {
            if (event->type() == QEvent::Hide) {
                DesktopMenuLayout::restoreAppearance(menu);
            } else if (event->type() == QEvent::Show && m_layout.ownsMenu(menu)) {
                // Desktop surfaces follow the Plasma theme, even when Qt apps
                // still use their previous Kvantum palette after a live switch.
                const KConfig plasmaConfig(QStringLiteral("plasmarc"), KConfig::CascadeConfig);
                const auto name = KConfigGroup(&plasmaConfig, QStringLiteral("Theme")).readEntry("name", QString());
                const KConfig globalConfig(QStringLiteral("kdeglobals"), KConfig::CascadeConfig);
                const auto scheme = KConfigGroup(&globalConfig, QStringLiteral("General")).readEntry("ColorScheme", QString());
                const bool dark = DesktopMenuLayout::darkMode(name, scheme,
                    qApp->palette().color(QPalette::Window).lightness() < 128);
                DesktopMenuLayout::applyAppearance(menu, dark);
            }
        }
        return Plasma::ContainmentActions::eventFilter(object, event);
    }
private:
    bool terminalAvailable() const
    {
        if (!KAuthorized::authorizeAction(QStringLiteral("shell_access"))) return false;
        const KConfig globalConfig(QStringLiteral("kdeglobals"), KConfig::CascadeConfig);
        const KConfigGroup general(&globalConfig, QStringLiteral("General"));
        const QString serviceId = general.readEntry("TerminalService", QString()).trimmed();
        if (!serviceId.isEmpty() && KService::serviceByStorageId(serviceId)) return true;
        const QString configured = general.readEntry("TerminalApplication", QStringLiteral("konsole")).trimmed();
        if (!configured.isEmpty()) {
            const QString binary = QFileInfo(configured).isExecutable()
                ? configured
                : configured.section(QLatin1Char(' '), 0, 0);
            if (!binary.isEmpty()
                && (QFileInfo(binary).isExecutable() || !QStandardPaths::findExecutable(binary).isEmpty())) {
                return true;
            }
        }
        return !QStandardPaths::findExecutable(QStringLiteral("konsole")).isEmpty()
            || !QStandardPaths::findExecutable(QStringLiteral("xterm")).isEmpty();
    }
    QString desktopWorkingDirectory() const
    {
        if (auto *desktop = containment()) {
            const QString rawUrl = desktop->config().group(QStringLiteral("General"))
                                       .readEntry("url", QStringLiteral("desktop:/")).trimmed();
            if (!rawUrl.isEmpty() && rawUrl != QLatin1String("desktop:/")) {
                const QUrl url = QUrl::fromUserInput(rawUrl);
                if (url.isLocalFile()) {
                    const QString local = url.toLocalFile();
                    if (QFileInfo(local).isDir()) return local;
                }
            }
        }
        const QString desktopDir = QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);
        if (!desktopDir.isEmpty() && QFileInfo(desktopDir).isDir()) return desktopDir;
        return QDir::homePath();
    }
    void launchDesktopTerminal() const
    {
        if (!terminalAvailable()) return;
        auto *job = new KTerminalLauncherJob(QString());
        job->setWorkingDirectory(desktopWorkingDirectory());
        job->start();
    }

    std::unique_ptr<Plasma::ContainmentActions> m_native;
    DesktopMenuLayout m_layout;
    QAction m_openTerminal;
};

K_PLUGIN_CLASS_WITH_JSON(NativeDesktopMenu, "metadata.json")
#include "nativecontextmenu.moc"
