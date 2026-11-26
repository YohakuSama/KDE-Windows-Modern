// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmaComponents.Button {
    id: control
    property bool quiet: false
    property bool attentionActive: false
    property string nativeIconName: ""
    readonly property string nativeIconSource: {
        if (!/^[A-Za-z0-9_.+-]+$/.test(nativeIconName)) return "";
        const names = nativeIconName.endsWith("-symbolic")
            ? [nativeIconName, nativeIconName.slice(0, -9)]
            : [nativeIconName + "-symbolic", nativeIconName];
        for (const name of names) {
            for (const context of ["actions", "status"]) {
                const file = StandardPaths.locate(StandardPaths.GenericDataLocation,
                    "windows-modern/native-assets/icons/" + context + "/" + name + ".svg",
                    StandardPaths.LocateFile);
                if (String(file).length > 0) return String(file);
            }
        }
        return "";
    }
    icon.name: ""
    focusPolicy: Qt.TabFocus
    implicitHeight: 28
    padding: 6
    leftPadding: 8
    rightPadding: 8
    icon.width: 14
    icon.height: 14
    font.pixelSize: 12
    Win11Palette { id: colors }
    readonly property bool selected: checked || attentionActive
    // Pointer activation must not leave the keyboard focus outline behind.
    readonly property bool keyboardFocus: activeFocus && visualFocus
    icon.color: selected ? colors.accentText : colors.text
    palette.buttonText: selected ? colors.accentText : colors.text
    // The stock ButtonContent uses a theme-aware Kirigami.Icon but does not
    // force a mask for file URLs. Explicitly tint the private SVG and reserve
    // the same logical icon slot even when a resource is missing.
    contentItem: GridLayout {
        id: content
        readonly property bool iconShown: control.nativeIconName.length > 0
            && control.display !== PlasmaComponents.AbstractButton.TextOnly
        readonly property bool labelShown: control.text.length > 0
            && control.display !== PlasmaComponents.AbstractButton.IconOnly
        columns: control.display === PlasmaComponents.AbstractButton.TextBesideIcon ? 2 : 1
        rowSpacing: control.spacing
        columnSpacing: control.spacing

        Item {
            visible: content.iconShown
            Layout.alignment: Qt.AlignCenter
            Layout.fillWidth: control.display !== PlasmaComponents.AbstractButton.TextBesideIcon || !content.labelShown
            Layout.fillHeight: true
            Layout.minimumWidth: Math.min(content.width, content.height, implicitWidth)
            Layout.minimumHeight: Math.min(content.width, content.height, implicitHeight)
            Layout.maximumWidth: control.icon.width
            Layout.maximumHeight: control.icon.height
            implicitWidth: control.icon.width
            implicitHeight: control.icon.height

            Kirigami.Icon {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height)
                height: width
                source: control.nativeIconSource
                fallback: ""
                visible: control.nativeIconSource.length > 0
                isMask: true
                color: control.icon.color
                roundToIconSize: false
                animated: false
            }
        }

        PlasmaComponents.Label {
            visible: content.labelShown
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: control.Kirigami.MnemonicData.richTextLabel
            font: control.font
            color: control.selected ? colors.accentText : colors.text
            horizontalAlignment: control.display === PlasmaComponents.AbstractButton.TextBesideIcon
                && content.iconShown ? Text.AlignLeft : Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    background: Rectangle {
        radius: 4
        color: control.selected ? colors.accent
            : control.down ? colors.pressed
            : control.hovered || control.keyboardFocus ? colors.hover
            : control.quiet ? "transparent" : colors.surface
        border.width: control.quiet && !control.selected && !control.keyboardFocus ? 0 : 1
        border.color: control.keyboardFocus || control.selected ? colors.accent : colors.surfaceBorder
        opacity: control.enabled ? 1 : 0.55
    }
}
