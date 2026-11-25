// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Keep ComboBox keyboard, selection and accessibility semantics. Explicit
// text metrics and popup visuals avoid the Plasma style's implicitWidth
// recursion when the displayed label differs from the selected model text.
QQC2.ComboBox {
    id: control

    property var choices: []
    property string labelFormat: "%1"
    readonly property int rowHeight: Math.max(fluent.controlHeight, Math.ceil(metrics.height) + 12)
    readonly property real widestLabel: {
        let width = 0;
        for (const label of choices) {
            width = Math.max(width, metrics.advanceWidth(label),
                metrics.advanceWidth(labelFormat.replace("%1", label)));
        }
        return width;
    }

    Win11Palette { id: fluent }
    FontMetrics { id: metrics; font: control.font }

    model: choices
    font: Kirigami.Theme.defaultFont
    displayText: labelFormat.replace("%1", choices[currentIndex] ?? choices[0] ?? "")
    implicitWidth: Math.ceil(widestLabel) + 42
    implicitHeight: Math.max(fluent.controlHeight, Math.ceil(metrics.height) + 12)
    leftPadding: mirrored ? 28 : 10
    rightPadding: mirrored ? 10 : 28
    topPadding: 4
    bottomPadding: 4
    hoverEnabled: true

    contentItem: Text {
        objectName: "wmViewSelectorText"
        text: control.displayText
        font: control.font
        textFormat: Text.PlainText
        color: control.enabled ? fluent.text : fluent.textDisabled
        horizontalAlignment: Text.AlignLeft
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }

    indicator: Kirigami.Icon {
        x: control.mirrored ? 8 : control.width - width - 8
        y: (control.height - height) / 2
        width: 12
        height: 12
        source: "go-down-symbolic"
        isMask: true
        color: fluent.text
        opacity: control.enabled ? 1 : 0.45
        roundToIconSize: false
    }

    background: Rectangle {
        radius: fluent.controlRadius
        color: control.down ? fluent.controlPressed
            : control.hovered || control.visualFocus ? fluent.controlHover : "transparent"
        border.width: control.visualFocus ? 1 : 0
        border.color: fluent.accent
    }

    delegate: QQC2.ItemDelegate {
        id: option
        required property int index
        required property string modelData

        width: ListView.view ? ListView.view.width : control.width - 2 * fluent.menuPadding
        height: control.rowHeight
        text: modelData
        font: control.font
        highlighted: control.highlightedIndex === index
        leftPadding: 12
        rightPadding: 8
        hoverEnabled: true

        contentItem: Text {
            text: option.text
            textFormat: Text.PlainText
            font: option.font
            color: fluent.text
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: fluent.controlRadius
            color: option.down ? fluent.controlPressed
                : option.highlighted || option.hovered || option.index === control.currentIndex
                    ? fluent.controlHover : "transparent"
            Rectangle {
                visible: option.index === control.currentIndex
                width: 3
                height: 16
                radius: 1.5
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: fluent.accent
            }
        }
    }

    popup: QQC2.Popup {
        y: control.height + 4
        width: control.width
        padding: fluent.menuPadding
        implicitHeight: Math.min(control.count, 8) * control.rowHeight + 2 * padding
        contentItem: ListView {
            clip: true
            model: control.delegateModel
            currentIndex: control.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            implicitHeight: contentHeight
        }
        background: Rectangle {
            radius: fluent.menuRadius
            color: fluent.menuBackground
            border.width: 1
            border.color: fluent.menuBorder
        }
    }
}
