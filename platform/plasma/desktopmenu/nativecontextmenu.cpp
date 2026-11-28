// SPDX-License-Identifier: GPL-3.0-or-later
#include "menulayout.h"
#include "panelpopuphost.h"
#include "shellappearancemonitor.h"
#include "shellshortcutrouter.h"
#include <KConfigGroup>
#include <KConfig>
#include <KPluginFactory>
#include <Plasma/Containment>
#include <Plasma/ContainmentActions>
#include <Plasma/Corona>
#include <Plasma/PluginLoader>
#include <QApplication>
#include <QDebug>
#include <QEvent>
#include <QPalette>
#include <QMetaObject>
#include <memory>

class NativeDesktopMenu final : public Plasma::ContainmentActions
{
    Q_OBJECT
public:
    NativeDesktopMenu(QObject *parent, const QVariantList &args)
        : Plasma::ContainmentActions(parent, args)
    {
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
        return m_layout.build(stock, refresh, desktop->internalAction(QStringLiteral("configure")), undo);
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
    std::unique_ptr<Plasma::ContainmentActions> m_native;
    DesktopMenuLayout m_layout;
};

K_PLUGIN_CLASS_WITH_JSON(NativeDesktopMenu, "metadata.json")
#include "nativecontextmenu.moc"
