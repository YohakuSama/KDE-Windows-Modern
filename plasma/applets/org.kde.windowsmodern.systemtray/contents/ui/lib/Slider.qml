import QtQuick
import QtQuick.Controls
import QtCore
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
    property string detailsFallbackIconSource: ""
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
    implicitWidth: 180
    LayoutMirroring.childrenInherit: true
    readonly property bool mirroredRow: LayoutMirroring.enabled
    readonly property int leadingGap: 8
    readonly property int trailingGap: 2
    readonly property int detailsWidth: 36
    readonly property int leadingWidth: iconSize + leadingGap
    readonly property int trailingWidth: showArrow ? detailsWidth + trailingGap : 0
    readonly property url detailsAsset: detailsIconSource.length > 0
        ? StandardPaths.locate(StandardPaths.GenericDataLocation,
            "icons/windows-modern/actions/" + detailsIconSource + ".svg", StandardPaths.LocateFile)
        : ""

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

    Kirigami.Icon {
        objectName: "wmSliderLeadingIcon"
        x: root.mirroredRow ? root.width - width : 0
        anchors.verticalCenter: parent.verticalCenter
        width: root.iconSize
        height: width
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
        x: root.mirroredRow ? root.trailingWidth : root.leadingWidth
        width: Math.max(0, root.width - root.leadingWidth - root.trailingWidth)
        height: root.height
        anchors.verticalCenter: parent.verticalCenter
        from: root.from
        to: root.to
        value: root.value
        stepSize: root.stepSize
        Accessible.name: root.sliderAccessibleName
        // Keep a single wheel path; mouse, touch and keyboard are native.
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
        objectName: "wmSliderDetails"
        visible: root.showArrow
        x: root.mirroredRow ? 0 : root.width - width
        anchors.verticalCenter: parent.verticalCenter
        width: root.detailsWidth
        height: Math.min(root.height, 32)
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

        Kirigami.Icon {
            objectName: "wmSliderDetailsGlyph"
            visible: root.detailsIconSource.length > 0
            x: root.mirroredRow ? 14 : 0
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: width
            source: String(root.detailsAsset).length > 0 ? root.detailsAsset
                : root.detailsFallbackIconSource.length > 0 ? root.detailsFallbackIconSource : root.detailsIconSource
            roundToIconSize: false
            isMask: true
            color: Kirigami.Theme.textColor
        }

        Kirigami.Icon {
            objectName: "wmSliderDetailsChevron"
            x: root.mirroredRow ? 2 : parent.width - width - 2
            anchors.verticalCenter: parent.verticalCenter
            width: 12
            height: width
            source: root.mirroredRow ? "go-previous-symbolic" : "go-next-symbolic"
            roundToIconSize: false
            isMask: true
            color: Kirigami.Theme.textColor
        }

        MouseArea {
            id: detailsMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.arrowClicked()
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
