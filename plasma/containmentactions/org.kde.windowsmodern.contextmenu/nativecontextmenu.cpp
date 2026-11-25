// SPDX-License-Identifier: GPL-3.0-or-later
#include "menulayout.h"
#include <KConfigGroup>
#include <KPluginFactory>
#include <Plasma/Containment>
#include <Plasma/ContainmentActions>
#include <Plasma/PluginLoader>
#include <QDebug>
#include <QMetaObject>
#include <memory>

class NativeDesktopMenu final : public Plasma::ContainmentActions
{
    Q_OBJECT
public:
    NativeDesktopMenu(QObject *parent, const QVariantList &args)
        : Plasma::ContainmentActions(parent, args) {}
    void restore(const KConfigGroup &config) override
    {
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
        if (desktop->containmentType() != Plasma::Containment::Desktop || !m_native) return stock;
        // Reuse FolderModel's real refresh action, even though the stock
        // background menu does not expose it. Never add an unconnected row.
        QAction *refresh = nullptr;
        QAction *undo = DesktopMenuLayout::named(stock, QStringLiteral("undo"));
        if (auto *newFile = DesktopMenuLayout::named(stock, QStringLiteral("newMenu"))) {
            if (auto *model = newFile->parent()) {
                QMetaObject::invokeMethod(model, "action", Qt::DirectConnection,
                    Q_RETURN_ARG(QAction *, refresh), Q_ARG(QString, QStringLiteral("refresh")));
                if (!undo)
                    QMetaObject::invokeMethod(model, "action", Qt::DirectConnection,
                        Q_RETURN_ARG(QAction *, undo), Q_ARG(QString, QStringLiteral("undo")));
            }
        }
        return m_layout.build(stock, refresh, desktop->internalAction(QStringLiteral("configure")), undo);
    }
private:
    std::unique_ptr<Plasma::ContainmentActions> m_native;
    DesktopMenuLayout m_layout;
};

K_PLUGIN_CLASS_WITH_JSON(NativeDesktopMenu, "metadata.json")
#include "nativecontextmenu.moc"
