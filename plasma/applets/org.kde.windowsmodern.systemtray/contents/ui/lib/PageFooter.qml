// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../js/colorType.js" as ColorType

// The page is the sole owner of its footer. Keep the old shell divider
// and four logical pixels of separation, outside the scroll viewport.
Rectangle {
    id: footer
    objectName: "wmDetailPageFooter"
    property Component sourceComponent: null
    readonly property alias item: loader.item

    color: "transparent"
    visible: loader.item !== null
    implicitHeight: loader.item ? loader.item.implicitHeight + 4 : 0
    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    Layout.minimumHeight: 0
    Layout.maximumHeight: implicitHeight
    clip: true

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        height: 1
        color: ColorType.divider(ColorType.isDark(Kirigami.Theme.backgroundColor))
    }

    Loader {
        id: loader
        anchors.fill: parent
        anchors.topMargin: 4
        active: footer.sourceComponent !== null
        sourceComponent: footer.sourceComponent
    }
}
