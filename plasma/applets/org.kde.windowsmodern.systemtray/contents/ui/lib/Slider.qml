import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../js/colorType.js" as ColorType

Item {
    id: root

    property string iconSource
    property int from: 0
    property int to: 100
    property int value: 0
    property int stepSize: 1
    property int iconSize: 20
    property bool pressed: false
    property bool showArrow: false
    // Home rows reserve the same output slot so both tracks end at
    // the same x coordinate. Other detail-page sliders stay full-width.
    property bool reserveDetailsSpace: false
    property bool soundOutputDetails: false
    property string detailsIconSource: ""
    property string detailsAccessibleName: ""
    property bool iconClickable: false
    readonly property bool dark: ColorType.isDark(Kirigami.Theme.backgroundColor)

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
            objectName: "wmFluentSliderTrack"
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
                    color: root.dark ? "#A0A0A0" : "#888888"
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
                color: root.dark ? "#383838" : "#FFFFFF"
                border.width: 1
                border.color: root.dark ? "#4B4B4B" : "#D6D6D6"
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
            visible: root.showArrow || root.reserveDetailsSpace
            enabled: root.showArrow
            opacity: root.showArrow ? 1 : 0
            Layout.preferredWidth: root.reserveDetailsSpace || root.soundOutputDetails || root.detailsIconSource.length > 0 ? 36 : 24
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignVCenter
            activeFocusOnTab: root.showArrow
            Accessible.role: Accessible.Button
            Accessible.name: root.detailsAccessibleName || i18n("More")
            Accessible.onPressAction: root.arrowClicked()
            Keys.onReturnPressed: root.arrowClicked()
            Keys.onEnterPressed: root.arrowClicked()
            Keys.onSpacePressed: root.arrowClicked()

            Rectangle {
                anchors.fill: parent
                radius: 4
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                    Kirigami.Theme.textColor.b, detailsMouse.containsPress ? 0.10
                        : detailsMouse.containsMouse || detailsButton.activeFocus ? 0.06 : 0)
            }

            Row {
                anchors.centerIn: parent
                spacing: 2
                Kirigami.Icon {
                    visible: !root.soundOutputDetails && root.detailsIconSource.length > 0
                    width: 18
                    height: 18
                    source: root.detailsIconSource
                    roundToIconSize: false
                    isMask: true
                    color: Kirigami.Theme.textColor
                }
                Canvas {
                    id: outputGlyph
                    visible: root.soundOutputDetails
                    width: 18
                    height: 18
                    property color glyphColor: Kirigami.Theme.textColor
                    onGlyphColorChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        const c = getContext("2d");
                        c.reset();
                        c.clearRect(0, 0, width, height);
                        c.scale(width / 20, height / 20);
                        c.strokeStyle = glyphColor;
                        c.fillStyle = glyphColor;
                        c.lineWidth = 1.35;
                        c.lineCap = "round";
                        c.lineJoin = "round";
                        c.beginPath();
                        c.moveTo(1.8, 5);
                        c.lineTo(6, 5);
                        c.moveTo(10, 5);
                        c.lineTo(18, 5);
                        c.moveTo(2, 13);
                        c.lineTo(7, 13);
                        c.stroke();
                        c.beginPath();
                        c.arc(8, 5, 2, 0, Math.PI * 2);
                        c.stroke();
                        c.beginPath();
                        c.moveTo(8.5, 11.2);
                        c.lineTo(11, 11.2);
                        c.lineTo(14.1, 8.6);
                        c.lineTo(14.1, 17.4);
                        c.lineTo(11, 14.8);
                        c.lineTo(8.5, 14.8);
                        c.closePath();
                        c.fill();
                        c.beginPath();
                        c.moveTo(16, 10.4);
                        c.quadraticCurveTo(18, 13, 16, 15.6);
                        c.stroke();
                    }
                }
                Kirigami.Icon {
                    width: 12
                    height: 18
                    source: "go-next-symbolic"
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
