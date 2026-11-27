// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import org.kde.plasma.private.mpris as Mpris
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/components" as Components
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/js/controlMetrics.js" as ControlMetrics

Item {
    id: fixture
    function i18n(text) { return text; }
    width: 400
    height: 220
    QtObject {
        id: fakeState
        property string identity: "Test player"
        property string iconName: "audio-x-generic"
        property string desktopEntry: ""
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
    }
    // Native MPRIS exposes capitalized C++ invokables. QML-declared
    // methods cannot begin with a capital, so use a JS adapter around
    // reactive QtObject properties rather than an invalid QML mock.
    readonly property var mockPlayer: ({
        get identity() { return fakeState.identity; },
        get iconName() { return fakeState.iconName; },
        get desktopEntry() { return fakeState.desktopEntry; },
        get track() { return fakeState.track; },
        get artist() { return fakeState.artist; },
        get artUrl() { return fakeState.artUrl; },
        get playbackStatus() { return fakeState.playbackStatus; },
        get canGoNext() { return fakeState.canGoNext; },
        get canGoPrevious() { return fakeState.canGoPrevious; },
        get canPlay() { return fakeState.canPlay; },
        get canPause() { return fakeState.canPause; },
        Previous: function() { fakeState.previousCount++; },
        Next: function() { fakeState.nextCount++; },
        Play: function() { fakeState.playbackStatus = Mpris.PlaybackStatus.Playing; },
        Pause: function() { fakeState.playbackStatus = Mpris.PlaybackStatus.Paused; }
    })
    Components.MediaCard {
        id: card
        width: implicitWidth
        height: implicitHeight
        anchors.centerIn: parent
        player: fixture.mockPlayer
    }
    TestCase {
        name: "WindowsMediaCard"
        when: windowShown
        function test_browserSource() {
            fakeState.identity = "Mozilla firefox-nightly";
            fakeState.desktopEntry = "firefox-nightly";
            fakeState.iconName = "emblem-music-symbolic";
            tryCompare(card, "applicationName", "Firefox Nightly");
            compare(card.applicationIcon, "firefox-nightly");
            fakeState.identity = "Microsoft Edge";
            fakeState.desktopEntry = "com.microsoft.Edge";
            tryCompare(card, "applicationName", "Microsoft Edge");
            compare(card.applicationIcon, "microsoft-edge");
            fakeState.identity = "Firefox Nightly Radio";
            fakeState.desktopEntry = "org.example.radio";
            tryCompare(card, "applicationName", "Firefox Nightly Radio");
            compare(card.applicationIcon, "org.example.radio");
            fakeState.identity = "Test player";
            fakeState.desktopEntry = "";
            fakeState.iconName = "audio-x-generic";
            tryCompare(card, "applicationName", "Test player");
        }
        function test_repeatTrackControls() {
            const previous = findChild(card, "wmMediaPrevious");
            const next = findChild(card, "wmMediaNext");
            const play = findChild(card, "wmMediaPlayPause");
            const before = fakeState.previousCount;
            fakeState.canGoPrevious = true;
            fakeState.canGoNext = true;
            tryCompare(previous, "enabled", true);
            tryCompare(next, "enabled", true);
            mousePress(previous);
            tryVerify(() => fakeState.previousCount >= before + 2, 1800);
            mouseRelease(previous);
            const released = fakeState.previousCount;
            wait(350);
            compare(fakeState.previousCount, released);
            fakeState.canGoNext = false;
            tryCompare(next, "enabled", false);
            const nextBefore = fakeState.nextCount;
            mousePress(next);
            wait(600);
            mouseRelease(next);
            compare(fakeState.nextCount, nextBefore);
            fakeState.canGoNext = true;
            verify(!play.autoRepeat);
            // Other cases expect fresh counters.
            fakeState.previousCount = 0;
            fakeState.nextCount = 0;
        }

        function test_sharedCardRadiusTracksUiScale() {
            compare(card.radius, Math.round(ControlMetrics.cardSurfaceRadius * card.uiScale));
            card.uiScale = 1.25;
            compare(card.radius, Math.round(ControlMetrics.cardSurfaceRadius * card.uiScale));
            card.uiScale = 1;
            compare(card.radius, ControlMetrics.cardSurfaceRadius);
        }

        function test_stateAndControls() {
            verify(card.hasSession);
            compare(card.trackName, "Test track");
            compare(card.applicationName, "Test player");
            compare(card.implicitWidth, 376);
            compare(card.implicitHeight, 178);
            const previous = findChild(card, "wmMediaPrevious");
            const play = findChild(card, "wmMediaPlayPause");
            const next = findChild(card, "wmMediaNext");
            verify(previous && play && next);
            compare(previous.implicitWidth, 40);
            compare(previous.implicitHeight, 40);
            compare(previous.nativeRole, "wm-media-previous-symbolic");
            compare(play.nativeRole, "wm-media-play-symbolic");
            compare(next.nativeRole, "wm-media-next-symbolic");
            verify(previous.autoRepeat && next.autoRepeat);
            verify(!play.autoRepeat);
            for (const transport of [previous, next]) {
                compare(transport.autoRepeatDelay, 250);
                compare(transport.autoRepeatInterval, 250);
            }
            mouseClick(previous);
            compare(fakeState.previousCount, 1);
            mouseClick(play);
            tryCompare(card, "playing", true);
            tryCompare(play, "nativeRole", "wm-media-pause-symbolic");
            mouseClick(play);
            tryCompare(card, "playing", false);
            tryCompare(play, "nativeRole", "wm-media-play-symbolic");
            mouseClick(next);
            compare(fakeState.nextCount, 1);
            fakeState.canGoNext = false;
            tryCompare(next, "enabled", false);
            card.player = null;
            verify(!card.hasSession);
            card.player = fixture.mockPlayer;
        }
    }
}
