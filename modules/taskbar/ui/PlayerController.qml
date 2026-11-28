/*
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2014 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2017 Roman Gilg <subdiff@gmail.com>
    SPDX-FileCopyrightText: 2020 Nate Graham <nate@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

RowLayout {
    id: root

    property Mpris.PlayerContainer playerData: null

    enabled: root.playerData?.canControl ?? false
    spacing: Kirigami.Units.smallSpacing

    readonly property bool isPlaying: root.playerData?.playbackStatus === Mpris.PlaybackStatus.Playing

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        ScrollableTextWrapper {
            id: songTextWrapper

            Layout.fillWidth: true
            Layout.preferredHeight: songText.height
            implicitWidth: songText.implicitWidth

            textItem: PlasmaComponents3.Label {
                id: songText
                maximumLineCount: artistText.visible ? 1 : 2
                wrapMode: Text.NoWrap
                elide: songTextWrapper.state ? Text.ElideNone : Text.ElideRight
                text: root.playerData?.track ?? ""
                textFormat: Text.PlainText
            }
        }

        ScrollableTextWrapper {
            id: artistTextWrapper

            Layout.fillWidth: true
            Layout.preferredHeight: artistText.height
            implicitWidth: artistText.implicitWidth
            visible: artistText.text.length > 0

            textItem: PlasmaExtras.DescriptiveLabel {
                id: artistText
                wrapMode: Text.NoWrap
                elide: artistTextWrapper.state ? Text.ElideNone : Text.ElideRight
                text: root.playerData?.artist ?? ""
                font: Kirigami.Theme.smallFont
                textFormat: Text.PlainText
            }
        }
    }

    PlasmaComponents3.ToolButton {
        enabled: root.playerData?.canGoPrevious ?? false
        icon.name: mirrored ? "media-skip-forward" : "media-skip-backward"
        onClicked: root.playerData?.Previous()
    }

    PlasmaComponents3.ToolButton {
        enabled: (root.isPlaying ? root.playerData?.canPause : root.playerData?.canPlay) ?? false
        icon.name: root.isPlaying ? "media-playback-pause" : "media-playback-start"
        onClicked: {
            if (!root.isPlaying) {
                root.playerData?.Play();
            } else {
                root.playerData?.Pause();
            }
        }
    }

    PlasmaComponents3.ToolButton {
        enabled: root.playerData?.canGoNext ?? false
        icon.name: mirrored ? "media-skip-backward" : "media-skip-forward"
        onClicked: root.playerData?.Next()
    }
}
