import QtQuick
import org.kde.plasma.private.sessions as Sessions
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: root
    signal clicked

    function activate() {
        sessionManagement.requestLogoutPrompt();
        root.clicked();
    }
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: i18n("Power")
    Accessible.onPressAction: root.activate()
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat) root.activate(); }
    Keys.onEnterPressed: event => { if (!event.isAutoRepeat) root.activate(); }
    Keys.onSpacePressed: event => { if (!event.isAutoRepeat) root.activate(); }

    Sessions.SessionManagement {
        id: sessionManagement
    }

    NativeGlyph {
        id: powerGlyph
        width: 20; height: 20
        anchors.centerIn: parent
        roleName: "system-shutdown"
    }
    PlasmaComponents3.Label {
        anchors.centerIn: parent
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        visible: powerGlyph.nativeSource.length === 0
        text: i18n("Power")
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activate()
    }
}
