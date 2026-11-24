// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/components" as Components

Item {
    width: 300
    height: 80
    function i18n(text, argument) {
        return argument === undefined ? text : text.replace("%1", argument);
    }
    Components.StartViewSelector {
        id: selector
        width: 180
        height: 32
    }
    TestCase {
        name: "StartViewSelector"
        when: windowShown
        function test_explicitLabelForEveryView() {
            const label = findChild(selector, "wmStartViewLabel");
            verify(label !== null);
            for (let i = 0; i < 3; ++i) {
                selector.mode = i;
                tryCompare(selector, "currentIndex", i);
                tryCompare(label, "text", selector.displayText);
                verify(label.text.length > 0);
                verify(label.text.indexOf(selector.modeLabels[i]) >= 0);
            }
        }
    }
}
