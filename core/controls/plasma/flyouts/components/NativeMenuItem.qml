/*
 * SPDX-FileCopyrightText: 2016 Marco Martin <mart@kde.org>
 * SPDX-FileCopyrightText: 2026 Windows Modern contributors
 * SPDX-License-Identifier: LGPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

// Adapt Plasma MenuItem's check/icon/text alignment. The original
// indicator, background, arrow and input semantics remain inherited.
PlasmaComponents3.MenuItem {
    id: control
    property string nativeRole: ""
    readonly property string nativeIcon: glyph.nativeSource
    icon.name: ""
    icon.source: nativeIcon
    contentItem: RowLayout {
        Item {
            Layout.preferredWidth: (control.ListView.view && control.ListView.view.hasCheckables)
                || control.checkable ? control.indicator.width : Kirigami.Units.smallSpacing
        }
        Item {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: Math.max(label.height, Kirigami.Units.iconSizes.small)
            Layout.preferredWidth: Layout.preferredHeight
            visible: !!(control.ListView.view && control.ListView.view.hasIcons) || control.nativeIcon.length > 0
            NativeGlyph {
                id: glyph
                objectName: "wmNativeMenuGlyph"
                anchors.fill: parent
                roleName: control.nativeRole
            }
        }
        PlasmaComponents3.Label {
            id: label
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            text: control.Kirigami.MnemonicData.richTextLabel
            font: control.font
            elide: Text.ElideRight
            visible: control.text.length > 0
            horizontalAlignment: control.mirrored ? Text.AlignRight : Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
        }
    }
}
