.pragma library

// Keep the complete order, including temporarily unavailable hardware and
// user-disabled tiles. Unknown and repeated saved keys are ignored.
function normalizeOrder(saved, known) {
    const order = [];
    for (const key of saved.concat(known)) {
        if (known.indexOf(key) >= 0 && order.indexOf(key) < 0)
            order.push(key);
    }
    return order;
}

function visibleOrder(order, available) {
    return order.filter(key => available.indexOf(key) >= 0);
}

function moveVisible(order, available, key, to) {
    const visible = visibleOrder(order, available);
    const from = visible.indexOf(key);
    if (from < 0 || to < 0 || to >= visible.length || from === to)
        return order.slice();
    visible.splice(from, 1);
    visible.splice(to, 0, key);
    let index = 0;
    return order.map(k => available.indexOf(k) >= 0 ? visible[index++] : k);
}

function clampOffset(offset, maximum) {
    return Math.max(0, Math.min(Math.max(0, maximum), offset));
}

function snapOffset(offset, stride, maximum) {
    if (stride <= 0 || maximum <= 0)
        return 0;
    const position = clampOffset(offset, maximum);
    const row = clampOffset(Math.round(position / stride) * stride, maximum);
    return Math.abs(maximum - position) < Math.abs(row - position) ? maximum : row;
}

function columnX(index, cellWidth, gap, mirrored = false) {
    const column = index % 3;
    return (mirrored ? 2 - column : column) * (cellWidth + gap);
}

function slotAt(x, y, width, stride, count, gap = 0, mirrored = false) {
    if (count <= 0 || width <= 0 || stride <= 0 || x < 0 || x >= width || y < 0)
        return -1;
    const pitch = (width + gap) / 3;
    const physicalColumn = Math.min(2, Math.floor((x + gap / 2) / pitch));
    const column = mirrored ? 2 - physicalColumn : physicalColumn;
    return Math.min(count - 1, Math.floor(y / stride) * 3 + column);
}

