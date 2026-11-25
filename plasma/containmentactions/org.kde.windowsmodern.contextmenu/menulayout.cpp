// SPDX-License-Identifier: GPL-3.0-or-later
#include "menulayout.h"
#include <KLocalizedString>
#include <QIcon>
#include <QSet>

namespace {
constexpr auto domain = "plasma_containmentactions_org.kde.windowsmodern.contextmenu";
bool usable(const QAction *a) { return a && a->isVisible() && !a->isSeparator(); }
bool namedIcon(const QAction *a, const QString &name)
{
    return a && (a->icon().name() == name || a->icon().name() == name + QStringLiteral("-symbolic"));
}
}
DesktopMenuLayout::DesktopMenuLayout()
{
    m_view.setTitle(i18nd(domain, "View"));
    m_view.setIcon(QIcon::fromTheme(QStringLiteral("view-list-icons")));
    m_more.setTitle(i18nd(domain, "Show more options"));
    m_more.setIcon(QIcon::fromTheme(QStringLiteral("overflow-menu")));
    m_more.setSeparatorsCollapsible(true);
    for (auto *a : {&m_separator1, &m_separator2, &m_separator3}) a->setSeparator(true);
}
QAction *DesktopMenuLayout::named(const QList<QAction *> &actions, const QString &name)
{
    for (auto *a : actions) if (usable(a) && a->objectName() == name) return a;
    return nullptr;
}
QAction *DesktopMenuLayout::sortAction(QAction *view)
{
    if (!usable(view) || !view->menu()) return nullptr;
    for (auto *a : view->menu()->actions()) {
        if (!usable(a) || !a->menu()) continue;
        const auto children = a->menu()->actions();
        // KDE ViewPropertiesMenu starts its native sorting submenu with the
        // checkable Unsorted role (data -1). No locale-dependent text matching.
        if (namedIcon(a, QStringLiteral("view-sort"))
            || (!children.isEmpty() && children.first()->isCheckable()
                && children.first()->data().isValid() && children.first()->data().toInt() == -1))
            return a;
    }
    return nullptr;
}
QList<QAction *> DesktopMenuLayout::build(const QList<QAction *> &nativeActions,
                                         QAction *refresh, QAction *personalize)
{
    m_view.clear();
    m_more.clear();
    QSet<QAction *> used;
    QList<QAction *> result;
    auto add = [&](QAction *a) {
        if (usable(a) && !used.contains(a)) {
            result.append(a);
            used.insert(a);
        }
    };
    auto separator = [&](QAction *a) {
        if (!result.isEmpty() && !result.last()->isSeparator()) result.append(a);
    };
    QAction *view = nullptr;
    QAction *sort = nullptr;
    for (auto *a : nativeActions) {
        if ((sort = sortAction(a))) { view = a; break; }
    }
    if (view) {
        for (auto *a : view->menu()->actions())
            if (usable(a) && a != sort) m_view.addAction(a);
        if (!m_view.actions().isEmpty()) add(m_view.menuAction());
        add(sort);
        used.insert(view);
    }
    add(refresh);
    separator(&m_separator1);
    add(named(nativeActions, QStringLiteral("newMenu")));
    add(named(nativeActions, QStringLiteral("paste")));
    separator(&m_separator2);
    for (auto *a : nativeActions)
        if (usable(a) && namedIcon(a, QStringLiteral("preferences-desktop-display"))) {
            add(a);
            break;
        }
    if (nativeActions.contains(personalize)) add(personalize);
    bool pendingSeparator = false;
    for (auto *a : nativeActions) {
        if (!a || !a->isVisible() || used.contains(a)) continue;
        if (a->isSeparator()) {
            pendingSeparator = !m_more.actions().isEmpty();
            continue;
        }
        if (pendingSeparator) m_more.addSeparator();
        pendingSeparator = false;
        m_more.addAction(a);
        used.insert(a);
    }
    if (!m_more.actions().isEmpty()) {
        separator(&m_separator3);
        add(m_more.menuAction());
    }
    while (!result.isEmpty() && result.last()->isSeparator()) result.removeLast();
    return result;
}
