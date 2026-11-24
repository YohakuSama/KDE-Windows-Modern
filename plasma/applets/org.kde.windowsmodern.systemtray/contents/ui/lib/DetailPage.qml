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
        WheelHandler {
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            enabled: list.visible && list.contentHeight > list.height
            onWheel: event => {
                const pixels = event.pixelDelta.y;
                const angle = event.angleDelta.y;
                const row = list.currentItem ? Math.max(28, list.currentItem.height + list.spacing)
                                             : Math.max(40, Kirigami.Units.gridUnit * 2);
                const delta = pixels !== 0 && Math.abs(angle) < 120 ? pixels
                            : angle !== 0 ? angle / 120 * 3 * row : pixels;
                if (delta === 0) { event.accepted = false; return; }
                const low = list.originY - list.topMargin;
                const high = Math.max(low, list.originY + list.contentHeight - list.height + list.bottomMargin);
                list.cancelFlick();
                list.contentY = Math.max(low, Math.min(high, list.contentY - delta));
                event.accepted = true;
            }
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
