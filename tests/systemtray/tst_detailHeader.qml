// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/lib" as Lib
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/components" as Components
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/js/controlMetrics.js" as ControlMetrics

Item {
    id: fixture
    property int footerClicks: 0
    width: 360
    height: 300
    ColumnLayout {
        anchors.fill: parent
        Lib.PageHeader {
            id: header
            title: "Bluetooth"
            showSwitch: true
            onSwitchToggled: switchChecked = !switchChecked
        }
        Item { Layout.fillHeight: true }
    }
    Component {
        id: footerContent
        ColumnLayout {
            spacing: 0
            Lib.MoreSettingsLink {
                objectName: "wmTestFooterLink"
                text: "More settings"
                onClicked: fixture.footerClicks++
            }
            Lib.MoreSettingsLink { text: "Display settings" }
        }
    }
    Component {
        id: pageComponent
        Lib.Page {
            width: 300
            height: 240
            title: "Volume"
            footer: footerContent
            Item { Layout.fillWidth: true; implicitHeight: 600 }
        }
    }
    Component {
        id: detailComponent
        Lib.DetailPage {
            width: 300
            height: 240
            title: "Bluetooth"
            emptyText: "No devices"
            footer: footerContent
        }
    }
    Component {
        id: missingMenuComponent
        Components.NativeMenuItem {
            text: "More settings"
            nativeRole: "wm-test-absent-glyph-not-installed"
        }
    }
    SignalSpy { id: toggled; target: header; signalName: "switchToggled" }
    SignalSpy { id: wentBack; target: header; signalName: "back" }
    SignalSpy { id: action; target: header; signalName: "actionTriggered" }
    TestCase {
        name: "DetailHeaderGeometry"
        when: windowShown
        function center(item) { return item.mapToItem(header, 0, item.height / 2).y; }
        function test_nativeButtonAndMenuMaskContract() {
            const back = findChild(header, "wmDetailBack");
            const glyph = findChild(back, "wmNativeButtonGlyph");
            verify(back && glyph);
            verify(glyph.isMask);
            compare(glyph.nativeSource, back.nativeIcon);
            compare(back.contentItem.labelShown, back.nativeIcon.length === 0);
            const menu = createTemporaryObject(missingMenuComponent, fixture);
            verify(menu);
            compare(menu.nativeIcon, "");
            const menuGlyph = findChild(menu, "wmNativeMenuGlyph");
            verify(menuGlyph && menuGlyph.isMask);
            compare(menuGlyph.nativeSource, "");
            compare(menu.text, "More settings");
        }
        function test_commonCenterlineAndSwitch() {
            header.showSwitch = true;
            header.showAction = false;
            header.switchChecked = false;
            const back = findChild(header, "wmDetailBack");
            const title = findChild(header, "wmDetailTitle");
            const sw = findChild(header, "wmDetailSwitch");
            const track = findChild(sw, "wmDetailSwitchTrack");
            verify(back && title && sw && track);
            tryVerify(() => back.width > 0 && sw.width > 0);
            verify(Math.abs(center(back) - center(title)) <= 1);
            verify(Math.abs(center(title) - center(track)) <= 1);
            compare(track.width, 40);
            compare(track.height, 20);
            compare(sw.background.radius, ControlMetrics.controlCornerRadius);
            toggled.clear();
            mouseClick(sw, sw.width / 2, sw.height / 2);
            compare(toggled.count, 1);
            tryCompare(header, "switchChecked", true);
            wentBack.clear();
            mouseClick(back, back.width / 2, back.height / 2);
            compare(wentBack.count, 1);
        }
        function test_switchKnobStates() {
            header.showSwitch = true;
            header.showAction = false;
            header.switchEnabled = true;
            header.switchChecked = false;
            const sw = findChild(header, "wmDetailSwitch");
            const knob = findChild(sw, "wmDetailSwitchKnob");
            verify(sw && knob);
            try {
                mouseMove(fixture, fixture.width - 1, fixture.height - 1);
                tryCompare(knob, "width", 12);
                compare(knob.height, 12);
                mouseMove(sw, sw.width / 2, sw.height / 2);
                tryCompare(knob, "width", 14);
                tryCompare(knob, "height", 14);
                mousePress(sw, sw.width / 2, sw.height / 2);
                tryCompare(knob, "width", 17);
                tryCompare(knob, "height", 14);
                mouseRelease(sw, sw.width / 2, sw.height / 2);
                tryCompare(header, "switchChecked", true);
                header.switchEnabled = false;
                tryCompare(knob, "width", 12);
                tryCompare(knob, "height", 12);
            } finally {
                header.switchEnabled = true;
            }
        }

        function test_fixedFooter_data() {
            return [{tag: "scroll page", component: pageComponent},
                    {tag: "empty detail page", component: detailComponent}];
        }
        function test_fixedFooter(data) {
            const page = createTemporaryObject(data.component, fixture);
            verify(page);
            const loader = findChild(page, "wmDetailPageFooter");
            verify(loader);
            tryVerify(() => loader.item !== null && loader.height > 0);
            const link = findChild(loader.item, "wmTestFooterLink");
            verify(link);
            const linkBackground = findChild(link, "wmMoreSettingsLinkBackground");
            verify(linkBackground);
            compare(linkBackground.radius, ControlMetrics.controlCornerRadius);
            tryVerify(() => Math.abs(loader.y + loader.height - page.height) <= 1);
            compare(loader.height, loader.item.implicitHeight + 4);
            tryCompare(link, "width", loader.width);
            const viewport = findChild(page, "wmDetailScrollView");
            if (viewport) {
                verify(viewport.height > 0);
                verify(viewport.y + viewport.height <= loader.y + 1);
                const bar = findChild(viewport, "wmDetailScrollBar");
                verify(bar);
                mouseMove(viewport, 20, 20);
                tryCompare(bar, "viewportHovered", true);
                tryCompare(bar, "indicatorVisible", true);
            }
            fixture.footerClicks = 0;
            mouseClick(link, link.width / 2, link.height / 2);
            compare(fixture.footerClicks, 1);
            page.footer = null;
            tryCompare(loader, "visible", false);
            tryVerify(() => loader.item === null && loader.implicitHeight === 0);
        }

        function test_conditionalAction() {
            header.showSwitch = false;
            header.showAction = true;
            header.actionText = "Clear all";
            const button = findChild(header, "wmDetailAction");
            tryCompare(button, "visible", true);
            action.clear();
            mouseClick(button, button.width / 2, button.height / 2);
            compare(action.count, 1);
            header.showAction = false;
            tryCompare(button, "visible", false);
        }
    }
}
