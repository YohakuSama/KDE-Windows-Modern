import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string iconSource: ""
    property string tooltipText: ""

    property int buttonSize: 20
    readonly property int hitSize: Math.max(buttonSize, Math.round(buttonSize * 2))

    signal clicked
    signal rightClicked

    implicitWidth: hitSize
    implicitHeight: hitSize
    activeFocusOnTab: true
    Accessible.onPressAction: root.clicked()
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
            Kirigami.Theme.textColor.b, mouseArea.containsPress ? 0.10
                : mouseArea.containsMouse || root.activeFocus ? 0.06 : 0)
    }

    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        mainText: root.tooltipText
        subText: ""
        textFormat: Text.PlainText
    }

    Kirigami.Icon {
        width: root.buttonSize; height: root.buttonSize
        anchors.centerIn: parent
        source: root.iconSource
        color: Kirigami.Theme.textColor
        isMask: true
        opacity: 1
        roundToIconSize: false
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton) {
                root.rightClicked();
            } else {
                root.clicked();
            }
        }
    }
}
