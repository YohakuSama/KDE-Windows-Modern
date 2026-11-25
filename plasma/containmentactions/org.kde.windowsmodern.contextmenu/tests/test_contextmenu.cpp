// SPDX-License-Identifier: GPL-3.0-or-later
#include "menulayout.h"
#include <QApplication>
#include <QDebug>

#define REQUIRE(expr) do { if (!(expr)) { qCritical() << "Failed:" << #expr; return 1; } } while (false)

int main(int argc, char **argv)
{
    QApplication app(argc, argv);
    DesktopMenuLayout layout;
    QMenu icons, sort, sizes;
    QAction *unsorted = sort.addAction("Unsorted");
    unsorted->setCheckable(true);
    unsorted->setData(-1);
    QAction *name = sort.addAction("Name");
    name->setCheckable(true);
    QAction *size = sizes.addAction("Large");
    size->setCheckable(true);
    icons.addMenu(&sort);
    icons.addMenu(&sizes);
    QAction newFile("New"), paste("Paste"), undo("Undo"), refresh("Refresh"),
        customize("Desktop and Wallpaper"), edit("Edit Mode"), hidden("Hidden"), separator;
    newFile.setObjectName(QStringLiteral("newMenu"));
    paste.setObjectName(QStringLiteral("paste"));
    undo.setObjectName(QStringLiteral("undo"));
    paste.setEnabled(false);
    hidden.setVisible(false);
    separator.setSeparator(true);
    const QList<QAction *> native{&newFile, &paste, &undo, icons.menuAction(),
        &separator, &edit, &customize, &hidden};
    int triggered = 0;
    QObject::connect(&refresh, &QAction::triggered, [&] { ++triggered; });
    QObject::connect(name, &QAction::triggered, [&] { ++triggered; });
    QObject::connect(&customize, &QAction::triggered, [&] { ++triggered; });
    auto result = layout.build(native, &refresh, &customize);
    REQUIRE(result.size() >= 7);
    REQUIRE(result.at(0)->menu());
    REQUIRE(result.at(0)->menu()->actions().contains(sizes.menuAction()));
    REQUIRE(result.at(1) == sort.menuAction());
    REQUIRE(result.at(2) == &refresh);
    REQUIRE(result.contains(&newFile));
    REQUIRE(result.contains(&paste) && !paste.isEnabled());
    REQUIRE(result.indexOf(&refresh) < result.indexOf(&paste));
    REQUIRE(result.indexOf(&paste) < result.indexOf(&undo));
    REQUIRE(result.indexOf(&undo) < result.indexOf(&newFile));
    REQUIRE(result.contains(&customize));
    REQUIRE(!result.contains(&hidden));
    REQUIRE(!result.contains(icons.menuAction()));
    QMenu *more = result.last()->menu();
    REQUIRE(more && !more->actions().contains(&undo) && more->actions().contains(&edit));
    REQUIRE(!more->actions().contains(&paste) && !more->actions().contains(&customize));
    refresh.trigger();
    name->trigger();
    customize.trigger();
    REQUIRE(triggered == 3);
    result = layout.build(native, &refresh, &customize);
    REQUIRE(result.at(1) == sort.menuAction());
    REQUIRE(sort.actions().contains(name));
    undo.setEnabled(false);
    result = layout.build(native, &refresh, &customize);
    REQUIRE(!result.contains(&undo));
    REQUIRE(!result.last()->menu()->actions().contains(&undo));
    REQUIRE(result.indexOf(&paste) < result.indexOf(&newFile));
    REQUIRE(layout.build({}, nullptr, nullptr).isEmpty());
    return 0;
}
