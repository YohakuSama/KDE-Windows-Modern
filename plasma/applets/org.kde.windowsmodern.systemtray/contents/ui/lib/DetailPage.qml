// SPDX-License-Identifier: GPL-3.0-or-later
// The device list owns the only scroll viewport. Avoid nested ScrollView and
// ListView geometry fighting over content height and wheel input.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

ColumnLayout {
    id: page
    spacing: 0
    property color shellAccent: Kirigami.Theme.highlightColor
    property string title
    property bool showSwitch: true
    property bool switchEnabled: true
    property bool switchChecked: false
    property Component footer: null
    signal back()
    signal switchToggled()
    property alias listView: list
    property alias emptyText: emptyLabel.text

    PageHeader {
        title: page.title
        shellAccent: page.shellAccent
        showSwitch: page.showSwitch
        switchEnabled: page.switchEnabled
        switchChecked: page.switchChecked
        onBack: page.back()
        onSwitchToggled: page.switchToggled()
    }

    ListView {
        id: list
        readonly property int headerHeight: headerItem ? headerItem.height : 0
        Layout.fillWidth: true
        Layout.fillHeight: count > 0
        Layout.preferredHeight: count > 0 ? -1 : headerHeight
        visible: count > 0 || headerHeight > 0
        spacing: 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: FluentScrollBar {}
        Kirigami.WheelHandler {
            target: list
            filterMouseEvents: true
            keyNavigationEnabled: false
            verticalStepSize: Math.max(120, 3 * (list.currentItem
                ? list.currentItem.height + list.spacing : Kirigami.Units.gridUnit * 2))
        }
    }

    PlasmaComponents3.Label {
        id: emptyLabel
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: 16
        visible: list.count === 0
        color: Kirigami.Theme.textColor
        opacity: 0.8
        font: Kirigami.Theme.defaultFont
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
