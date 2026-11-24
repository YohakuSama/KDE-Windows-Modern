import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../js/colorType.js" as ColorType

ColumnLayout {
    id: tile

    property string iconSource
    property string label
    property string tooltipText: ""
    property bool active: false
    property bool toggleAvailable: true

    signal clicked
    signal arrowClicked
    signal rightClicked
    signal middleClicked

    activeFocusOnTab: toggleAvailable
    focus: true

    Accessible.role: Accessible.CheckBox
    Accessible.name: tile.label
    Accessible.checked: tile.active
    Accessible.onPressAction: if (tile.toggleAvailable) tile.clicked()
    Keys.onReturnPressed: if (tile.toggleAvailable) tile.clicked()
    Keys.onEnterPressed: if (tile.toggleAvailable) tile.clicked()
    Keys.onSpacePressed: if (tile.toggleAvailable) tile.clicked()

    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color fg: active ? ColorType.contrastingForeground(accent) : Kirigami.Theme.textColor

    spacing: 4
    Layout.fillWidth: true
    Layout.preferredWidth: 0

    Rectangle {
        id: bg
        Layout.fillWidth: true
        Layout.preferredHeight: width / 2
        radius: 4
        border.width: 1
        border.color: tile.activeFocus || arrowMA.activeFocus ? Kirigami.Theme.textColor : active ? "transparent" : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
        color: {
            if (active) {
                const alpha = toggleMA.containsPress || arrowMA.containsPress ? 0.12
                    : toggleMA.containsMouse || arrowMA.containsMouse ? 0.06 : 0;
                return Qt.tint(accent, Qt.rgba(tile.fg.r, tile.fg.g, tile.fg.b, alpha));
            }
            if (toggleMA.containsPress || arrowMA.containsPress)
                return Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10);
            if (toggleMA.containsMouse || arrowMA.containsMouse)
                return Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06);
            return Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.04);
        }

        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }

        PlasmaCore.ToolTipArea {
            anchors.fill: parent
            mainText: tile.tooltipText
            subText: ""
            textFormat: Text.PlainText
        }

        MouseArea {
            id: toggleMA
            enabled: tile.toggleAvailable
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * 0.70
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: function (mouse) {
                if (mouse.button === Qt.RightButton) {
                    tile.rightClicked();
                } else if (mouse.button === Qt.MiddleButton) {
                    tile.middleClicked();
                } else {
                    tile.clicked();
                }
            }
        }

        MouseArea {
            id: arrowMA
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * 0.30
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("%1 details").arg(tile.label)
            Accessible.onPressAction: tile.arrowClicked()
            Keys.onReturnPressed: tile.arrowClicked()
            Keys.onEnterPressed: tile.arrowClicked()
            Keys.onSpacePressed: tile.arrowClicked()
            onClicked: tile.arrowClicked()
        }

        Kirigami.Icon {
            x: parent.width * 0.35 - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: Kirigami.Units.iconSizes.smallMedium
            height: Kirigami.Units.iconSizes.smallMedium
            source: tile.iconSource
            opacity: tile.toggleAvailable ? 1 : 0.55
            color: tile.fg
            isMask: true
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width * 0.70
            width: 1
            height: parent.height * 0.5
            color: active ? Qt.rgba(tile.fg.r, tile.fg.g, tile.fg.b, 0.28) : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
        }

        Kirigami.Icon {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: Kirigami.Units.iconSizes.small
            height: Kirigami.Units.iconSizes.small
            source: "go-next"
            color: tile.fg
            isMask: true
        }
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        text: tile.label
        color: Kirigami.Theme.textColor
        font: Kirigami.Theme.defaultFont
        maximumLineCount: 1
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
    }
}
