// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../js/colorType.js" as ColorType

QQC2.Switch {
    id: control
    readonly property bool dark: ColorType.isDark(Kirigami.Theme.backgroundColor)
    property color shellAccent: Kirigami.Theme.highlightColor
    readonly property color accent: ColorType.accentForSurface(shellAccent,
        Qt.color(ColorType.cardFill(dark, false)))
    implicitWidth: 44
    implicitHeight: 32
    padding: 0
    hoverEnabled: true
    background: Rectangle {
        radius: 4
        color: "transparent"
        border.width: control.activeFocus ? 1 : 0
        border.color: control.accent
    }
    contentItem: Item {}
    indicator: Rectangle {
        objectName: "wmDetailSwitchTrack"
        x: (control.width - width) / 2
        y: (control.height - height) / 2
        width: 40
        height: 20
        radius: 10
        color: control.checked
            ? ColorType.accentStateBrush(control.dark, control.accent, control.enabled, control.hovered, control.down)
            : ColorType.switchOffFill(control.dark, control.enabled, control.hovered, control.down)
        border.width: control.checked ? 0 : 1
        border.color: ColorType.switchOffStroke(control.dark, control.enabled)
        Rectangle {
            id: knob
            objectName: "wmDetailSwitchKnob"
            // WinUI ToggleSwitch common states: Normal/Disabled 12x12,
            // PointerOver 14x14, Pressed 17x14. Press extends inward.
            readonly property bool engaged: control.enabled && control.down
            readonly property bool enlarged: control.enabled && (control.hovered || control.down)
            readonly property int stateDuration: Kirigami.Units.shortDuration <= 0 ? 0
                : control.enabled ? 83 : 250
            property real sidePosition: control.visualPosition
            width: engaged ? 17 : enlarged ? 14 : 12
            height: enlarged ? 14 : 12
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            // Animate side changes independently of width; resizing cannot
            // restart a position animation on every frame.
            x: (parent.width / 2 - width) / 2 + sidePosition * parent.width / 2
                + (engaged ? (1 - 2 * sidePosition) * 1.5 : 0)
            color: ColorType.switchKnobFill(control.dark, control.checked, control.enabled, control.accent)
            Behavior on sidePosition {
                // During a real drag, the knob follows the native switch's
                // visualPosition immediately, including mirrored layouts.
                enabled: !control.pressed
                NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutQuad }
            }
            Behavior on width {
                NumberAnimation {
                    duration: knob.stateDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0, 0, 0, 1, 1, 1]
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: knob.stateDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0, 0, 0, 1, 1, 1]
                }
            }
        }
    }
}
