// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/code/tools.js" as Tools

TestCase {
    name: "StartSearchIdentity"
    function test_resolveOnlyStableUniqueUrl() {
        const apps = [{display: "Editor", url: "file:///usr/share/applications/one.desktop", index: 0},
                      {display: "Editor", url: "file:///usr/share/applications/two.desktop", index: 1}];
        compare(Tools.findAppByUrls(apps, ["file:///usr/share/applications/two.desktop"]).index, 1);
        compare(Tools.findAppByUrls(apps, ["Editor"]), null);
        compare(Tools.findAppByUrls(apps, ["file:///home/user/Editor"]), null);
        compare(Tools.findAppByUrls(apps, []), null);
        compare(Tools.findAppByUrls(apps.concat([apps[0]]), [apps[0].url]), null);
    }
}
