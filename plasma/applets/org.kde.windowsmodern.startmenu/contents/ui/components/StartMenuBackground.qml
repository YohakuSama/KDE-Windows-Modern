// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.kirigami as Kirigami
import "../code/theme.js" as Theme

Kirigami.ShadowedRectangle {
    readonly property bool dark: Theme.isDark(Kirigami.Theme.backgroundColor)
    radius: Theme.menuRadius
    color: Theme.menuSurface(Kirigami.Theme.backgroundColor)
    border.width: 1
    border.color: Theme.menuBorder(Kirigami.Theme.backgroundColor)
    shadow.size: 12
    shadow.yOffset: 3
    shadow.color: Qt.rgba(0, 0, 0, dark ? 0.32 : 0.18)
}
