// SPDX-License-Identifier: GPL-3.0-or-later
#include "menulayout.h"
#include <KLocalizedString>
#include <QIcon>
#include <QImageReader>
#include <QPainter>
#include <QPalette>
#include <QStandardPaths>
#include <QHash>
#include <QFileInfo>
#include <QDateTime>
#include <QPixmap>
#include <QSet>
#include <QVariant>

namespace {
constexpr auto domain = "plasma_containmentactions_org.kde.windowsmodern.contextmenu";
bool usable(const QAction *a) { return a && a->isVisible() && !a->isSeparator(); }
// Store semantic roles without replacing the live native action. Render
// only from the verified importer output, never from Breeze or an unrelated
// theme icon. Restore the original QAction icon when the menu is hidden.
void useSymbolic(QAction *a, const QString &role)
{
    if (a) a->setProperty("wmMenuNativeRole", role);
}
bool namedIcon(const QAction *a, const QString &name)
{
    if (!a) return false;
    const auto original = a->property("wmMenuOriginalIcon");
    const auto icon = original.isValid() ? original.value<QIcon>() : a->icon();
    return icon.name() == name || icon.name() == name + QStringLiteral("-symbolic");
}
QIcon nativeMenuIcon(const QString &role, bool dark)
{
    if (role.isEmpty()) return {};
    const auto base = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
        + QStringLiteral("/windows-modern/native-assets/icons/");
    const auto path = base + role + QStringLiteral(".svg");
    const QFileInfo info(path);
    if (!info.isFile() || info.isSymLink()) return {};
    const auto key = path + (dark ? QStringLiteral(":dark") : QStringLiteral(":light"))
        + QString::number(info.lastModified().toMSecsSinceEpoch());
    static QHash<QString, QIcon> cache;
    if (cache.contains(key)) return cache.value(key);
    QIcon result;
    for (const qreal dpr : {1.0, 1.25, 1.5, 1.75, 2.0}) {
        const int size = qRound(16 * dpr);
        QImageReader reader(path);
        reader.setScaledSize(QSize(size, size));
        auto image = reader.read().convertToFormat(QImage::Format_ARGB32_Premultiplied);
        if (image.isNull()) continue;
        QPainter painter(&image);
        painter.setCompositionMode(QPainter::CompositionMode_SourceIn);
        painter.fillRect(image.rect(), QColor(dark ? "#FFFFFF" : "#1B1B1B"));
        painter.end();
        auto pixmap = QPixmap::fromImage(image);
        pixmap.setDevicePixelRatio(dpr);
        result.addPixmap(pixmap, QIcon::Normal);
    }
    if (cache.size() >= 128) cache.clear();
    if (!result.isNull()) cache.insert(key, result);
    return result;
}
void setMenuActionIcon(QAction *action, bool dark)
{
    if (!action || action->isSeparator()) return;
    if (!action->property("wmMenuOriginalIcon").isValid())
        action->setProperty("wmMenuOriginalIcon", QVariant::fromValue(action->icon()));
    action->setIcon(nativeMenuIcon(action->property("wmMenuNativeRole").toString(), dark));
}
}
DesktopMenuLayout::DesktopMenuLayout()
{
    m_view.setTitle(i18nd(domain, "View"));
    useSymbolic(m_view.menuAction(), QStringLiteral("actions/view-grid-symbolic"));
    m_more.setTitle(i18nd(domain, "Show more options"));
    useSymbolic(m_more.menuAction(), QStringLiteral("actions/overflow-menu-symbolic"));
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
        sort->setText(i18nd(domain, "Sort by"));
        useSymbolic(sort, QStringLiteral("actions/view-sort-symbolic"));
        add(sort);
        used.insert(view);
    }
    if (refresh) refresh->setText(i18nd(domain, "Refresh"));
    useSymbolic(refresh, QStringLiteral("actions/view-refresh-symbolic"));
    add(refresh);
    separator(&m_separator1);
    auto *paste = named(nativeActions, QStringLiteral("paste"));
    if (paste) paste->setText(i18nd(domain, "Paste"));
    useSymbolic(paste, QStringLiteral("actions/edit-paste-symbolic"));
    add(paste);
    separator(&m_pasteSeparator);
    // Windows exposes the real undo operation only when it is available.
    // Keep the native action and its live operation-specific text.
    if (!undo) undo = named(nativeActions, QStringLiteral("undo"));
    if (usable(undo) && undo->isEnabled()) {
        useSymbolic(undo, QStringLiteral("actions/edit-undo-symbolic"));
        add(undo);
    }
    if (undo) used.insert(undo);
    auto *newAction = named(nativeActions, QStringLiteral("newMenu"));
    if (newAction) newAction->setText(i18nd(domain, "New"));
    useSymbolic(newAction, QStringLiteral("actions/document-new-symbolic"));
    add(newAction);
    separator(&m_separator2);
    for (auto *a : nativeActions)
        if (usable(a) && namedIcon(a, QStringLiteral("preferences-desktop-display"))) {
            a->setText(i18nd(domain, "Display settings"));
            useSymbolic(a, QStringLiteral("apps/preferences-desktop-display-symbolic"));
            add(a);
            break;
        }
    if (nativeActions.contains(personalize)) {
        personalize->setText(i18nd(domain, "Personalize"));
        useSymbolic(personalize, QStringLiteral("apps/preferences-desktop-wallpaper-symbolic"));
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
            || actions.contains(m_view.menuAction()) || actions.contains(m_more.menuAction())
            || actions.contains(const_cast<QAction *>(&m_separator1))
            || actions.contains(const_cast<QAction *>(&m_pasteSeparator))
            || actions.contains(const_cast<QAction *>(&m_separator2))
            || actions.contains(const_cast<QAction *>(&m_separator3))) return true;
        for (auto *owner : current->menuAction()->associatedObjects())
            if (const auto *parentMenu = qobject_cast<QMenu *>(owner)) pending.append(parentMenu);
    }
    return false;
}

