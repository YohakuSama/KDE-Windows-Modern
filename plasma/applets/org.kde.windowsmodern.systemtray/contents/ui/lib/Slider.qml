import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

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
    property string sliderAccessibleName: ""
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

        FluentSlider {
            id: slider
            objectName: "wmQuickSettingSlider"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 24
            Layout.preferredHeight: implicitHeight
            from: root.from
            to: root.to
            value: root.value
            stepSize: root.stepSize
            Accessible.name: root.sliderAccessibleName
            // The row's wheel handler below is the only wheel path. Mouse,
            // touch, keyboard and accessibility remain native Qt Slider.
            wheelEnabled: false

            onMoved: root.moved(Math.round(value))
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
            // Reserve the same trailing width on both rows so their
            // tracks begin and end at identical horizontal positions.
            Layout.preferredWidth: 36
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
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
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
        target: null
        enabled: root.enabled && !slider.pressed
        orientation: Qt.Vertical
        acceptedButtons: Qt.NoButton
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real remainder: 0
        onWheel: function (wheel) {
            const delta = wheel.angleDelta.y;
            if (!delta)
                return;
            if (remainder * delta < 0)
                remainder = 0;
            remainder += delta;
            const oldValue = slider.value;
            while (remainder >= 120) {
                remainder -= 120;
                slider.increase();
            }
            while (remainder <= -120) {
                remainder += 120;
                slider.decrease();
            }
            if (oldValue !== slider.value)
                slider.moved();
        }
    }
}
