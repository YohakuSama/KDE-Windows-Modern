// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import org.kde.plasma.private.mpris as Mpris
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/components" as Components

Item {
    width: 400
    height: 220
    QtObject {
        id: fakePlayer
        property string identity: "Test player"
        property string iconName: "audio-x-generic"
        property string track: "Test track"
        property string artist: "Test artist"
        property string artUrl: ""
        property int playbackStatus: Mpris.PlaybackStatus.Paused
        property bool canGoNext: true
        property bool canGoPrevious: true
        property bool canPlay: true
        property bool canPause: true
        property int previousCount: 0
        property int nextCount: 0
        function Previous() { previousCount++; }
        function Next() { nextCount++; }
        function Play() { playbackStatus = Mpris.PlaybackStatus.Playing; }
        function Pause() { playbackStatus = Mpris.PlaybackStatus.Paused; }
    }
    Components.MediaCard {
        id: card
        width: implicitWidth
        height: implicitHeight
        anchors.centerIn: parent
        player: fakePlayer
    }
    TestCase {
        name: "WindowsMediaCard"
        when: windowShown
        function test_stateAndControls() {
            verify(card.hasSession);
            compare(card.trackName, "Test track");
            compare(card.applicationName, "Test player");
            compare(card.implicitHeight, 178);
            const previous = findChild(card, "wmMediaPrevious");
            const play = findChild(card, "wmMediaPlayPause");
            const next = findChild(card, "wmMediaNext");
            verify(previous && play && next);
            mouseClick(previous);
            compare(fakePlayer.previousCount, 1);
            mouseClick(play);
            verify(card.playing);
            mouseClick(play);
            verify(!card.playing);
            mouseClick(next);
            compare(fakePlayer.nextCount, 1);
            fakePlayer.canGoNext = false;
            verify(!next.enabled);
            card.player = null;
            verify(!card.hasSession);
            card.player = fakePlayer;
        }
    }
}
