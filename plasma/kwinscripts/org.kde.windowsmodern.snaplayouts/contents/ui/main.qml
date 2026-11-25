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

    function track(win) {
        if (!win || !win.normalWindow) {
            return;
        }
        win.interactiveMoveResizeStarted.connect(() => {
            if (snapTimer.win === win) {
                snapTimer.stop();
                snapTimer.win = null;
                snapTimer.rect = null;
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
        snapTimer.restart();
    }

    Timer {
        id: snapTimer
        property var win: null
        property var rect: null
        interval: 50
        onTriggered: {
            if (!win || win.deleted || win.move || win.resize) {
                win = null;
                rect = null;
                return;
            }
            if (typeof win.setMaximize === "function") {
                win.setMaximize(false, false);
            }
            win.frameGeometry = Qt.rect(rect.x, rect.y, rect.width, rect.height);
            win = null;
            rect = null;
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
            if (root.movingWindow === win) {
                root.movingWindow = null;
                root.resetPicker();
            }
            if (snapTimer.win === win) {
                snapTimer.stop();
                snapTimer.win = null;
                snapTimer.rect = null;
            }
        }
        function onScreensChanged() {
            root.resetPicker();
            snapTimer.stop();
            snapTimer.win = null;
            snapTimer.rect = null;
        }
    }
}
