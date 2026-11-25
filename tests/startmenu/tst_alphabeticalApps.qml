// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import org.kde.kitemmodels as KItemModels
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
    KItemModels.KSortFilterProxyModel {
        id: sortedProxy
        sourceModel: apps
        sortRoleName: "display"
        sortOrder: Qt.AscendingOrder
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
            compare(Alphabetical.sectionForEntry({display:"浏览器", group:"L"}), "L");
            compare(Alphabetical.sectionForEntry({display:"Éditeur", group:"É"}), "E");
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
        function test_letterIndexJumpAndUnavailableLetters() {
            tryCompare(view, "count", 5);
            verify(view.letterIndexEntries.find(item => item.label === "A").available);
            verify(view.letterIndexEntries.find(item => item.label === "F").available);
            verify(!view.letterIndexEntries.find(item => item.label === "B").available);
            view.openLetterIndex();
            tryCompare(view, "letterIndexOpen", true);
            const overlay = findChild(view, "wmStartLetterIndexOverlay");
            verify(overlay);
            tryCompare(overlay, "opacity", 1);
            const fileLetter = findChild(overlay, "wmStartLetterIndex_F");
            verify(fileLetter);
            mouseClick(fileLetter, fileLetter.width / 2, fileLetter.height / 2);
            tryCompare(view, "letterIndexOpen", false);
            compare(view.currentIndex, 4);
            compare(view.jumpToLetter("B"), false);
            compare(view.currentIndex, 4);
            tryCompare(overlay, "opacity", 0);
        }
        function test_headingHoverAndOpen() {
            tryCompare(view, "count", 5);
            view.positionViewAtBeginning();
            const rows = findChild(view, "wmStartAlphabeticalRows");
            tryVerify(() => rows.itemAtIndex(0) !== null);
            const heading = findChild(rows.itemAtIndex(0), "wmStartLetterHeading");
            const hitArea = findChild(heading, "wmStartLetterHeadingHitArea");
            verify(heading && hitArea);
            mouseMove(hitArea, hitArea.width / 2, hitArea.height / 2);
            tryVerify(() => heading.hovered);
            mouseClick(hitArea, hitArea.width / 2, hitArea.height / 2);
            tryCompare(view, "letterIndexOpen", true);
            view.closeLetterIndex(true);
            tryCompare(view, "letterIndexOpen", false);
            tryCompare(overlayForTest(), "opacity", 0);
        }
        function overlayForTest() { return findChild(view, "wmStartLetterIndexOverlay"); }
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
        function test_realProxyRoles() {
            view.sourceModel = sortedProxy;
            tryVerify(() => view.count === 5 && view.sourceEntries[0].display === "Accessibility");
            compare(view.sourceEntries[0].favoriteId, "a.desktop");
            compare(view.visualRows.map(row => row.heading).join(","), "A,C,F");
            view.sourceModel = apps;
            tryCompare(view, "count", 5);
        }
        function test_visibilityDoesNotRebuildSnapshot() {
            tryCompare(view, "count", 5);
            const snapshot = view.sourceEntries;
            view.showApps = false;
            tryCompare(view, "count", 0);
            wait(20);
            verify(view.sourceEntries === snapshot);
            view.showApps = true;
            tryCompare(view, "count", 5);
            verify(view.sourceEntries === snapshot);
        }
        function test_nonAlphabeticalSortRemainsAvailable() {
            view.alphabeticalGrouping = false;
            compare(view.visualRows.length, 1);
            compare(view.visualRows[0].heading, "");
            view.alphabeticalGrouping = true;
        }
    }
}
