import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: root

    Win11Palette { id: fluent }

    property string iconSource
    property int from: 0
    property int to: 100
    property int value: 0
    property int stepSize: 1
    property int iconSize: 20
    property bool pressed: false
    property bool showArrow: false
    property string detailsIconSource: ""
    property string detailsAccessibleName: ""
    property bool iconClickable: false

    signal moved(int value)
    signal released
    signal arrowClicked
    signal iconClicked
    signal rightClicked
    signal middleClicked

    implicitHeight: 36

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.ArrowCursor
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton)
                root.rightClicked();
            else if (mouse.button === Qt.MiddleButton)
                root.middleClicked();
        }
    }

    GridLayout {
        anchors.fill: parent
        columns: 3
        columnSpacing: 12

        Kirigami.Icon {
            Layout.preferredWidth: root.iconSize
            Layout.preferredHeight: root.iconSize
            Layout.alignment: Qt.AlignVCenter
            source: root.iconSource
            roundToIconSize: false
            isMask: true
            color: Kirigami.Theme.textColor

            MouseArea {
                anchors.fill: parent
                enabled: root.iconClickable
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.iconClicked()
            }
        }

        PlasmaComponents3.Slider {
            id: slider
            Layout.fillWidth: true
            from: root.from
            to: root.to
            value: root.value
            stepSize: root.stepSize
            leftPadding: 0
            rightPadding: 0

            // Fluent track and thumb; the native control retains keyboard,
            // mouse, accessibility, wheel and value semantics.
            background: Item {
                x: slider.leftPadding + 10
                y: (slider.height - height) / 2
                width: Math.max(0, slider.availableWidth - 20)
                height: 4
                Rectangle {
                    anchors.fill: parent
                    radius: 2
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                        Kirigami.Theme.textColor.b, 0.38)
                }
                Rectangle {
                    width: parent.width * slider.position
                    height: parent.height
                    x: slider.mirrored ? parent.width - width : 0
                    radius: 2
                    color: Kirigami.Theme.highlightColor
                }
            }

            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * Math.max(0, slider.availableWidth - width)
                y: (slider.height - height) / 2
                width: 20
                height: 20
                radius: width / 2
                color: fluent.menuBackground
                border.width: 1
                border.color: slider.activeFocus ? fluent.accent : fluent.controlBorder
                Rectangle {
                    anchors.centerIn: parent
                    width: slider.pressed ? 10 : 12
                    height: width
                    radius: width / 2
                    color: Kirigami.Theme.highlightColor
                }
            }

            onMoved: root.moved(value)
            onPressedChanged: {
                if (!slider.pressed)
                    root.released();
            }

            Binding {
                root.pressed: slider.pressed
            }
        }

        Item {
            id: detailsButton
            visible: root.showArrow
            Layout.preferredWidth: root.detailsIconSource.length > 0 ? 36 : 24
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignVCenter
            activeFocusOnTab: visible
            Accessible.role: Accessible.Button
            Accessible.name: root.detailsAccessibleName || i18n("More")
            Accessible.onPressAction: root.arrowClicked()
            Keys.onReturnPressed: root.arrowClicked()
            Keys.onEnterPressed: root.arrowClicked()
            Keys.onSpacePressed: root.arrowClicked()

            Rectangle {
                anchors.fill: parent
                radius: fluent.controlRadius
                color: detailsMouse.containsPress ? fluent.controlPressed
                    : detailsMouse.containsMouse || detailsButton.activeFocus ? fluent.controlHover : "transparent"
                border.width: detailsButton.activeFocus ? 1 : 0
                border.color: fluent.accent
            }

            Row {
                anchors.centerIn: parent
                spacing: 2
                Kirigami.Icon {
                    visible: root.detailsIconSource.length > 0
                    width: 18
                    height: 18
                    source: root.detailsIconSource
                    roundToIconSize: false
                    isMask: true
                    color: Kirigami.Theme.textColor
                }
                Kirigami.Icon {
                    width: 12
                    height: 18
                    source: "go-next"
                    roundToIconSize: false
                    isMask: true
                    color: Kirigami.Theme.textColor
                }
            }

            MouseArea {
                id: detailsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.arrowClicked()
            }
        }
    }

    WheelHandler {
        target: slider
        orientation: Qt.Vertical
        acceptedButtons: Qt.NoButton
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function (wheel) {
            const delta = wheel.angleDelta.y;
            if (delta > 0)
                slider.increase();
            else if (delta < 0)
                slider.decrease();
            slider.moved();
        }
    }
}
