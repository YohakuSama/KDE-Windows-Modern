// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/pages"
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/code/alphabeticalApps.js" as Alphabetical

Item {
    width: 640
    height: 420
    ListModel {
        id: apps
        ListElement { display: "Accessibility"; favoriteId: "a.desktop" }
        ListElement { display: "Calculator"; favoriteId: "c.desktop" }
        ListElement { display: "Camera"; favoriteId: "camera.desktop" }
        ListElement { display: "Clock"; favoriteId: "clock.desktop" }
        ListElement { display: "File Explorer"; favoriteId: "files.desktop" }
    }
    AlphabeticalAppsView {
        id: view
        anchors.fill: parent
        sourceModel: apps
        gridMode: true
    }
    SignalSpy { id: activated; target: view; signalName: "applicationActivated" }
    TestCase {
        name: "WindowsStartAlphabetical"
        when: windowShown
        function test_sectionsAndNavigation() {
            compare(Alphabetical.sectionForName("  Éditeur"), "E");
            compare(Alphabetical.sectionForName("7-Zip"), "#");
            compare(Alphabetical.sectionForName("浏览器"), "浏");
            tryCompare(view, "count", 5);
            compare(view.columns, 6);
            compare(view.visualRows.length, 3);
            compare(view.visualRows.map(row => row.heading).join(","), "A,C,F");
            compare(view.visualRows[1].entries.length, 3);
            view.currentIndex = 0;
            view.moveVertical(1);
            compare(view.currentIndex, 1);
            view.moveHorizontal(1);
            compare(view.currentIndex, 2);
            view.moveVertical(1);
            compare(view.currentIndex, 4);
            view.activateRow(4);
            compare(activated.count, 1);
            compare(activated.signalArguments[0][0], 4);
            view.gridMode = false;
            compare(view.visualRows.length, 5);
            compare(view.visualRows.map(row => row.heading).join(","), "A,C,,,F");
            view.gridMode = true;
        }
        function test_modelUpdatesKeepSourceIdentity() {
            tryCompare(view, "count", 5);
            view.currentIndex = 4;
            apps.insert(0, {display: "7-Zip", favoriteId: "7.desktop"});
            tryCompare(view, "count", 6);
            compare(view.currentIndex, 5);
            compare(view.visualRows[0].heading, "#");
            apps.remove(0);
            tryCompare(view, "count", 5);
            compare(view.currentIndex, 4);
        }
        function test_nonAlphabeticalSortRemainsAvailable() {
            view.alphabeticalGrouping = false;
            compare(view.visualRows.length, 1);
            compare(view.visualRows[0].heading, "");
            view.alphabeticalGrouping = true;
        }
    }
}
