// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

WheelHandler {
    id: handler
    required property Flickable view
    required property real rowHeight
    target: null
    acceptedDevices: PointerDevice.Mouse
    enabled: view.visible && view.contentHeight > view.height
    onWheel: event => {
        // Keep high-resolution trackpad/pixel input native; accelerate
        // discrete mouse wheel detents to three rows per notch.
        const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y
                    : event.angleDelta.y / 120 * 3 * handler.rowHeight;
        if (delta === 0) { event.accepted = false; return; }
        const low = view.originY - view.topMargin;
        const high = Math.max(low, view.originY + view.contentHeight - view.height + view.bottomMargin);
        const next = Math.max(low, Math.min(high, view.contentY - delta));
        if (Math.abs(next - view.contentY) < 0.01) { event.accepted = false; return; }
        view.cancelFlick();
        view.contentY = next;
        event.accepted = true;
    }
}
