// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.kirigami as Kirigami

// Match Plasma Kickoff: use Kirigami's native event filter for the
// Flickable and its attached scroll bars, not a parallel Qt WheelHandler.
// In particular, it prefers angle delta over slow Wayland pixel delta.
Kirigami.WheelHandler {
    id: handler
    required property Flickable view
    required property real rowHeight
    target: view
    filterMouseEvents: true
    blockTargetWheel: true
    keyNavigationEnabled: false
    verticalStepSize: Math.max(120, 3 * rowHeight)
}
