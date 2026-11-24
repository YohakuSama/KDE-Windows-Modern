/* SPDX-License-Identifier: GPL-3.0-or-later */
import QtQuick

// A mouse drag takes the exclusive grab from the tile's click area.
// A touch swipe still belongs to the enclosing Flickable.
DragHandler {
    id: handler
    required property Item hostTile
    readonly property Item view: hostTile.orderView
    enabled: view !== null && hostTile.included
    target: null
    acceptedButtons: Qt.LeftButton
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
    cursorShape: Qt.ClosedHandCursor

    onGrabChanged: (transition, point) => {
        if (!view)
            return;
        if (transition === PointerDevice.GrabExclusive) {
            const position = view.mapFromItem(null, point.scenePosition.x, point.scenePosition.y);
            view.beginDrag(hostTile.orderKey, position);
        } else if (transition === PointerDevice.UngrabExclusive) {
            const position = view.mapFromItem(null, point.scenePosition.x, point.scenePosition.y);
            view.finishDrag(hostTile.orderKey, position);
        } else if (transition === PointerDevice.CancelGrabExclusive) {
            view.cancelDrag(hostTile.orderKey);
        }
    }

    onActiveTranslationChanged: {
        if (active && view) {
            const position = view.mapFromItem(null, centroid.scenePosition.x, centroid.scenePosition.y);
            view.updateDrag(hostTile.orderKey, position);
        }
    }
}
