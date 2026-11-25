// Live network status only; no duplicate audio or battery controls.
import QtQuick

Row {
    Loader {
        source: "NetworkStatusIcon.qml"
        visible: status === Loader.Ready
        anchors.verticalCenter: parent.verticalCenter
    }
}
