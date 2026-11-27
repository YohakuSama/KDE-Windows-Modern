/*
 * SPDX-FileCopyrightText: 2016 Marco Martin <mart@kde.org>
 * SPDX-FileCopyrightText: 2020 Noah Davis <noahadvs@gmail.com>
 * SPDX-FileCopyrightText: 2026 Windows Modern contributors
 * SPDX-License-Identifier: LGPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import org.kde.ksvg as KSvg
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

// Adapt Plasma ButtonContent's layout and focus roles, explicitly masking
// the private monochrome source instead of relying on icon-theme lookup.
RowLayout {
    id: content
    required property var button
    property string roleName: ""
    readonly property string nativeSource: glyph.nativeSource
    readonly property string labelText: button.Kirigami.MnemonicData.richTextLabel
    readonly property bool usingFocusBackground: !button.flat && buttonSvg.hasElement("hint-focus-highlighted-background")
        && button.visualFocus && !(button.pressed || button.checked)
    readonly property int defaultIconSize: button.flat ? Kirigami.Units.iconSizes.smallMedium : Kirigami.Units.iconSizes.small
    readonly property bool iconShown: nativeSource.length > 0 && button.display !== T.Button.TextOnly
    readonly property bool labelShown: labelText.length > 0 && button.display !== T.Button.IconOnly
    spacing: button.spacing
    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignCenter
        columns: content.button.display === T.Button.TextBesideIcon ? 2 : 1
        rowSpacing: content.button.spacing
        columnSpacing: rowSpacing
        NativeGlyph {
            id: glyph
            objectName: "wmNativeButtonGlyph"
            Layout.alignment: Qt.AlignCenter
            Layout.fillWidth: content.button.display !== T.Button.TextBesideIcon || !content.labelShown
            Layout.fillHeight: true
            Layout.minimumWidth: Math.min(content.width, content.height, implicitWidth)
            Layout.minimumHeight: Math.min(content.width, content.height, implicitHeight)
            Layout.maximumWidth: content.button.icon.width > 0 ? content.button.icon.width : Number.POSITIVE_INFINITY
            Layout.maximumHeight: content.button.icon.height > 0 ? content.button.icon.height : Number.POSITIVE_INFINITY
            implicitWidth: content.button.icon.width > 0 ? content.button.icon.width : content.defaultIconSize
            implicitHeight: content.button.icon.height > 0 ? content.button.icon.height : content.defaultIconSize
            visible: content.iconShown
            roleName: content.roleName
            foreground: content.button.icon.color.a > 0 ? content.button.icon.color
                : content.usingFocusBackground ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
        }
        PlasmaComponents3.Label {
            visible: content.labelShown
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: content.labelText
            font: content.button.font
            color: content.usingFocusBackground ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
            horizontalAlignment: content.button.display !== T.Button.TextUnderIcon && content.iconShown
                ? Text.AlignLeft : Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }
    NativeGlyph {
        visible: content.button.Accessible.role === Accessible.ButtonMenu && content.labelShown && nativeSource.length > 0
        Layout.preferredWidth: Kirigami.Units.iconSizes.small
        Layout.preferredHeight: Layout.preferredWidth
        Layout.alignment: Qt.AlignCenter
        roleName: "go-down-symbolic"
    }
    KSvg.Svg {
        id: buttonSvg
        imagePath: "widgets/button"
    }
}
