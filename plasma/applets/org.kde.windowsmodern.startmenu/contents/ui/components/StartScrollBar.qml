// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

PlasmaComponents3.ScrollBar {
    id: bar
    policy: PlasmaComponents3.ScrollBar.AsNeeded
    width: 16
    padding: 4
    hoverEnabled: true
    minimumSize: height > 0 ? Math.min(1, 32 / height) : 0
    contentItem: Rectangle {
        implicitWidth: 8
        radius: width / 2
        color: Kirigami.Theme.textColor
        opacity: bar.pressed ? 0.72 : bar.hovered ? 0.55 : 0.34
    }
}
