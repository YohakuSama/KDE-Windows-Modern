// Network and battery; an unavailable loader must not reserve a gap.
import QtQuick

Row {
    spacing: 4
    Loader {
        source: "NetworkStatusIcon.qml"
        visible: status === Loader.Ready
        anchors.verticalCenter: parent.verticalCenter
    }
    Loader {
        source: "BatteryStatusIcon.qml"
        visible: status === Loader.Ready && item && item.available
        anchors.verticalCenter: parent.verticalCenter
    }
}
