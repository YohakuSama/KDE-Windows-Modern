import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami
import "../lib" as Lib
import "../js/colorType.js" as ColorType

Lib.Tile {
    id: tile

    readonly property bool darkMode: ColorType.isDark(Kirigami.Theme.backgroundColor)

    label: qsTr("Dark Mode")
    iconSource: darkMode ? "weather-clear-night-symbolic" : "weather-clear-symbolic"
    active: darkMode

    function switchTheme() {
        const target = darkMode ? Plasmoid.configuration.lightTheme : Plasmoid.configuration.darkTheme;
        if (/^[A-Za-z0-9_.-]+$/.test(target))
            colorschemeExec.exec("plasma-apply-lookandfeel --apply " + target);
    }

    // Reflect the actual applied palette, never a guessed toggle state.
    onClicked: switchTheme()
    onMiddleClicked: switchTheme()

    tooltipText: darkMode ? qsTr("Switch to light mode") : qsTr("Switch to dark mode")

    Plasma5Support.DataSource {
        id: colorschemeExec
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            disconnectSource(sourceName);
        }
        function exec(cmd) {
            connectSource(cmd);
        }
    }
}
