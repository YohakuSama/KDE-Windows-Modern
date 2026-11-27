import QtQuick
import QtQuick.Controls
import QtQuick.Templates as T
import QtCore
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../js/colorType.js" as ColorType
import "../js/trayMetrics.js" as TrayMetrics
import "../js/controlMetrics.js" as ControlMetrics
import "../components" as Components

Item {
    id: root

    property string iconSource
    property int from: 0
    property int to: 100
    property int value: 0
    property int stepSize: 1
    property int iconSize: TrayMetrics.quickSliderGlyphSize
    readonly property bool pressed: slider.pressed
    property string sliderAccessibleName: ""
    // Home rows use balanced side slots. Qt applies output DPI once;
    // controlScale is only the user's optional Quick Settings UI scale.
    property real controlScale: 1
    readonly property int trackGap: reserveDetailsSpace ? 0 : Math.round(8 * controlScale)
    readonly property int thumbExtent: Math.max(12, Math.round(18 * controlScale))
    readonly property int trackThickness: Math.max(2, Math.round(TrayMetrics.sliderTrackHeight * controlScale))
    readonly property int alignedSideWidth: Math.max(iconSize, Math.round(27 * controlScale))
    readonly property int leadingWidth: reserveDetailsSpace ? alignedSideWidth : iconSize
    readonly property int detailsWidth: reserveDetailsSpace ? alignedSideWidth
        : Math.round((soundOutputDetails || detailsIconSource.length > 0 ? 32 : 24) * controlScale)
    property bool showArrow: false
    // Home rows reserve the same output slot so both tracks end at
    // the same x coordinate. Other detail-page sliders stay full-width.
    property bool reserveDetailsSpace: false
    property bool soundOutputDetails: false
    // Dedicated sound-output role (F4C3), distinct from speaker volume.
    // Use only the private Windows import; the chevron remains if absent.
    readonly property url nativeSoundOutputAsset: soundOutputDetails
        ? StandardPaths.locate(StandardPaths.GenericDataLocation,
            "windows-modern/native-assets/icons/actions/wm-sound-output-symbolic.svg", StandardPaths.LocateFile)
        : ""
    property string detailsIconSource: ""
    property string detailsAccessibleName: ""
    property bool iconClickable: false
    property string iconAccessibleName: ""
    // Keep the details action usable even when there is no audio output.
    property bool trackEnabled: true
    readonly property bool dark: ColorType.isDark(Kirigami.Theme.backgroundColor)
    property color shellAccent: Kirigami.Theme.highlightColor
    readonly property color accent: ColorType.accentForSurface(shellAccent, Qt.color(ColorType.cardFill(dark, false)))

    signal moved(int value)
    signal released
    signal arrowClicked
    signal iconClicked
    signal rightClicked
    signal middleClicked

    implicitHeight: TrayMetrics.quickSliderRowHeight

    // Keep fractional wheel detents per control and per input representation.
    // Pixel-only gestures use a provisional logical-pixel step, not DPI.
    property real wheelRemainder: 0
    property bool wheelUsesPixels: false
    readonly property int wheelPixelThreshold: 40

    function resetWheelInput() {
        wheelRemainder = 0;
        wheelUsesPixels = false;
    }

    function handleWheel(angleX, angleY, pixelX, pixelY) {
        if (!visible || !trackEnabled || slider.pressed) return;
        const hasPixels = pixelX !== 0 || pixelY !== 0;
        const dx = hasPixels ? pixelX : angleX;
        const dy = hasPixels ? pixelY : angleY;
        if (dy === 0 || Math.abs(dx) > Math.abs(dy)) return;

        if (wheelUsesPixels !== hasPixels || wheelRemainder * dy < 0)
            resetWheelInput();
        wheelUsesPixels = hasPixels;
        const threshold = hasPixels ? wheelPixelThreshold : 120;
        wheelRemainder += dy;
        const steps = Math.trunc(wheelRemainder / threshold);
        wheelRemainder %= threshold;
        const before = slider.value;
        // Native increase/decrease preserve the slider's value semantics.
        // Stop at the bound and notify the backend only once per event.
        for (let remaining = Math.abs(steps); remaining > 0; --remaining) {
            const previous = slider.value;
            if (steps > 0) slider.increase();
            else slider.decrease();
            if (slider.value === previous) break;
        }
        if (slider.value !== before) slider.moved();
    }

    onTrackEnabledChanged: resetWheelInput()
    onVisibleChanged: if (!visible) resetWheelInput()
    onPressedChanged: if (pressed) resetWheelInput()
    onFromChanged: resetWheelInput()
    onToChanged: resetWheelInput()
    onStepSizeChanged: resetWheelInput()

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
        columnSpacing: root.trackGap

        Item {
            objectName: "wmFluentSliderLeadingSlot"
            visible: root.iconSource.length > 0
            activeFocusOnTab: root.iconClickable
            Accessible.ignored: !root.iconClickable
            Accessible.role: Accessible.Button
            Accessible.name: root.iconAccessibleName || root.sliderAccessibleName
            Accessible.onPressAction: if (root.iconClickable) root.iconClicked()
            Keys.onReturnPressed: event => {
                if (root.iconClickable && !event.isAutoRepeat) root.iconClicked();
            }
            Keys.onEnterPressed: event => {
                if (root.iconClickable && !event.isAutoRepeat) root.iconClicked();
            }
            Keys.onSpacePressed: event => {
                if (root.iconClickable && !event.isAutoRepeat) root.iconClicked();
            }

            Rectangle {
                anchors.fill: parent
                radius: ControlMetrics.controlCornerRadius
                color: "transparent"
                border.width: parent.activeFocus && root.iconClickable ? 1 : 0
                border.color: root.accent
            }
            Layout.minimumWidth: root.leadingWidth
            Layout.preferredWidth: root.leadingWidth
            Layout.maximumWidth: root.leadingWidth
            Layout.preferredHeight: Math.max(root.iconSize, Math.round(32 * root.controlScale))
            Layout.alignment: Qt.AlignVCenter
            Components.NativeGlyph {
                objectName: "wmFluentSliderLeadingGlyph"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: root.iconSize
                height: width
                roleName: root.iconSource
                roundToIconSize: false
                isMask: true
                color: Kirigami.Theme.textColor
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.iconClickable
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.iconClicked()
            }
        }

        // Use the native Qt Quick slider template directly. Its input
        // rectangle must cover the whole row height, not just the 4px groove.
        T.Slider {
            id: slider
            objectName: "wmFluentSliderTrack"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: root.implicitHeight
            implicitHeight: root.implicitHeight
            implicitWidth: 160
            from: root.from
            to: root.to
            stepSize: root.stepSize
            live: true
            snapMode: T.Slider.SnapAlways
            focusPolicy: Qt.StrongFocus
            wheelEnabled: false
            enabled: root.trackEnabled
            hoverEnabled: true
            readonly property color valueBrush: ColorType.accentStateBrush(root.dark, root.accent,
                enabled, hovered, pressed)
            leftPadding: 0
            rightPadding: 0
            Accessible.name: root.sliderAccessibleName || root.iconSource

            // Asynchronous DBus/PipeWire feedback must not drag the thumb
            // backwards while the user owns the pointer.
            Binding {
                target: slider
                property: "value"
                value: root.value
                when: !slider.pressed
                restoreMode: Binding.RestoreNone
            }

            // Fluent track and thumb; the native control retains keyboard,
            // mouse, accessibility, wheel and value semantics.
            background: Item {
                objectName: "wmFluentSliderGroove"
                x: slider.leftPadding + root.thumbExtent / 2
                y: (slider.height - height) / 2
                width: Math.max(0, slider.availableWidth - root.thumbExtent)
                height: root.trackThickness
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: ColorType.sliderTrackBrush(root.dark, slider.enabled)
                }
                Rectangle {
                    width: parent.width * slider.position
                    height: parent.height
                    x: slider.mirrored ? parent.width - width : 0
                    radius: height / 2
                    color: slider.valueBrush
                }
            }

            handle: Rectangle {
                id: thumb
                objectName: "wmFluentSliderThumb"
                x: slider.leftPadding + slider.visualPosition * Math.max(0, slider.availableWidth - width)
                y: (slider.height - height) / 2
                width: root.thumbExtent
                height: root.thumbExtent
                radius: width / 2
                color: ColorType.sliderOuterThumbBrush(root.dark)
                border.width: 1
                border.color: root.dark ? "#454545" : "#D6D6D6"
                HoverHandler {
                    id: thumbHover
                    enabled: slider.enabled
                }
                Rectangle {
                    objectName: "wmFluentSliderInnerThumb"
                    anchors.centerIn: parent
                    // WinUI SliderInnerThumb state design: 12 normal,
                    // 14 hovered/disabled, 10 pressed logical pixels.
                    // Clamp to the existing outer handle on narrow scales.
                    readonly property int stateExtent: !slider.enabled ? 14
                        : slider.pressed ? 10 : thumbHover.hovered ? 14 : 12
                    width: Math.max(0, Math.min(thumb.width - 2,
                        Math.max(6, Math.round(stateExtent * root.controlScale))))
                    height: width
                    radius: width / 2
                    color: slider.valueBrush
                }
            }

            onMoved: root.moved(value)
            onPressedChanged: {
                if (!slider.pressed)
                    root.released();
            }


        }

        Item {
            id: detailsButton
            objectName: "wmFluentSliderDetailsSlot"
            visible: root.showArrow || root.reserveDetailsSpace
            enabled: root.showArrow
            opacity: root.showArrow ? 1 : 0
            Layout.minimumWidth: root.detailsWidth
            Layout.preferredWidth: root.detailsWidth
            Layout.maximumWidth: root.detailsWidth
            Layout.preferredHeight: Math.round(32 * root.controlScale)
            Layout.alignment: Qt.AlignVCenter
            activeFocusOnTab: root.showArrow
            Accessible.ignored: !root.showArrow
            Accessible.role: Accessible.Button
            Accessible.name: root.detailsAccessibleName || i18nd("plasma_applet_org.kde.windowsmodern.systemtray", "More")
            Accessible.onPressAction: root.arrowClicked()
            Keys.onReturnPressed: event => { if (!event.isAutoRepeat) root.arrowClicked(); }
            Keys.onEnterPressed: event => { if (!event.isAutoRepeat) root.arrowClicked(); }
            Keys.onSpacePressed: event => { if (!event.isAutoRepeat) root.arrowClicked(); }

            Rectangle {
                anchors.fill: parent
                radius: ControlMetrics.controlCornerRadius
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                    Kirigami.Theme.textColor.b, detailsMouse.containsPress ? 0.10
                        : detailsMouse.containsMouse || detailsButton.activeFocus ? 0.06 : 0)
            }

            Row {
                anchors.centerIn: parent
                spacing: Math.round(2 * root.controlScale)
                readonly property int glyphExtent: Math.max(8, Math.round((root.reserveDetailsSpace ? 16 : 18) * root.controlScale))
                Components.NativeGlyph {
                    visible: !root.soundOutputDetails && nativeSource.length > 0
                    width: parent.glyphExtent
                    height: parent.glyphExtent
                    roleName: root.detailsIconSource
                }
                Kirigami.Icon {
                    objectName: "wmNativeSoundOutputGlyph"
                    visible: root.soundOutputDetails && String(root.nativeSoundOutputAsset).length > 0
                    width: parent.glyphExtent
                    height: parent.glyphExtent
                    source: root.nativeSoundOutputAsset
                    fallback: ""
                    roundToIconSize: false
                    isMask: true
                    color: Kirigami.Theme.textColor
                }
                Components.NativeGlyph {
                    objectName: "wmFluentSliderDetailsChevron"
                    width: Math.max(6, Math.round((root.reserveDetailsSpace ? 8 : 12) * root.controlScale))
                    height: parent.glyphExtent
                    roleName: slider.mirrored ? "go-previous-symbolic" : "go-next-symbolic"
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
        enabled: root.trackEnabled && !slider.pressed
        target: null
        orientation: Qt.Vertical
        acceptedButtons: Qt.NoButton
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        activeTimeout: 0.3
        onActiveChanged: if (!active) root.resetWheelInput()
        onWheel: wheel => root.handleWheel(wheel.angleDelta.x, wheel.angleDelta.y,
                                          wheel.pixelDelta.x, wheel.pixelDelta.y)
    }
}
