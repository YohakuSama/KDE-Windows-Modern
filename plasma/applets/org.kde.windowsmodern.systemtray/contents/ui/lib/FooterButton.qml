import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import "../components" as Components

Item {
    id: root

    property string iconSource: ""
    property string tooltipText: ""

    property int buttonSize: 20
    readonly property int hitSize: Math.max(buttonSize, Math.round(buttonSize * 2))

    signal clicked
    signal rightClicked

    implicitWidth: Math.max(hitSize, glyph.nativeSource.length > 0 ? 0
        : Math.min(120, missingGlyphLabel.implicitWidth + 8))
    implicitHeight: hitSize
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: root.tooltipText
    Accessible.onPressAction: root.clicked()

    function resolveIcon(role) { return glyph.resolveRole(role); }
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat) root.clicked(); }
    Keys.onEnterPressed: event => { if (!event.isAutoRepeat) root.clicked(); }
    Keys.onSpacePressed: event => { if (!event.isAutoRepeat) root.clicked(); }

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
            Kirigami.Theme.textColor.b, mouseArea.containsPress ? 0.10
                : mouseArea.containsMouse || root.activeFocus ? 0.06 : 0)
    }

    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        mainText: root.tooltipText
        subText: ""
        textFormat: Text.PlainText
    }

    Components.NativeGlyph {
        id: glyph
        width: root.buttonSize; height: root.buttonSize
        anchors.centerIn: parent
        roleName: root.iconSource
    }
    // Keep the action visible and usable when the owner has not imported
    // the original resource. Never silently fall through to a KDE glyph.
    PlasmaComponents3.Label {
        id: missingGlyphLabel
        anchors.centerIn: parent
        width: Math.max(0, parent.width - 8)
        visible: glyph.nativeSource.length === 0
        text: root.tooltipText
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        textFormat: Text.PlainText
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton) {
                root.rightClicked();
            } else {
                root.clicked();
            }
        }
    }
}