bool DesktopMenuLayout::darkMode(const QString &plasmaTheme, const QString &scheme, bool paletteDark)
{
    if (plasmaTheme == QStringLiteral("Windows-modern-light")) return false;
    if (plasmaTheme == QStringLiteral("Windows-modern-dark")) return true;
    if (scheme == QStringLiteral("WindowsModernLight")) return false;
    if (scheme == QStringLiteral("WindowsModernDark")) return true;
    return paletteDark;
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
    if (!menu->property("wmDesktopMenuStyled").toBool()) {
        menu->setProperty("wmDesktopMenuOriginalStyle", menu->styleSheet());
        menu->setProperty("wmDesktopMenuOriginalPalette", QVariant::fromValue(menu->palette()));
        menu->setProperty("wmDesktopMenuStyled", true);
    }
    QPalette palette = menu->palette();
    const QColor bg(dark ? "#202020" : "#F9F9F9");
    const QColor fg(dark ? "#FFFFFF" : "#1B1B1B");
    for (const auto role : {QPalette::Window, QPalette::Base, QPalette::Button})
        palette.setColor(role, bg);
    for (const auto role : {QPalette::WindowText, QPalette::Text, QPalette::ButtonText})
        palette.setColor(role, fg);
    menu->setPalette(palette);
    for (auto *action : menu->actions()) setMenuActionIcon(action, dark);
    if (menu->styleSheet() != sheet) menu->setStyleSheet(sheet);
}

void DesktopMenuLayout::restoreAppearance(QMenu *menu)
{
    if (!menu || !menu->property("wmDesktopMenuStyled").toBool()) return;
    const auto previous = menu->property("wmDesktopMenuOriginalStyle").toString();
    const auto palette = menu->property("wmDesktopMenuOriginalPalette").value<QPalette>();
    for (auto *action : menu->actions()) {
        const auto icon = action->property("wmMenuOriginalIcon");
        if (!icon.isValid()) continue;
        action->setIcon(icon.value<QIcon>());
        action->setProperty("wmMenuOriginalIcon", QVariant());
    }
    menu->setProperty("wmDesktopMenuStyled", QVariant());
    menu->setProperty("wmDesktopMenuOriginalStyle", QVariant());
    menu->setProperty("wmDesktopMenuOriginalPalette", QVariant());
    menu->setStyleSheet(previous);
    menu->setPalette(palette);
}
