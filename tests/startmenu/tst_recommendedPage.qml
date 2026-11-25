// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/pages"

Item {
    width: 600
    height: 500
    ListModel {
        id: recent
        ListElement { display: "Document"; description: "/home/test"; url: "file:///home/test/Document"; decoration: "text-x-generic" }
        ListElement { display: "Terminal"; description: "Command line"; url: "file:///usr/share/applications/terminal.desktop"; decoration: "utilities-terminal" }
        ListElement { display: "Third"; description: "Third"; url: "file:///home/test/Third"; decoration: "text-x-generic" }
        ListElement { display: "Fourth"; description: "Fourth"; url: "file:///home/test/Fourth"; decoration: "text-x-generic" }
        ListElement { display: "Fifth"; description: "Fifth"; url: "file:///home/test/Fifth"; decoration: "text-x-generic" }
    }
    RecommendedPage { id: page; anchors.fill: parent; sourceModel: recent }
    SignalSpy { id: back; target: page; signalName: "backRequested" }
    SignalSpy { id: launch; target: page; signalName: "launchRequested" }
    SignalSpy { id: context; target: page; signalName: "contextRequested" }
    TestCase {
        name: "StartRecommendedPage"
        when: windowShown
        function init() { page.reset(); back.clear(); launch.clear(); context.clear(); }
        function test_fullSingleColumnAndActivation() {
            tryCompare(page.resultsView, "count", 5);
            const first = page.resultsView.itemAtIndex(0);
            const second = page.resultsView.itemAtIndex(1);
            verify(first && second);
            compare(first.x, second.x);
            compare(second.y - first.y, first.height);
            mouseClick(second, second.width / 2, second.height / 2);
            tryCompare(launch, "count", 1);
            compare(launch.signalArguments[0][0], 1);
            mouseClick(first, first.width / 2, first.height / 2, Qt.RightButton);
            tryCompare(context, "count", 1);
            compare(context.signalArguments[0][1], 0);
        }
        function test_backByMouseAndKeyboard() {
            const button = findChild(page, "wmStartRecommendedBack");
            verify(button);
            mouseClick(button);
            tryCompare(back, "count", 1);
            page.focusResults();
            keyClick(Qt.Key_Escape);
            tryCompare(back, "count", 2);
        }
    }
}
