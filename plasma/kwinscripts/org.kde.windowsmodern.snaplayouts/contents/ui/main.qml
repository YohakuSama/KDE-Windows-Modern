/*
    Windows 11 Snap Layouts. Drag a window towards the top edge: a bar of
    layouts slides in at the top centre. Hover a cell to preview where the
    window goes, release to snap it there. Releasing anywhere else leaves
    KWin's own behaviour (e.g. maximize at the top edge) alone.

    KWin keeps the pointer during a move, so the bar gets no hover events:
    the hovered cell is worked out from the cursor on every move step.

    SPDX-FileCopyrightText: 2026 Jeysef
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import org.kde.kwin

import "layouts.js" as Layouts

Item {
    id: root

    // How close to the top of the screen the pointer must come.
    readonly property int triggerDistance: 48

    property var movingWindow: null
    property var target: null // { layout, cell, rect } while a cell is hovered
    property var captionWindow: null
    property rect captionGeometry: Qt.rect(0, 0, 0, 0)

    function track(win) {
        if (!win || !win.normalWindow) {
            return;
        }
        win.interactiveMoveResizeStarted.connect(() => {
            root.hideCaptionPicker();
            if (snapTimer.win === win) {
                snapTimer.stop();
                snapTimer.win = null;
                snapTimer.rect = null;
                snapTimer.captionArea = null;
                snapTimer.captionFrame = null;
            }
            if (win.move && win.resizeable) {
                root.resetPicker();
                root.movingWindow = win;
            }
        });
        win.interactiveMoveResizeStepped.connect(() => {
            if (root.movingWindow === win) {
                root.update(win);
            }
        });
        win.interactiveMoveResizeFinished.connect(() => {
            if (root.movingWindow === win) {
                root.finish(win);
            }
        });
    }

    function resetPicker() {
        if (target) Workspace.hideOutline();
        target = null;
        bar.visible = false;
    }

    function sameRect(a, b) {
        return a.x === b.x && a.y === b.y && a.width === b.width && a.height === b.height;
    }

    function update(win) {
        const cursor = Workspace.cursorPos;
        const output = Workspace.screenAt(cursor);
        if (!output) {
            resetPicker();
            return;
        }
        const screen = Workspace.clientArea(KWin.FullScreenArea, output, Workspace.currentDesktop);
        const area = Workspace.clientArea(KWin.MaximizeArea, output, Workspace.currentDesktop);
        // The cursor can cross outputs before KWin changes the window's
        // assigned output. Never keep a target on the previous monitor.
        if (bar.visible && (!sameRect(bar.screenGeometry, screen) || !sameRect(bar.workArea, area)))
            resetPicker();
        const nearTop = cursor.y >= screen.y && cursor.y - screen.y <= triggerDistance
            && cursor.x >= screen.x && cursor.x < screen.x + screen.width;
        if (!bar.visible && !nearTop) return;
        if (!bar.visible) bar.showOn(screen, area);
        if (!bar.visible) return;
        const hit = bar.cellAt(cursor.x, cursor.y);
        if (hit) {
            const rect = Layouts.cellRect(bar.workArea, Layouts.layouts[hit.layout][hit.cell]);
            if (!target || target.layout !== hit.layout || target.cell !== hit.cell) {
                target = { layout: hit.layout, cell: hit.cell, rect: rect };
                Workspace.showOutline(Qt.rect(rect.x, rect.y, rect.width, rect.height));
            }
        } else {
            if (target) {
                Workspace.hideOutline();
            }
            target = null;
            // Leave the bar once the pointer is well below it.
            if (cursor.y > bar.y + bar.height + triggerDistance) {
                bar.visible = false;
            }
        }
    }

    function finish(win) {
        const cursor = Workspace.cursorPos;
        const hit = bar.visible ? bar.cellAt(cursor.x, cursor.y) : null;
        const output = Workspace.screenAt(cursor);
        const chosen = target && hit && hit.layout === target.layout && hit.cell === target.cell
            && output && sameRect(bar.workArea, Workspace.clientArea(KWin.MaximizeArea, output, Workspace.currentDesktop))
            ? target : null;
        resetPicker();
        movingWindow = null;
        if (!chosen || win.deleted) return;
        // After KWin has handled the release (it may maximize at the top edge).
        snapTimer.win = win;
        snapTimer.rect = chosen.rect;
        snapTimer.captionArea = null;
        snapTimer.captionFrame = null;
        snapTimer.restart();
    }

    // The application cannot position Wayland toplevels. Its optional
    // Konsole plugin only requests a short-lived anchor. KWin retains the
    // target window, presents the picker and applies the chosen geometry.
    function captionCandidate(win) {
        if (!win || win.deleted || !win.normalWindow || !win.active
            || win !== Workspace.activeWindow || !win.resizeable
            || !win.moveable || win.fullScreen || win.minimized || win.move || win.resize
            || win.pid <= 0)
            return false;
        // noBorder is a decoration policy, not a reliable Wayland CSD
        // indicator. Require the actual client and frame to coincide.
        const g = win.frameGeometry;
        const client = win.clientGeometry;
        if (!client || Math.abs(g.x - client.x) > 2 || Math.abs(g.y - client.y) > 2
            || Math.abs(g.width - client.width) > 2 || Math.abs(g.height - client.height) > 2)
            return false;
        const name = String(win.resourceClass).toLowerCase();
        const desktop = String(win.desktopFileName).toLowerCase();
        return name === "konsole" || name === "org.kde.konsole"
            || desktop === "org.kde.konsole";
    }

    function hideCaptionPicker() {
        captionWindow = null;
        captionPicker.visible = false;
    }

    function fitsWindow(win, rect) {
        const min = win.minSize;
        const max = win.maxSize;
        return rect.width >= min.width && rect.height >= min.height
            && (max.width <= 0 || rect.width <= max.width)
            && (max.height <= 0 || rect.height <= max.height);
    }

    function clearCaptionSnap() {
        if (!snapTimer.captionArea)
            return;
        snapTimer.stop();
        snapTimer.win = null;
        snapTimer.rect = null;
        snapTimer.captionArea = null;
        snapTimer.captionFrame = null;
    }

    function requestCaptionPicker() {
        const win = Workspace.activeWindow;
        if (captionRequest.pending || movingWindow || !captionCandidate(win))
            return;
        captionRequest.win = win;
        captionRequest.pending = true;
        captionRequest.service = "org.kde.windowsmodern.KonsoleChrome.p" + win.pid;
        captionRequest.call();
    }

    function showCaptionPicker(win, reply) {
        if (!captionCandidate(win) || movingWindow || !reply || reply.length !== 1 || !reply[0])
            return;
        let anchor;
        try {
            anchor = JSON.parse(String(reply[0]));
        } catch (error) {
            return;
        }
        const g = win.frameGeometry;
        if (!anchor || ![anchor.x, anchor.y, anchor.width, anchor.height,
                         anchor.windowWidth, anchor.windowHeight].every(Number.isFinite)
            || anchor.x < 0 || anchor.y < 0 || anchor.width < 20 || anchor.width > 100
            || anchor.height < 20 || anchor.height > 100
            || anchor.x + anchor.width > anchor.windowWidth
            || anchor.y + anchor.height > anchor.windowHeight
            || Math.abs(anchor.windowWidth - g.width) > 2
            || Math.abs(anchor.windowHeight - g.height) > 2)
            return;
        const rect = Qt.rect(win.clientGeometry.x + anchor.x, win.clientGeometry.y + anchor.y,
            anchor.width, anchor.height);
        const cursor = Workspace.cursorPos;
        if (cursor.x < rect.x - 2 || cursor.x > rect.x + rect.width + 2
            || cursor.y < rect.y - 2 || cursor.y > rect.y + rect.height + 2)
            return;
        const output = Workspace.screenAt(Qt.point(rect.x + rect.width / 2, rect.y + rect.height / 2));
        if (!output)
            return;
        hideCaptionPicker();
        const screen = Workspace.clientArea(KWin.FullScreenArea, output, Workspace.currentDesktop);
        const area = Workspace.clientArea(KWin.MaximizeArea, output, Workspace.currentDesktop);
        if (captionPicker.showFor(screen, area, rect, win.minSize, win.maxSize)) {
            captionWindow = win;
            captionGeometry = Qt.rect(g.x, g.y, g.width, g.height);
        }
    }

    ShortcutHandler {
        name: "Windows Modern: Show Konsole Snap Layouts"
        text: qsTr("Windows Modern: Show Konsole Snap Layouts")
        // No default global shortcut, and no effect without a live one-shot
        // request from the active Konsole window.
        onActivated: root.requestCaptionPicker()
    }

    DBusCall {
        id: captionRequest
        property var win: null
        property bool pending: false
        path: "/KonsoleChrome"
        dbusInterface: "org.kde.windowsmodern.KonsoleChrome"
        method: "takeAnchor"
        onFinished: returnValue => {
            const requested = win;
            win = null;
            pending = false;
            root.showCaptionPicker(requested, returnValue);
        }
        onFailed: {
            win = null;
            pending = false;
        }
    }

    CaptionSnapPicker {
        id: captionPicker
        onCellChosen: (layout, cell) => {
            const win = root.captionWindow;
            const area = workArea;
            root.hideCaptionPicker();
            if (!root.captionCandidate(win) || !root.sameRect(root.captionGeometry, win.frameGeometry)
                || !Layouts.layouts[layout] || !Layouts.layouts[layout][cell])
                return;
            const output = Workspace.screenAt(Qt.point(area.x + area.width / 2, area.y + area.height / 2));
            if (!output || !root.sameRect(area, Workspace.clientArea(KWin.MaximizeArea, output, Workspace.currentDesktop)))
                return;
            const rect = Layouts.cellRect(area, Layouts.layouts[layout][cell]);
            if (!root.fitsWindow(win, rect))
                return;
            snapTimer.win = win;
            snapTimer.rect = rect;
            snapTimer.captionArea = area;
            snapTimer.captionFrame = root.captionGeometry;
            snapTimer.restart();
        }
    }

    Timer {
        interval: 90
        repeat: true
        running: captionPicker.visible
        onTriggered: {
            if (!root.captionCandidate(root.captionWindow)
                || !root.sameRect(root.captionGeometry, root.captionWindow.frameGeometry)
                || !captionPicker.containsPointer(Workspace.cursorPos))
                root.hideCaptionPicker();
        }
    }

    Timer {
        id: snapTimer
        property var win: null
        property var rect: null
        property var captionArea: null
        property var captionFrame: null
        interval: 50
        onTriggered: {
            const window = win;
            const geometry = rect;
            const area = captionArea;
            const frame = captionFrame;
            win = null;
            rect = null;
            captionArea = null;
            captionFrame = null;
            if (!window || window.deleted || window.move || window.resize || !geometry)
                return;
            if (area) {
                // A focus switch or output change must not tile another
                // window or apply geometry captured for the old monitor.
                if (!root.captionCandidate(window) || !frame
                    || !root.sameRect(frame, window.frameGeometry) || !root.fitsWindow(window, geometry))
                    return;
                const output = Workspace.screenAt(Qt.point(area.x + area.width / 2, area.y + area.height / 2));
                if (!output || !root.sameRect(area, Workspace.clientArea(KWin.MaximizeArea, output, Workspace.currentDesktop)))
                    return;
                if (window.tile) {
                    if (typeof window.tile.unmanage === "function")
                        window.tile.unmanage(window);
                    else
                        window.tile = null;
                }
            }
            if (typeof window.setMaximize === "function")
                window.setMaximize(false, false);
            window.frameGeometry = Qt.rect(geometry.x, geometry.y, geometry.width, geometry.height);
        }
    }

    SnapBar {
        id: bar
        hovered: root.target
    }

    Component.onCompleted: {
        Workspace.windows.forEach(track);
    }

    Connections {
        target: Workspace
        function onWindowAdded(win) {
            root.track(win);
        }
        function onWindowRemoved(win) {
            if (root.captionWindow === win)
                root.hideCaptionPicker();
            if (captionRequest.win === win)
                captionRequest.win = null;
            if (root.movingWindow === win) {
                root.movingWindow = null;
                root.resetPicker();
            }
            if (snapTimer.win === win) {
                snapTimer.stop();
                snapTimer.win = null;
                snapTimer.rect = null;
                snapTimer.captionArea = null;
                snapTimer.captionFrame = null;
            }
        }
        function onWindowActivated(win) {
            if (snapTimer.captionArea && snapTimer.win !== win)
                root.clearCaptionSnap();
            if (root.captionWindow && root.captionWindow !== win)
                root.hideCaptionPicker();
            if (captionRequest.win && captionRequest.win !== win)
                captionRequest.win = null;
        }
        function onCurrentDesktopChanged() {
            root.clearCaptionSnap();
            root.hideCaptionPicker();
            captionRequest.win = null;
        }
        function onScreensChanged() {
            root.hideCaptionPicker();
            captionRequest.win = null;
            root.resetPicker();
            snapTimer.stop();
            snapTimer.win = null;
            snapTimer.rect = null;
            snapTimer.captionArea = null;
            snapTimer.captionFrame = null;
        }
    }
}
