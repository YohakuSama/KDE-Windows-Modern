// Snap Layouts: the layout table, cell rectangles and pointer hit-testing.
import QtQuick
import QtTest
import "../../plasma/kwinscripts/org.kde.windowsmodern.snaplayouts/contents/ui/layouts.js" as Layouts

TestCase {
    name: "SnapLayouts"

    // Every layout tiles the work area exactly: cells cover the whole
    // area once (sum of areas is 1) and stay inside it.
    function test_layoutsTile() {
        for (let l = 0; l < Layouts.layouts.length; ++l) {
            let sum = 0;
            for (const c of Layouts.layouts[l]) {
                verify(c[0] >= 0 && c[1] >= 0 && c[0] + c[2] <= 1 + 1e-9 && c[1] + c[3] <= 1 + 1e-9, "inside, layout " + l);
                sum += c[2] * c[3];
            }
            fuzzyCompare(sum, 1, 1e-9, "covers the area, layout " + l);
        }
    }

    // Neighbouring cells share edges in whole pixels: no gaps, no overlap.
    function test_cellRectsShareEdges() {
        const area = { x: 0, y: 0, width: 1920, height: 1032 };
        const thirds = Layouts.layouts[2].map(c => Layouts.cellRect(area, c));
        compare(thirds[0].x + thirds[0].width, thirds[1].x);
        compare(thirds[1].x + thirds[1].width, thirds[2].x);
        compare(thirds[2].x + thirds[2].width, 1920);
        const half = Layouts.cellRect({ x: 0, y: 48, width: 1920, height: 1032 }, Layouts.layouts[0][1]);
        compare(half.x, 960); compare(half.y, 48); compare(half.width, 960); compare(half.height, 1032);
    }

    function test_sharedSizeConstraints() {
        const area = {x: -1601, y: 41, width: 1601, height: 901};
        const half = Layouts.cellRect(area, Layouts.layouts[0][0]);
        const quarter = Layouts.cellRect(area, Layouts.layouts[4][0]);
        const min = Qt.size(600, 700);
        const max = Qt.size(0, 0);
        verify(Layouts.fitsSize(half, min, max));
        verify(!Layouts.fitsSize(quarter, min, max));
        verify(!Layouts.fitsSize(half, min, Qt.size(600, 0)));
        verify(Layouts.fitsSize(half, Qt.size(half.width, half.height),
                                Qt.size(half.width, half.height)));
        verify(Layouts.hasFittingCell(area, min, max));
        verify(!Layouts.hasFittingCell(area, Qt.size(1602, 902), max));
        verify(!Layouts.fitsSize({width: 0, height: 10}, Qt.size(0, 0), max));
    }

    function test_sharedPreviewMetrics() {
        compare(Layouts.diagramGap, 10);
        compare(Layouts.barDiagramWidth, 72);
        compare(Layouts.barDiagramHeight, 44);
        compare(Layouts.barCellGap, 3);
        compare(Layouts.barCellRadius, 3);
        compare(Layouts.captionCellGap, 4);
        compare(Layouts.captionCellRadius, 4);
        compare(Layouts.cellBorderWidth, 1);
        compare(Layouts.captionDiagramMaxWidth, 96);
        compare(Layouts.captionDiagramAspectRatio, 0.6);
    }

    function test_narrowAndShortOutputMetrics() {
        for (const size of [[300, 600], [1920, 25], [1920, 1080]]) {
            const m = Layouts.barMetrics(size[0], size[1]);
            verify(m.width * Layouts.layouts.length + m.gap * (Layouts.layouts.length - 1) <= size[0]);
            verify(m.height <= size[1]);
            verify(m.width > 0 && m.height > 0);
        }
        compare(Layouts.barMetrics(1920, 1080), {width: 72, height: 44, gap: 10, cellGap: 3});
    }

    function test_visibleCellGapsDoNotSnap() {
        compare(Layouts.cellAt(36, 20, 72, 44, 10, 3), null);
        compare(Layouts.cellAt(0, 20, 72, 44, 10, 3), null);
        compare(Layouts.cellAt(10, 0, 72, 44, 10, 3), null);
        compare(Layouts.cellAt(60, 20, 72, 44, 10, 3), {layout: 0, cell: 1});
    }

    function test_cellAt() {
        const w = 72, h = 44, gap = 10;
        compare(Layouts.cellAt(10, 10, w, h, gap), { layout: 0, cell: 0 });      // 50/50, left
        compare(Layouts.cellAt(60, 10, w, h, gap), { layout: 0, cell: 1 });      // 50/50, right
        compare(Layouts.cellAt(75, 10, w, h, gap), null);                        // gap between diagrams
        compare(Layouts.cellAt(4 * (w + gap) + 60, 40, w, h, gap), { layout: 4, cell: 3 }); // quarters, bottom right
        compare(Layouts.cellAt(10, -1, w, h, gap), null);                        // above
        compare(Layouts.cellAt(6 * (w + gap) + 5, 10, w, h, gap), null);          // past the last diagram
    }

    function test_snapAssistRemainingCellsAndOccupancy() {
        const area = { x: 0, y: 48, width: 1920, height: 1032 };
        // 2-zone 50/50: snapping cell 0 leaves cell 1 (right half)
        const halfOpen = Layouts.remainingLayoutCells(area, 0, [0], []);
        compare(halfOpen.length, 1);
        compare(halfOpen[0].cell, 1);
        compare(halfOpen[0].rect, { x: 960, y: 48, width: 960, height: 1032 });

        // If right half is already occupied (within tolerance), 0 open cells remain
        const alreadyFull = Layouts.remainingLayoutCells(area, 0, [0], [
            { x: 962, y: 48, width: 958, height: 1030 }
        ], 4);
        compare(alreadyFull.length, 0);

        // 4-zone grid (layout 4): snapping cell 0 with cell 2 occupied leaves [1, 3] in order
        const q2 = Layouts.cellRect(area, Layouts.layouts[4][2]);
        const gridOpen = Layouts.remainingLayoutCells(area, 4, [0], [q2], 4);
        compare(gridOpen.map(s => s.cell), [1, 3]);

        // Sequential fill of cell 1 leaves only cell 3
        const gridNext = Layouts.remainingLayoutCells(area, 4, [0, 1], [q2], 4);
        compare(gridNext.map(s => s.cell), [3]);

        // Invalid area or layout returns empty
        compare(Layouts.remainingLayoutCells({ x: 0, y: 0, width: 0, height: 100 }, 0, []), []);
        compare(Layouts.remainingLayoutCells(area, 99, []), []);
        verify(!Layouts.sameCellGeometry(null, q2));
        verify(Layouts.sameCellGeometry(q2, { x: q2.x + 2, y: q2.y - 2, width: q2.width, height: q2.height }, 4));
        verify(!Layouts.sameCellGeometry(q2, { x: q2.x + 10, y: q2.y, width: q2.width, height: q2.height }, 4));
    }
}
