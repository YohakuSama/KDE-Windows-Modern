// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Windows groups alphabetic views by the first visible letter. Accented
// Latin letters share their base section; numbers and symbols use #.
// Keep native-script headings for other alphabets (no guessed pinyin).
function sectionForName(name) {
    const value = String(name || "").trim();
    if (!value.length) return "#";
    const letter = Array.from(value)[0];
    const base = letter.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    if (/^[A-Za-z]$/.test(base)) return base.toUpperCase();
    if (letter.toLowerCase() !== letter.toUpperCase()) return letter.toUpperCase();
    if (/^[\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]$/.test(letter)) return letter;
    return "#";
}

// A heading belongs to the first visual row in each section. Grid rows
// never borrow cells from another letter, even when the last row is short.
// The source row is preserved for activation and context menu actions.
function buildRows(entries, columns, alphabetical) {
    columns = Math.max(1, Math.floor(columns));
    const groups = [];
    const byLabel = Object.create(null);
    for (const entry of entries) {
        const label = alphabetical ? sectionForName(entry.display || entry.name) : "";
        let group = byLabel[label];
        if (!group) {
            group = { label: label, entries: [] };
            groups.push(group);
            byLabel[label] = group;
        }
        group.entries.push(entry);
    }
    const rows = [];
    for (const group of groups) {
        for (let offset = 0; offset < group.entries.length; offset += columns) {
            rows.push({
                heading: offset === 0 ? group.label : "",
                entries: group.entries.slice(offset, offset + columns)
            });
        }
    }
    return rows;
}

function locate(rows, sourceIndex) {
    for (let r = 0; r < rows.length; ++r) {
        const c = rows[r].entries.findIndex(entry => entry.index === sourceIndex);
        if (c >= 0) return {row: r, column: c};
    }
    return {row: -1, column: -1};
}

function verticalNeighbor(rows, sourceIndex, direction) {
    if (!rows.length) return -1;
    const pos = locate(rows, sourceIndex);
    if (pos.row < 0) return rows[0].entries[0].index;
    const row = Math.max(0, Math.min(rows.length - 1, pos.row + direction));
    return rows[row].entries[Math.min(pos.column, rows[row].entries.length - 1)].index;
}

function horizontalNeighbor(rows, sourceIndex, direction) {
    if (!rows.length) return -1;
    const pos = locate(rows, sourceIndex);
    if (pos.row < 0) return rows[0].entries[0].index;
    const entries = rows[pos.row].entries;
    const column = pos.column + direction;
    if (column >= 0 && column < entries.length) return entries[column].index;
    const row = pos.row + direction;
    if (row < 0 || row >= rows.length) return sourceIndex;
    const next = rows[row].entries;
    return next[direction < 0 ? next.length - 1 : 0].index;
}
