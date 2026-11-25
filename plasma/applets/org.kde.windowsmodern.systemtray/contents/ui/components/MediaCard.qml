// SPDX-License-Identifier: GPL-3.0-or-later
// One live MPRIS session, shared by the Quick Settings card and media page.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris
import "../js/colorType.js" as ColorType
import "../js/mediaSource.js" as MediaSource

Rectangle {
    id: card
    objectName: "wmMediaCard"
    property var player: null
    property real uiScale: 1
    property bool acrylic: false
    readonly property bool playing: !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property bool hasSession: !!player && (playing ||
        player.playbackStatus === Mpris.PlaybackStatus.Paused || String(player.track || "").length > 0)
    readonly property string trackName: player ? String(player.track || "") : ""
    readonly property string artistName: player ? String(player.artist || "") : ""
    readonly property var sourceInfo: MediaSource.describe(player ? player.identity : "",
        player ? player.desktopEntry : "", player ? player.iconName : "")
    readonly property string applicationName: sourceInfo.name
    readonly property string applicationIcon: sourceInfo.icon
    readonly property bool dark: ColorType.isDark(Kirigami.Theme.backgroundColor)
    readonly property color foreground: Kirigami.Theme.textColor
    readonly property color surfaceColor: ColorType.cardFill(dark, acrylic)
    readonly property color outlineColor: ColorType.cardBorder(dark)

    implicitWidth: Math.round(360 * uiScale)
    implicitHeight: Math.round(178 * uiScale)
    radius: Math.round(8 * uiScale)
    color: surfaceColor
    border.width: 1
    border.color: outlineColor

    function previous() {
        if (player && player.canGoPrevious) player.Previous();
    }
    function next() {
        if (player && player.canGoNext) player.Next();
    }
    function togglePlayback() {
        if (!player) return;
        if (playing && player.canPause) player.Pause();
        else if (!playing && player.canPlay) player.Play();
    }

    component Transport: QQC2.ToolButton {
        id: control
        required property string kind
        implicitWidth: Math.round(48 * card.uiScale)
        implicitHeight: Math.round(36 * card.uiScale)
        padding: 0
        display: QQC2.AbstractButton.IconOnly
        background: Rectangle {
            radius: 4
            color: Qt.rgba(card.foreground.r, card.foreground.g, card.foreground.b,
                           control.down ? 0.12 : control.hovered || control.activeFocus ? 0.07 : 0)
        }
        contentItem: Item {
            Canvas {
                id: glyph
                anchors.centerIn: parent
                width: Math.round(20 * card.uiScale)
                height: width
                opacity: control.enabled ? 1 : 0.32
                readonly property string kind: control.kind
                readonly property color ink: card.foreground
                onKindChanged: requestPaint()
                onInkChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const c = getContext("2d");
                    c.reset();
                    c.clearRect(0, 0, width, height);
                    c.scale(width / 20, height / 20);
                    c.fillStyle = ink;
                    if (kind === "pause") {
                        c.fillRect(4, 3, 4, 14);
                        c.fillRect(12, 3, 4, 14);
                        return;
                    }
                    c.beginPath();
                    if (kind === "previous") {
                        c.moveTo(15, 3);
                        c.lineTo(5, 10);
                        c.lineTo(15, 17);
                        c.closePath();
                        c.fill();
                        c.fillRect(3, 3, 2, 14);
                    } else if (kind === "next") {
                        c.moveTo(5, 3);
                        c.lineTo(15, 10);
                        c.lineTo(5, 17);
                        c.closePath();
                        c.fill();
                        c.fillRect(15, 3, 2, 14);
                    } else {
                        c.moveTo(5, 3);
                        c.lineTo(17, 10);
                        c.lineTo(5, 17);
                        c.closePath();
                        c.fill();
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.round(24 * card.uiScale)
        anchors.rightMargin: anchors.leftMargin
        anchors.topMargin: Math.round(16 * card.uiScale)
        anchors.bottomMargin: Math.round(14 * card.uiScale)
        spacing: Math.round(10 * card.uiScale)

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(20 * card.uiScale)
            spacing: Math.round(8 * card.uiScale)
            Kirigami.Icon {
                objectName: "wmMediaSourceIcon"
                Layout.preferredWidth: Math.round(18 * card.uiScale)
                Layout.preferredHeight: Layout.preferredWidth
                source: card.applicationIcon
                fallback: card.sourceInfo.fallback
                roundToIconSize: false
                animated: false
            }
            Text {
                Layout.fillWidth: true
                color: card.foreground
                objectName: "wmMediaSourceName"
                text: card.applicationName
                textFormat: Text.PlainText
                font.pixelSize: Math.round(12 * card.uiScale)
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Math.round(12 * card.uiScale)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Math.round(3 * card.uiScale)
                Text {
                    Layout.fillWidth: true
                    color: card.foreground
                    text: card.trackName || i18n("Unknown track")
                    textFormat: Text.PlainText
                    font.pixelSize: Math.round(14 * card.uiScale)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: card.artistName.length > 0
                    color: card.foreground
                    text: card.artistName
                    textFormat: Text.PlainText
                    font.pixelSize: Math.round(12 * card.uiScale)
                    elide: Text.ElideRight
                }
            }
            Rectangle {
                id: artwork
                Layout.preferredWidth: Math.round(60 * card.uiScale)
                Layout.preferredHeight: Layout.preferredWidth
                radius: 4
                color: Qt.rgba(card.foreground.r, card.foreground.g, card.foreground.b, 0.08)
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Math.round(26 * card.uiScale)
                    height: width
                    source: "audio-x-generic-symbolic"
                    visible: albumImage.status !== Image.Ready
                    isMask: true
                    color: card.foreground
                    opacity: 0.6
                }
                Image {
                    id: albumImage
                    anchors.fill: parent
                    anchors.margins: 1
                    source: card.player ? card.player.artUrl || "" : ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Math.round(18 * card.uiScale)
            Transport {
                objectName: "wmMediaPrevious"
                kind: "previous"
                text: i18n("Previous track")
                Accessible.name: text
                enabled: !!card.player && card.player.canGoPrevious
                onClicked: card.previous()
            }
            Transport {
                objectName: "wmMediaPlayPause"
                kind: card.playing ? "pause" : "play"
                text: card.playing ? i18n("Pause") : i18n("Play")
                Accessible.name: text
                enabled: !!card.player && (card.playing ? card.player.canPause : card.player.canPlay)
                onClicked: card.togglePlayback()
            }
            Transport {
                objectName: "wmMediaNext"
                kind: "next"
                text: i18n("Next track")
                Accessible.name: text
                enabled: !!card.player && card.player.canGoNext
                onClicked: card.next()
            }
        }
    }
}
