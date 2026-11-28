// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQC
import org.kde.plasma.plasma5support as Plasma5Support

import "js/colorType.js" as ColorType
import "js/controlMetrics.js" as ControlMetrics

KCMUtils.SimpleKCM {
    id: colorsPage
    objectName: "wmConfigColorsPage"

    readonly property string modeScript: {
        const url = String(StandardPaths.locate(StandardPaths.GenericDataLocation,
            "plasma/look-and-feel/org.kde.windowsmodern.dark/contents/scripts/switch-mode.sh"));
        return url.startsWith("file:///") ? decodeURIComponent(url.slice(7))
            : url.startsWith("/") ? url : "";
    }
    readonly property bool scriptAvailable: modeScript.length > 0
    readonly property bool busy: pendingCommand.length > 0

    property string pendingCommand: ""
    property bool pendingIsStatus: false
    property string statusError: ""
    property bool activePackage: true
    property string activeMode: ColorType.isDark(Kirigami.Theme.backgroundColor) ? "dark" : "light"
    property string accentSource: "automatic"
    property bool accentPending: false
    property string manualColor: "#0078D4"
    property string activeAccent: "#0078D4"
    property bool nativeOverride: false
    property bool transparencyEnabled: true
    property var activePalette: null
    // Default 6x8 Windows 11 26H2 uxtheme.dll swatch grid before async status arrives.
    property var swatchGrid: [
        ["#FFB900", "#FF8C00", "#F7630C", "#CA5010", "#DA3B01", "#EF6950", "#D13438", "#FF4343"],
        ["#E74856", "#E81123", "#EA005E", "#C30052", "#E3008C", "#BF0077", "#C239B3", "#9A0089"],
        ["#0078D4", "#0063B1", "#8E8CD8", "#6B69D6", "#8764B8", "#744DA9", "#B146C2", "#881798"],
        ["#0099BC", "#2D7D9A", "#00B7C3", "#038387", "#00B294", "#018574", "#00CC6A", "#10893E"],
        ["#7A7574", "#5D5A58", "#68768A", "#515C6B", "#567C73", "#486860", "#498205", "#107C10"],
        ["#767676", "#4C4A48", "#69797E", "#4A5459", "#647C64", "#525E54", "#847545", "#7E735F"]
    ]

    function shellQuote(arg) {
        return "'" + String(arg).split("'").join("'\\''") + "'";
    }

    function normalizeHex(raw) {
        const trimmed = String(raw || "").trim();
        const prefixed = trimmed.startsWith("#") ? trimmed : "#" + trimmed;
        return /^#[0-9A-Fa-f]{6}$/.test(prefixed) ? prefixed.toUpperCase() : "";
    }

    function runScript(args, isStatus) {
        if (!scriptAvailable || busy) return;
        const quoted = ["bash", shellQuote(modeScript)].concat(args.map(shellQuote)).join(" ");
        statusError = "";
        pendingIsStatus = !!isStatus;
        pendingCommand = quoted;
        runner.connectSource(quoted);
    }

    function refreshStatus() {
        if (!scriptAvailable || busy) return;
        runScript(["--status-json"], true);
    }

    function applyAppearanceMode(targetMode) {
        if (targetMode !== "light" && targetMode !== "dark") return;
        if (targetMode === activeMode) return;
        runScript([targetMode], false);
    }

    function applyAutomaticAccent() {
        if (nativeOverride) {
            runScript(["--reset-native-accent", "--automatic-accent"], false);
        } else {
            runScript(["--automatic-accent"], false);
        }
    }

    function applyManualAccent(hexColor) {
        const normalized = normalizeHex(hexColor);
        if (!normalized) return;
        if (nativeOverride) {
            runScript(["--reset-native-accent", "--manual-accent", normalized], false);
        } else {
            runScript(["--manual-accent", normalized], false);
        }
    }

    function applyNativeAccentMode() {
        runScript(["--native-accent"], false);
    }

    Component.onCompleted: refreshStatus()

    Plasma5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            if (sourceName !== colorsPage.pendingCommand || data["exit code"] === undefined)
                return;
            disconnectSource(sourceName);
            const wasStatus = colorsPage.pendingIsStatus;
            const exitCode = Number(data["exit code"]);
            const stdoutText = String(data["stdout"] || "").trim();
            const stderrText = String(data["stderr"] || "").trim();
            colorsPage.pendingCommand = "";
            colorsPage.pendingIsStatus = false;

            if (exitCode !== 0) {
                colorsPage.statusError = stderrText.length > 0 ? stderrText : i18n("Appearance update failed.");
                return;
            }
            if (wasStatus) {
                try {
                    const parsed = JSON.parse(stdoutText);
                    colorsPage.activePackage = parsed.active_package !== false;
                    if (typeof parsed.mode === "string") colorsPage.activeMode = parsed.mode;
                    if (typeof parsed.accent_source === "string") colorsPage.accentSource = parsed.accent_source;
                    colorsPage.accentPending = parsed.pending === true;
                    if (typeof parsed.manual_color === "string") {
                        colorsPage.manualColor = parsed.manual_color.toUpperCase();
                        customHexField.text = colorsPage.manualColor;
                    }
                    if (typeof parsed.active_accent === "string") colorsPage.activeAccent = parsed.active_accent.toUpperCase();
                    colorsPage.nativeOverride = parsed.native_override === true;
                    colorsPage.transparencyEnabled = parsed.transparency_enabled !== false;
                    colorsPage.activePalette = parsed.palette || null;
                    if (Array.isArray(parsed.swatch_grid) && parsed.swatch_grid.length === 6)
                        colorsPage.swatchGrid = parsed.swatch_grid;
                } catch (e) {
                    colorsPage.statusError = i18n("Could not read Windows Modern color status.");
                }
            } else {
                colorsPage.refreshStatus();
            }
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: !colorsPage.scriptAvailable || !colorsPage.activePackage
            type: Kirigami.MessageType.Warning
            text: i18n("Apply the shared Windows Modern global theme first to manage Windows 11 appearance modes and accent ramps.")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: colorsPage.statusError.length > 0
            type: Kirigami.MessageType.Error
            text: colorsPage.statusError
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: colorsPage.nativeOverride
            type: Kirigami.MessageType.Information
            text: i18n("KDE System Settings Colors currently overrides the color scheme accent. Selecting Automatic or a Windows color below will switch KDE Colors back to 'From current color scheme'.")
            actions: [
                Kirigami.Action {
                    text: i18n("Use Windows accent ramp")
                    enabled: !colorsPage.busy && colorsPage.scriptAvailable
                    onTriggered: colorsPage.runScript(["--reset-native-accent"], false)
                },
                Kirigami.Action {
                    text: i18n("Open KDE Colors…")
                    onTriggered: KCMUtils.KCMLauncher.openSystemSettings("kcm_colors")
                }
            ]
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true
            enabled: colorsPage.scriptAvailable && colorsPage.activePackage && !colorsPage.busy

            QQC2.ComboBox {
                id: modeCombo
                Kirigami.FormData.label: i18n("Choose your mode:")
                model: [
                    { "label": i18n("Light"), "mode": "light" },
                    { "label": i18n("Dark"), "mode": "dark" }
                ]
                textRole: "label"
                currentIndex: colorsPage.activeMode === "light" ? 0 : 1
                onActivated: index => colorsPage.applyAppearanceMode(model[index].mode)
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Transparency effects:")
                spacing: Kirigami.Units.smallSpacing

                QQC2.Label {
                    text: colorsPage.transparencyEnabled ? i18n("On") : i18n("Off")
                    textFormat: Text.PlainText
                }
                QQC2.Button {
                    text: i18n("Desktop Effects…")
                    onClicked: KCMUtils.KCMLauncher.openSystemSettings("kcm_kwin_effects")
                }
            }

            QQC2.ComboBox {
                id: accentModeCombo
                Kirigami.FormData.label: i18n("Accent color:")
                model: [
                    { "label": i18n("Automatic"), "source": "automatic" },
                    { "label": i18n("Manual"), "source": "manual" },
                    { "label": i18n("KDE System Settings"), "source": "native" }
                ]
                textRole: "label"
                currentIndex: colorsPage.nativeOverride || colorsPage.accentSource === "native" ? 2
                    : colorsPage.accentSource === "manual" ? 1 : 0
                onActivated: index => {
                    const chosen = model[index].source;
                    if (chosen === "automatic") {
                        colorsPage.applyAutomaticAccent();
                    } else if (chosen === "manual") {
                        colorsPage.applyManualAccent(colorsPage.manualColor || "#0078D4");
                    } else {
                        colorsPage.applyNativeAccentMode();
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing
            enabled: colorsPage.scriptAvailable && colorsPage.activePackage && !colorsPage.busy

            QQC2.Label {
                text: i18n("Windows colors")
                textFormat: Text.PlainText
                font.weight: Font.DemiBold
            }

            GridLayout {
                id: swatchLayout
                columns: 8
                rowSpacing: 6
                columnSpacing: 6

                Repeater {
                    model: {
                        const flat = [];
                        for (let r = 0; r < colorsPage.swatchGrid.length; ++r) {
                            const row = colorsPage.swatchGrid[r] || [];
                            for (let c = 0; c < row.length; ++c)
                                flat.push(String(row[c]).toUpperCase());
                        }
                        return flat;
                    }
                    delegate: QQC2.AbstractButton {
                        id: swatchButton
                        required property string modelData
                        readonly property bool isSelected: !colorsPage.nativeOverride
                            && colorsPage.accentSource === "manual"
                            && colorsPage.manualColor === modelData
                        implicitWidth: 36
                        implicitHeight: 36
                        hoverEnabled: true
                        activeFocusOnTab: true
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: modelData
                        Accessible.checked: isSelected
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.text: modelData
                        onClicked: colorsPage.applyManualAccent(modelData)

                        background: Rectangle {
                            radius: ControlMetrics.controlCornerRadius
                            color: swatchButton.modelData
                            scale: swatchButton.down ? 0.92 : (swatchButton.hovered ? 1.04 : 1.0)
                            border.width: swatchButton.isSelected || swatchButton.activeFocus ? 2 : 1
                            border.color: swatchButton.isSelected || swatchButton.activeFocus
                                ? Kirigami.Theme.textColor
                                : Qt.rgba(0, 0, 0, 0.22)
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Kirigami.Units.shortDuration > 0 ? ControlMetrics.controlFasterDuration : 0
                                }
                            }
                        }

                        contentItem: Text {
                            visible: swatchButton.isSelected
                            text: "\u2713"
                            textFormat: Text.PlainText
                            font.pixelSize: 16
                            font.bold: true
                            color: ColorType.contrastingForeground(Qt.color(swatchButton.modelData))
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            RowLayout {
                Layout.topMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                QQC2.Label {
                    text: i18n("Custom colors:")
                    textFormat: Text.PlainText
                }

                KQC.ColorButton {
                    id: customColorPicker
                    showAlphaChannel: false
                    dialogTitle: i18n("Choose custom accent color")
                    color: colorsPage.normalizeHex(colorsPage.manualColor) || "#0078D4"
                    onAccepted: color => {
                        const hex = String(color).toUpperCase();
                        if (/^#[0-9A-F]{6}$/.test(hex)) {
                            customHexField.text = hex;
                            colorsPage.applyManualAccent(hex);
                        }
                    }
                }

                QQC2.TextField {
                    id: customHexField
                    Layout.preferredWidth: 108
                    Layout.minimumHeight: ControlMetrics.menuItemMinimumHeight
                    text: colorsPage.manualColor
                    placeholderText: "#0078D4"
                    maximumLength: 7
                    selectByMouse: true
                    onAccepted: {
                        const normalized = colorsPage.normalizeHex(text);
                        if (normalized) colorsPage.applyManualAccent(normalized);
                    }
                }

                QQC2.Button {
                    text: i18n("Apply")
                    enabled: colorsPage.normalizeHex(customHexField.text).length > 0
                    onClicked: colorsPage.applyManualAccent(customHexField.text)
                }

                QQC2.Button {
                    text: i18n("KDE Colors…")
                    onClicked: KCMUtils.KCMLauncher.openSystemSettings("kcm_colors")
                }
            }

            RowLayout {
                Layout.topMargin: Kirigami.Units.smallSpacing
                visible: colorsPage.activePalette !== null
                spacing: 4

                Repeater {
                    model: ["AccentLight3", "AccentLight2", "AccentLight1", "Accent", "AccentDark1", "AccentDark2", "AccentDark3"]
                    delegate: Rectangle {
                        required property string modelData
                        readonly property string shadeHex: colorsPage.activePalette && colorsPage.activePalette[modelData]
                            ? String(colorsPage.activePalette[modelData]) : "#0078D4"
                        width: 36
                        height: 18
                        radius: ControlMetrics.controlCornerRadius
                        color: shadeHex
                        border.width: 1
                        border.color: Qt.rgba(0, 0, 0, 0.2)
                        QQC2.ToolTip.visible: shadeHover.hovered
                        QQC2.ToolTip.text: modelData + ": " + shadeHex
                        HoverHandler { id: shadeHover }
                    }
                }
            }
        }
    }
}
