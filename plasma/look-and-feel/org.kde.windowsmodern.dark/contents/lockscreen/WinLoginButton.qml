/*
 * SPDX-FileCopyrightText: 2026 Jeysef
 *
 * SPDX-License-Identifier: LGPL-2.0-or-later
 */

import QtQuick
import QtQuick.Controls 2.15 as QQC2
import "lockMetrics.js" as LockMetrics

QQC2.ToolButton {
    id: root

    property bool layoutMirrored: false

    width: Math.max(WinStyle.loginButtonSize, LockMetrics.submitButtonMinWidth)
    height: Math.max(WinStyle.loginButtonSize, LockMetrics.submitButtonMinHeight)

    text: i18nd("plasma_shell_org.kde.windowsmodern.lockscreen", "Sign in")
    Accessible.name: text
    display: QQC2.AbstractButton.IconOnly
    icon.name: root.layoutMirrored ? "go-previous" : "go-next"
    icon.color: root.hovered ? WinStyle.accentColor : WinStyle.mutedForegroundColor

    // Keep native ToolButton input and focus; only its visual content
    // resolves the verified mapped artwork rather than the icon theme.
    contentItem: Item {
        NativeGlyph {
            id: arrow
            anchors.centerIn: parent
            width: Math.max(0, Math.min(root.icon.width || 16, root.icon.height || 16,
                                        parent.width, parent.height))
            height: width
            roleName: root.icon.name
            foreground: root.icon.color
        }
        Text {
            anchors.fill: parent
            visible: arrow.nativeSource.length === 0
            text: root.text
            font: root.font
            color: root.icon.color
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    background: Rectangle {
        color: root.hovered ? WinStyle.hoverBackground : "transparent"
        radius: LockMetrics.fieldButtonRadius
    }

}
