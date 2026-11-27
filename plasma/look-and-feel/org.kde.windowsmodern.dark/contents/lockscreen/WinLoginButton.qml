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

    icon.name: root.layoutMirrored ? "go-previous" : "go-next"
    icon.color: root.hovered ? WinStyle.accentColor : WinStyle.mutedForegroundColor

    background: Rectangle {
        color: root.hovered ? WinStyle.hoverBackground : "transparent"
        radius: LockMetrics.fieldButtonRadius
    }

}
