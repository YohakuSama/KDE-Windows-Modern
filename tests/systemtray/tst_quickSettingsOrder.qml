import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/js/quickSettingsOrder.js" as Order

TestCase {
    name: "QuickSettingsOrder"
    function test_normalize() {
        compare(Order.normalizeOrder(["b", "b", "obsolete"], ["a", "b", "c"]), ["b", "a", "c"]);
        compare(Order.normalizeOrder([""], ["a", "b"]), ["a", "b"]);
    }
    function test_reorder_preserves_hidden_slots() {
        const order = ["a", "hidden", "b", "c", "d"];
        compare(Order.moveVisible(order, ["a", "b", "c", "d"], "a", 3),
            ["b", "hidden", "c", "d", "a"]);
        compare(Order.moveVisible(order, ["a", "b", "c", "d"], "d", 0),
            ["d", "hidden", "a", "b", "c"]);
        compare(Order.moveVisible(order, ["a", "b", "c", "d"], "hidden", 0), order);
        compare(Order.moveVisible(order, ["a", "b", "c", "d"], "a", -1), order);
        compare(order, ["a", "hidden", "b", "c", "d"]);
    }
    function test_row_snapping() {
        compare(Order.snapOffset(45, 80, 160), 80);
        compare(Order.snapOffset(19, 80, 160), 0);
        compare(Order.snapOffset(158, 80, 160), 160);
        compare(Order.snapOffset(73, 80, 74), 74);
        compare(Order.snapOffset(50, 80, 0), 0);
        compare(Order.clampOffset(500, 160), 160);
    }
    function test_partial_final_row() {
        compare(Order.slotAt(30, 10, 300, 80, 7), 0);
        compare(Order.slotAt(150, 90, 300, 80, 7), 4);
        compare(Order.slotAt(290, 170, 300, 80, 7), 6);
        compare(Order.slotAt(-1, 20, 300, 80, 7), -1);
        compare(Order.slotAt(300, 20, 300, 80, 7), -1);
    }
}
