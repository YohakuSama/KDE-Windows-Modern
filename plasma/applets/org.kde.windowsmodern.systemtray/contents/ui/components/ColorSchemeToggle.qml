import QtQuick
import QtCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami
import "../lib" as Lib
import "../js/colorType.js" as ColorType

Lib.Tile {
    id: tile

    readonly property bool darkMode: ColorType.isDark(Kirigami.Theme.backgroundColor)
    readonly property string modeScript: {
        const url = String(StandardPaths.locate(StandardPaths.GenericDataLocation,
            "plasma/look-and-feel/org.kde.windowsmodern.dark/contents/scripts/switch-mode.sh"));
        return url.startsWith("file:///") ? decodeURIComponent(url.slice(7))
            : url.startsWith("/") ? url : "";
    }
    property string pendingCommand: ""

    label: i18n("Dark Mode")
    iconSource: "wm-dark-mode-symbolic"
    active: darkMode
    enabled: modeScript.length > 0 && pendingCommand.length === 0

    function switchTheme() {
        if (!enabled) return;
        // The executable engine runs a shell command. Quote the local path;
        // mode is one of two fixed literals, never an arbitrary package id.
        const script = "'" + modeScript.replace(/'/g, "'\\''") + "'";
        pendingCommand = "bash " + script + (darkMode ? " light" : " dark");
        colorschemeExec.connectSource(pendingCommand);
    }

    // Reflect the actual palette. Do not reapply the whole global theme.
    onClicked: switchTheme()
    onMiddleClicked: switchTheme()
    tooltipText: darkMode ? i18n("Switch to light mode") : i18n("Switch to dark mode")

    Plasma5Support.DataSource {
        id: colorschemeExec
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            if (sourceName !== tile.pendingCommand || data["exit code"] === undefined) return;
            disconnectSource(sourceName);
            tile.pendingCommand = "";
            if (data["exit code"] !== 0)
                console.warn("Windows Modern appearance switch failed:", data["stderr"]);
        }
    }
}
