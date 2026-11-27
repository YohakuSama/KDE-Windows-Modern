/*
    The layout picker: a row of small layout diagrams in the Plasma theme's
    popup frame, like the bar Windows 11 shows at the top of the screen.
    Colours follow the colour scheme (light and dark).

    The bar is placed so the diagram row sits at a fixed spot (centred,
    rowTop px below the screen's top), whatever padding the theme's frame
    has; cellAt() accounts for that padding.

    SPDX-FileCopyrightText: 2026 Jeysef
    SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

import "layouts.js" as Layouts

PlasmaCore.Window {
    id: bar

    property var hovered: null    // { layout, cell } or null
    property rect workArea: Qt.rect(0, 0, 1, 1)
    property rect screenGeometry: Qt.rect(0, 0, 1920, 1080)
    property size minimumWindowSize: Qt.size(0, 0)
    property size maximumWindowSize: Qt.size(0, 0)
    readonly property var metrics: Layouts.barMetrics(screenGeometry.width - leftPadding - rightPadding,
        screenGeometry.height - topPadding - bottomPadding)
    readonly property int diagramWidth: metrics.width
    readonly property int diagramHeight: metrics.height
    readonly property int gap: metrics.gap
    readonly property int rowTop: 20
    readonly property int cellGap: metrics.cellGap
    readonly property int rowWidth: Layouts.layouts.length * diagramWidth + (Layouts.layouts.length - 1) * gap

    visible: false
    flags: Qt.X11BypassWindowManagerHint | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus

    width: rowWidth + leftPadding + rightPadding
    height: diagramHeight + topPadding + bottomPadding

    function showOn(screen, area) {
        screenGeometry = screen;
        workArea = area;
        if (width > screen.width || height > screen.height || area.width <= 0 || area.height <= 0
            || !Layouts.hasFittingCell(area, minimumWindowSize, maximumWindowSize))
            return;
        const centered = Math.round(screen.x + (screen.width - rowWidth) / 2) - leftPadding;
        x = Math.max(screen.x, Math.min(centered, screen.x + screen.width - width));
        y = Math.max(screen.y, Math.min(screen.y + rowTop - topPadding, screen.y + screen.height - height));
        visible = true;
    }

    function fitsCell(cell) {
        return Layouts.fitsSize(Layouts.cellRect(workArea, cell), minimumWindowSize, maximumWindowSize);
    }

    // The enabled layout cell under a point in screen coordinates, or null.
    function cellAt(px, py) {
        const hit = Layouts.cellAt(px - x - leftPadding, py - y - topPadding,
                                   diagramWidth, diagramHeight, gap, cellGap);
        return hit && fitsCell(Layouts.layouts[hit.layout][hit.cell]) ? hit : null;
    }

    mainItem: Row {
        Kirigami.Theme.colorSet: Kirigami.Theme.Window
        Kirigami.Theme.inherit: false
        spacing: bar.gap
        Repeater {
            model: Layouts.layouts.length
            Item {
                id: diagram
                required property int index
                width: bar.diagramWidth
                height: bar.diagramHeight
                Repeater {
                    model: Layouts.layouts[diagram.index]
                    Rectangle {
                        required property var modelData
                        required property int index
                        enabled: bar.fitsCell(modelData)
                        readonly property bool isHovered: enabled && bar.hovered !== null
                            && bar.hovered.layout === diagram.index && bar.hovered.cell === index
                        x: modelData[0] * bar.diagramWidth + bar.cellGap / 2
                        y: modelData[1] * bar.diagramHeight + bar.cellGap / 2
                        width: Math.max(0, modelData[2] * bar.diagramWidth - bar.cellGap)
                        height: Math.max(0, modelData[3] * bar.diagramHeight - bar.cellGap)
                        radius: Layouts.barCellRadius
                        color: isHovered ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, enabled ? 0.10 : 0.04)
                        border.width: Layouts.cellBorderWidth
                        border.color: isHovered ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, enabled ? 0.35 : 0.15)
                    }
                }
            }
        }
    }
}
