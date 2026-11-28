import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../js/colorType.js" as ColorType
import "../js/controlMetrics.js" as ControlMetrics

Item {
    id: root

    property string text
    property string kcm
    readonly property bool dark: ColorType.isDark(Kirigami.Theme.backgroundColor)

    signal clicked

    implicitHeight: Math.max(42, Math.ceil(linkLabel.implicitHeight) + 22)
    // Intrinsic width is independent of the host Loader/ColumnLayout.
    implicitWidth: 200
    Layout.fillWidth: true
    LayoutMirroring.childrenInherit: true
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: root.text
    Accessible.onPressAction: root.clicked()
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    Rectangle {
        objectName: "wmMoreSettingsLinkBackground"
        anchors.fill: parent
        anchors.margins: 4
        radius: ControlMetrics.controlCornerRadius
        color: ColorType.rowFill(root.dark, false, ma.containsMouse || root.activeFocus, ma.containsPress)
        border.width: root.activeFocus ? 1 : 0
        border.color: Kirigami.Theme.textColor
    }

    PlasmaComponents3.Label {
        id: linkLabel
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: root.text
        textFormat: Text.PlainText
        color: Kirigami.Theme.textColor
        opacity: 1
        font.pixelSize: Math.max(12, Kirigami.Theme.smallFont.pixelSize)
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
