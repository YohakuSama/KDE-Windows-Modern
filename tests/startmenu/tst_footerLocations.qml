// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/code/footerLocations.js" as Locations

TestCase {
    name: "StartFooterLocations"
    function test_everyShortcutHasRealDispatch() {
        const entries = Locations.locations(s => s);
        for (const location of entries) {
            let folder = "";
            let opened = "";
            let command = "";
            const result = Locations.invoke(location,
                key => { folder = key; return "file:///home/test/" + key; },
                url => { opened = url; return true; },
                cmd => { command = cmd; return true; });
            verify(result, location.key);
            if (location.folder) {
                compare(folder, location.folder);
                compare(opened, "file:///home/test/" + location.folder);
                compare(command, "");
            } else {
                compare(command, location.command);
                compare(opened, "");
            }
        }
        verify(!Locations.invoke(entries[0], () => "", () => true, () => true));
        verify(!Locations.invoke(entries[0], () => "file:///x", () => false, () => true));
        verify(!Locations.invoke(entries[8], () => "", () => true, () => false));
    }
    function test_referenceOrderAndMigration() {
        const expected = ["documents", "downloads", "music", "pictures", "videos",
                          "network", "home", "thispc", "settings"];
        compare(Locations.normalize(undefined), expected);
        compare(Locations.normalize(["home", "documents", "pictures", "music", "downloads",
                                    "recent", "thispc", "update", "terminal", "run"]), expected);
        compare(Locations.normalize(["settings", "downloads", "home"]), ["downloads", "home", "settings"]);
        compare(Locations.toggle(["documents", "settings"], "documents", false), ["settings"]);
        compare(Locations.toggle(["settings"], "music", true), ["music", "settings"]);
        compare(Locations.normalize([]), []);
        compare(Locations.normalize(["terminal"]), ["terminal"]);
        const entries = Locations.locations(s => s);
        compare(entries.slice(0, 9).map(item => item.key), expected);
    }
}
