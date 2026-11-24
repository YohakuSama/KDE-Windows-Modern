// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

PlasmaComponents3.ComboBox {
    id: selector
    property int mode: 2
    signal modeRequested(int index)
    readonly property var modeLabels: [i18n("List"), i18n("Grid"), i18n("Category")]
    model: modeLabels
    currentIndex: Math.max(0, Math.min(modeLabels.length - 1, mode))
    displayText: i18n("View: %1", modeLabels[Math.max(0, Math.min(modeLabels.length - 1, mode))])
    Accessible.name: displayText
    leftPadding: 8
    rightPadding: 24
    font.pixelSize: 13
    contentItem: PlasmaComponents3.Label {
        objectName: "wmStartViewLabel"
        text: selector.displayText
        color: Kirigami.Theme.textColor
        font: selector.font
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
        textFormat: Text.PlainText
    }
    background: Rectangle {
        radius: 4
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
            Kirigami.Theme.textColor.b, selector.hovered || selector.activeFocus ? 0.07 : 0)
    }
    onActivated: index => modeRequested(index)
}
