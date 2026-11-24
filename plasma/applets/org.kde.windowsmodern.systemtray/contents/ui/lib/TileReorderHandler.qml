/* SPDX-License-Identifier: GPL-3.0-or-later */
import QtQuick

// A mouse drag takes the exclusive grab from the tile's click area.
// A touch swipe still belongs to the enclosing Flickable.
DragHandler {
    id: handler
    required property Item tile
    readonly property Item view: tile.orderView
    enabled: view !== null && tile.included
    target: null
    acceptedButtons: Qt.LeftButton
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
    cursorShape: Qt.ClosedHandCursor

    onGrabChanged: (transition, point) => {
        if (!view)
            return;
        if (transition === PointerDevice.GrabExclusive) {
            const position = view.mapFromItem(null, point.scenePosition.x, point.scenePosition.y);
            view.beginDrag(tile.orderKey, position);
        } else if (transition === PointerDevice.UngrabExclusive) {
            const position = view.mapFromItem(null, point.scenePosition.x, point.scenePosition.y);
            view.finishDrag(tile.orderKey, position);
        } else if (transition === PointerDevice.CancelGrabExclusive) {
            view.cancelDrag(tile.orderKey);
        }
    }

    onActiveTranslationChanged: {
        if (active && view) {
            const position = view.mapFromItem(null, centroid.scenePosition.x, centroid.scenePosition.y);
            view.updateDrag(tile.orderKey, position);
        }
    }
}
