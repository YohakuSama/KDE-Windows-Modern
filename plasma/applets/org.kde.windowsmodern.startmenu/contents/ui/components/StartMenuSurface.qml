// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.kirigami as Kirigami
import "../code/theme.js" as Theme

// The shared in-dialog flyout surface. Use native Kirigami's shadow
// primitive rather than drawing any new Windows icon or bitmap artwork.
FocusScope {
    id: surface
    readonly property int frameRadius: Theme.menuRadius
    readonly property int contentInset: Theme.menuOuterInset
    readonly property bool dark: (0.299 * Kirigami.Theme.backgroundColor.r
        + 0.587 * Kirigami.Theme.backgroundColor.g
        + 0.114 * Kirigami.Theme.backgroundColor.b) < 0.5

    Kirigami.ShadowedRectangle {
        anchors.fill: parent
        z: -2
        radius: surface.frameRadius
        color: Qt.tint(Kirigami.Theme.backgroundColor, surface.dark
            ? Qt.rgba(1, 1, 1, 0.035) : Qt.rgba(1, 1, 1, 0.60))
        border.width: 1
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
            Kirigami.Theme.textColor.b, Theme.menuFrameOpacity)
        shadow.size: 12
        shadow.yOffset: 3
        shadow.color: Qt.rgba(0, 0, 0, surface.dark ? 0.32 : 0.18)
    }

    // Clicking the empty inset of a menu is not an outside click.
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: surface.forceActiveFocus(Qt.MouseFocusReason)
    }
}
