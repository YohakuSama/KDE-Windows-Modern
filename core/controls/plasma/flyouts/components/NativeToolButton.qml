// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.plasma.components as PlasmaComponents3

PlasmaComponents3.ToolButton {
    id: control
    property string nativeRole: ""
    readonly property string nativeIcon: paint.nativeSource
    icon.name: ""
    icon.source: nativeIcon
    display: nativeIcon.length > 0 ? PlasmaComponents3.AbstractButton.IconOnly
        : PlasmaComponents3.AbstractButton.TextOnly
    contentItem: NativeButtonContent {
        id: paint
        button: control
        roleName: control.nativeRole
    }
}
