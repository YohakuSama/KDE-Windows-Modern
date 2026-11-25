// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.components as PlasmaComponents3
import "../lib" as Lib

Lib.Page {
    id: page
    title: i18n("Media")
    contentFillsHeight: false

    Mpris.Mpris2Model { id: playerModel }

    MediaCard {
        id: card
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        player: playerModel.currentPlayer
        visible: hasSession
    }
    PlasmaComponents3.Label {
        Layout.fillWidth: true
        text: i18n("No media playing")
        horizontalAlignment: Text.AlignHCenter
        visible: !card.hasSession
    }
}
