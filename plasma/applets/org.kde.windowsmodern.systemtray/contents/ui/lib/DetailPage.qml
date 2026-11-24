import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Page {
    id: page

    showSwitch: true

    property alias listView: list
    property alias emptyText: emptyLabel.text

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: count > 0
        Layout.preferredHeight: count > 0 ? -1 : (headerItem && headerItem.visible ? headerItem.height : 0)
        visible: count > 0 || (headerItem && headerItem.visible)
        spacing: 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        PlasmaComponents3.ScrollBar.vertical: PlasmaComponents3.ScrollBar {
            policy: PlasmaComponents3.ScrollBar.AsNeeded
            width: 16
            hoverEnabled: true
        }
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
        visible: list.count === 0
        color: Kirigami.Theme.textColor
        opacity: 0.8
        font: Kirigami.Theme.defaultFont
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
