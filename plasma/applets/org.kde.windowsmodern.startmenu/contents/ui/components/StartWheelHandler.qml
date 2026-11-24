// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

WheelHandler {
    id: handler
    required property Flickable view
    required property real rowHeight
    target: null
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    enabled: view.visible && view.contentHeight > view.height
    onWheel: event => {
        // A wheel detent advances three list rows, including over the
        // header. Preserve continuous high-resolution touchpad movement.
        const pixels = event.pixelDelta.y;
        const angle = event.angleDelta.y;
        const delta = pixels !== 0 && Math.abs(angle) < 120 ? pixels
                    : angle !== 0 ? angle / 120 * 3 * handler.rowHeight : pixels;
        if (delta === 0) { event.accepted = false; return; }
        const low = view.originY - view.topMargin;
        const high = Math.max(low, view.originY + view.contentHeight - view.height + view.bottomMargin);
        view.cancelFlick();
        view.contentY = Math.max(low, Math.min(high, view.contentY - delta));
        event.accepted = true;
    }
}
