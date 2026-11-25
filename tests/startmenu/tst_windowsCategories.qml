// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/code/startCategories.js" as Categories

TestCase {
    name: "WindowsStartCategories"
    function test_metadataAndThreshold() {
        compare(Categories.desktopId("applications:org.kde.dolphin.desktop"), "org.kde.dolphin.desktop");
        compare(Categories.explicitCategory("applications:org.kde.dolphin.desktop"), "productivity");
        compare(Categories.explicitCategory("org.kde.kcalc.desktop"), "utilities");
        compare(Categories.categoryForIcon("applications-graphics-symbolic"), "creativity");
        const entries = [
            {index:0, favoriteId:"applications:org.kde.dolphin.desktop", display:"Dolphin"},
            {index:1, favoriteId:"applications:org.kde.kate.desktop", display:"Kate"},
            {index:2, favoriteId:"applications:firefox.desktop", display:"Firefox"},
            {index:3, favoriteId:"applications:org.kde.kcalc.desktop", display:"Calculator"},
            {index:4, favoriteId:"applications:org.kde.spectacle.desktop", display:"Screenshot"},
            {index:5, favoriteId:"applications:unknown.desktop", display:"Unknown"},
            {index:6, favoriteId:"applications:design-a.desktop", display:"Design A"},
            {index:7, favoriteId:"applications:design-b.desktop", display:"Design B"},
            {index:8, favoriteId:"applications:design-c.desktop", display:"Design C"}
        ];
        const memberships = {"design-a.desktop":["creativity","utilities"],
            "design-b.desktop":["creativity"], "design-c.desktop":["creativity"]};
        const usage = ["applications:design-c.desktop","applications:org.kde.kate.desktop"];
        const rows = Categories.build(entries, memberships, usage);
        compare(rows.map(row => row.key).join(","), "creativity,productivity,other");
        compare(rows[0].entries[0].index, 8);
        compare(rows[1].entries[0].index, 1);
        compare(rows[2].entries.map(entry => entry.index).sort().join(","), "3,4,5");
        const all = [];
        for (const row of rows)
            for (const entry of row.entries) all.push(entry.index);
        compare(all.sort().join(","), "0,1,2,3,4,5,6,7,8");
    }
    function test_noInventedApps() {
        compare(Categories.build([], {}, []).length, 0);
        const rows = Categories.build([{index:0, display:"Unclassified"}], {}, []);
        compare(rows.length, 1);
        compare(rows[0].key, "other");
        compare(rows[0].entries[0].index, 0);
    }
}
