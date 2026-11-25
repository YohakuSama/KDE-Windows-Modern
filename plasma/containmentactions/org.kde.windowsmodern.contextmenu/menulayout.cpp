// SPDX-License-Identifier: GPL-3.0-or-later
#include "menulayout.h"
#include <KLocalizedString>
#include <QIcon>
#include <QSet>
#include <QVariant>

namespace {
constexpr auto domain = "plasma_containmentactions_org.kde.windowsmodern.contextmenu";
bool usable(const QAction *a) { return a && a->isVisible() && !a->isSeparator(); }
void useSymbolic(QAction *a, const QString &name)
{
    if (!a) return;
    const auto icon = QIcon::fromTheme(name);
    if (!icon.isNull()) a->setIcon(icon);
}
bool namedIcon(const QAction *a, const QString &name)
{
    return a && (a->icon().name() == name || a->icon().name() == name + QStringLiteral("-symbolic"));
}
}
DesktopMenuLayout::DesktopMenuLayout()
{
    m_view.setTitle(i18nd(domain, "View"));
    m_view.setIcon(QIcon::fromTheme(QStringLiteral("view-grid-symbolic"),
        QIcon::fromTheme(QStringLiteral("view-list-icons"))));
    m_more.setTitle(i18nd(domain, "Show more options"));
    m_more.setIcon(QIcon::fromTheme(QStringLiteral("overflow-menu-symbolic"),
        QIcon::fromTheme(QStringLiteral("overflow-menu"))));
    m_more.setSeparatorsCollapsible(true);
    for (auto *a : {&m_separator1, &m_pasteSeparator, &m_separator2, &m_separator3}) a->setSeparator(true);
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
                                         QAction *refresh, QAction *personalize, QAction *undo)
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
    useSymbolic(refresh, QStringLiteral("view-refresh-symbolic"));
    add(refresh);
    separator(&m_separator1);
    auto *paste = named(nativeActions, QStringLiteral("paste"));
    useSymbolic(paste, QStringLiteral("edit-paste-symbolic"));
    add(paste);
    separator(&m_pasteSeparator);
    // Windows exposes the real undo operation only when it is available.
    // Keep the native action and its live operation-specific text.
    if (!undo) undo = named(nativeActions, QStringLiteral("undo"));
    if (usable(undo) && undo->isEnabled()) {
        useSymbolic(undo, QStringLiteral("edit-undo-symbolic"));
        add(undo);
    }
    if (undo) used.insert(undo);
    auto *newAction = named(nativeActions, QStringLiteral("newMenu"));
    useSymbolic(newAction, QStringLiteral("document-new-symbolic"));
    add(newAction);
    separator(&m_separator2);
    for (auto *a : nativeActions)
        if (usable(a) && namedIcon(a, QStringLiteral("preferences-desktop-display"))) {
            useSymbolic(a, QStringLiteral("preferences-desktop-display-symbolic"));
            add(a);
            break;
        }
    if (nativeActions.contains(personalize)) {
        useSymbolic(personalize, QStringLiteral("preferences-desktop-wallpaper-symbolic"));
        add(personalize);
    }
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

bool DesktopMenuLayout::ownsMenu(const QMenu *menu) const
{
    if (!menu) return false;
    QList<const QMenu *> pending{menu};
    QSet<const QMenu *> visited;
    while (!pending.isEmpty()) {
        const auto *current = pending.takeLast();
        if (visited.contains(current)) continue;
        visited.insert(current);
        const auto actions = current->actions();
        if (current == &m_view || current == &m_more
            || actions.contains(m_view.menuAction()) || actions.contains(m_more.menuAction())) return true;
        for (auto *owner : current->menuAction()->associatedObjects())
            if (const auto *parentMenu = qobject_cast<QMenu *>(owner)) pending.append(parentMenu);
    }
    return false;
}

void DesktopMenuLayout::applyAppearance(QMenu *menu, bool dark)
{
    if (!menu) return;
    // Only the desktop background menu and its attached submenus get
    // this surface. Never change the application's global style.
    const QString sheet = QStringLiteral(
        "QMenu { background-color: %1; color: %2; border: 1px solid %3;"
        "border-radius: 8px; padding: 4px; min-width: 204px; }"
        "QMenu::item { min-height: 26px; padding: 4px 24px 4px 30px;"
        "margin: 0px 2px; border-radius: 4px; background: transparent; }"
        "QMenu::item:selected:enabled { background-color: %4; }"
        "QMenu::item:disabled { color: %5; }"
        "QMenu::separator { height: 1px; background: %6; margin: 3px 4px; }"
        "QMenu::icon { left: 8px; width: 16px; height: 16px; }"
    ).arg(dark ? QStringLiteral("#202020") : QStringLiteral("#F9F9F9"),
          dark ? QStringLiteral("#FFFFFF") : QStringLiteral("#1B1B1B"),
          dark ? QStringLiteral("#383838") : QStringLiteral("#E1E1E1"),
          dark ? QStringLiteral("#303030") : QStringLiteral("#EEEEEE"),
          dark ? QStringLiteral("#777777") : QStringLiteral("#A0A0A0"),
          dark ? QStringLiteral("#343434") : QStringLiteral("#E5E5E5"));
    if (menu->styleSheet() == sheet) return;
    if (!menu->property("wmDesktopMenuStyled").toBool()) {
        menu->setProperty("wmDesktopMenuOriginalStyle", menu->styleSheet());
        menu->setProperty("wmDesktopMenuStyled", true);
    }
    menu->setStyleSheet(sheet);
}

void DesktopMenuLayout::restoreAppearance(QMenu *menu)
{
    if (!menu || !menu->property("wmDesktopMenuStyled").toBool()) return;
    const auto previous = menu->property("wmDesktopMenuOriginalStyle").toString();
    menu->setProperty("wmDesktopMenuStyled", QVariant());
    menu->setProperty("wmDesktopMenuOriginalStyle", QVariant());
    menu->setStyleSheet(previous);
}
