// SPDX-License-Identifier: GPL-3.0-or-later
// Caption-button Snap Layouts: the same six layouts as the drag-to-top
// picker, in a compact interactive grid anchored to the maximize button.
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

import "layouts.js" as Layouts

PlasmaCore.Window {
    id: picker

    signal cellChosen(int layout, int cell)
    property rect screenGeometry: Qt.rect(0, 0, 1920, 1080)
    property rect workArea: Qt.rect(0, 0, 1, 1)
    property rect anchorRect: Qt.rect(0, 0, 1, 1)
    property size minimumWindowSize: Qt.size(0, 0)
    property size maximumWindowSize: Qt.size(0, 0)
    readonly property int gap: 10
    readonly property int cellGap: 4
    readonly property int diagramColumns: Math.max(1, Math.min(2,
        Math.floor((screenGeometry.width - leftPadding - rightPadding + gap) / (96 + gap))))
    readonly property int diagramWidth: Math.max(1, Math.min(96,
        Math.floor((screenGeometry.width - leftPadding - rightPadding - (diagramColumns - 1) * gap) / diagramColumns)))
    readonly property int diagramHeight: Math.max(1, Math.round(diagramWidth * 0.6))
    readonly property int diagramRows: Math.ceil(Layouts.layouts.length / diagramColumns)

    visible: false
    flags: Qt.X11BypassWindowManagerHint | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
    width: diagramColumns * diagramWidth + (diagramColumns - 1) * gap + leftPadding + rightPadding
    height: diagramRows * diagramHeight + (diagramRows - 1) * gap + topPadding + bottomPadding

    function showFor(screen, area, anchor, minimum, maximum) {
        screenGeometry = screen;
        workArea = area;
        anchorRect = anchor;
        minimumWindowSize = minimum;
        maximumWindowSize = maximum;
        if (!Layouts.hasFittingCell(area, minimum, maximum))
            return false;
        if (diagramWidth < 48 || width > screen.width || height > screen.height
            || area.width <= 0 || area.height <= 0)
            return false;
        const below = anchor.y + anchor.height + 6;
        const above = anchor.y - height - 6;
        const fitsBelow = below + height <= screen.y + screen.height;
        if (!fitsBelow && above < screen.y)
            return false; // Do not overlap the actual maximize button.
        const desiredY = fitsBelow ? below : above;
        x = Math.max(screen.x, Math.min(anchor.x + anchor.width - width, screen.x + screen.width - width));
        y = Math.max(screen.y, Math.min(desiredY, screen.y + screen.height - height));
        visible = true;
        return true;
    }

    function fitsCell(cell) {
        return Layouts.fitsSize(Layouts.cellRect(workArea, cell), minimumWindowSize, maximumWindowSize);
    }

    function inside(point, rect, padding) {
        return point.x >= rect.x - padding && point.x <= rect.x + rect.width + padding
            && point.y >= rect.y - padding && point.y <= rect.y + rect.height + padding;
    }

    function containsPointer(point) {
        const popup = Qt.rect(x, y, width, height);
        // Include the small gap between the anchor and popup, without
        // retaining the picker over unrelated title-bar controls.
        if (inside(point, anchorRect, 4) || inside(point, popup, 4))
            return true;
        const corridor = Qt.rect(anchorRect.x, Math.min(anchorRect.y, y),
            anchorRect.width, Math.max(anchorRect.y + anchorRect.height, y + height) - Math.min(anchorRect.y, y));
        return inside(point, corridor, 2);
    }

    mainItem: Grid {
        Kirigami.Theme.colorSet: Kirigami.Theme.Window
        Kirigami.Theme.inherit: false
        columns: picker.diagramColumns
        spacing: picker.gap

        Repeater {
            model: Layouts.layouts.length
            Item {
                id: diagram
                required property int index
                width: picker.diagramWidth
                height: picker.diagramHeight

                Repeater {
                    model: Layouts.layouts[diagram.index]
                    Rectangle {
                        id: cell
                        required property var modelData
                        required property int index
                        x: modelData[0] * diagram.width + picker.cellGap / 2
                        y: modelData[1] * diagram.height + picker.cellGap / 2
                        width: Math.max(0, modelData[2] * diagram.width - picker.cellGap)
                        height: Math.max(0, modelData[3] * diagram.height - picker.cellGap)
                        radius: 4
                        enabled: picker.fitsCell(modelData)
                        color: enabled && hit.containsMouse ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, enabled ? 0.10 : 0.04)
                        border.width: 1
                        border.color: enabled && hit.containsMouse ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, enabled ? 0.35 : 0.15)
                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("Layout %1, position %2").arg(diagram.index + 1).arg(index + 1)
                        Accessible.onPressAction: if (enabled) picker.cellChosen(diagram.index, index)

                        MouseArea {
                            id: hit
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: picker.cellChosen(diagram.index, cell.index)
                        }
                    }
                }
            }
        }
    }
}
