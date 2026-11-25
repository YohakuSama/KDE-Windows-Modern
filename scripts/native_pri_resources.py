# SPDX-License-Identifier: GPL-3.0-or-later
"""Read named, embedded assets from Windows PRI resource indexes.

This intentionally implements only the PRI sections needed for original
shell artwork: schema names, resource maps and embedded data items. It does
not resolve package-qualified or external resources.
"""
from pathlib import Path
import struct

MAX_PRI_BYTES = 128 * 1024 * 1024
SCHEMA_IDS = (b"[mrm_hschema]  \0", b"[mrm_hschemaex] ")
MAP_IDS = (b"[mrm_res_map__]\0", b"[mrm_res_map2_]\0")
DATA_ID = b"[mrm_dataitem] \0"


def _u16(data, offset):
    if offset < 0 or offset + 2 > len(data):
        raise ValueError("PRI field outside section")
    return struct.unpack_from("<H", data, offset)[0]


def _u32(data, offset):
    if offset < 0 or offset + 4 > len(data):
        raise ValueError("PRI field outside section")
    return struct.unpack_from("<I", data, offset)[0]


def _slice(data, offset, length, label):
    if offset < 0 or length < 0 or offset + length > len(data):
        raise ValueError("Invalid PRI " + label + " bounds")
    return data[offset:offset + length]


def _toc(data):
    if len(data) < 8 or not (data.startswith(b"mrm_pri") or data.startswith(b"mrm_prif")):
        raise ValueError("Not a Windows PRI resource index")
    head = _slice(data, 0, 32, "header")
    toc_at = _u32(head, 16)
    section_start = _u32(head, 20)
    count = _u16(head, 24)
    table = _slice(data, toc_at, count * 32, "section table")
    sections = []
    for index in range(count):
        entry = table[index * 32:(index + 1) * 32]
        size = _u32(entry, 28)
        if size < 40:
            raise ValueError("Invalid PRI section size")
        offset = section_start + _u32(entry, 24) + 32
        length = size - 40
        sections.append((entry[:16], _slice(data, offset, length, "section")))
    return sections


def _item_names(data, extended):
    if not data:
        return {}
    unique_len = _u16(data, 2)
    name_len = _u16(data, 4)
    at = 8
    names_x = False
    if extended:
        marker = _slice(data, at, 16, "schema name marker")
        if marker == b"[def_hnamesx]  \0":
            names_x = True
        elif marker != b"[def_hnames]   \0":
            raise ValueError("Unknown PRI schema name table")
        at += 16
    scopes = _u32(data, at + 12)
    items = _u32(data, at + 16)
    at += 20 + (unique_len + name_len) * 2 + 2
    unicode_len = _u32(data, at + 16)
    ascii_len = _u32(data, at + 24) if names_x else 0
    at += 28 if names_x else 24
    nodes = scopes + items
    infos = at
    unicode_at = infos + nodes * 12 + scopes * 8 + items * 2
    ascii_at = unicode_at + unicode_len * 2
    _slice(data, infos, nodes * 12, "schema nodes")
    _slice(data, unicode_at, unicode_len * 2, "schema Unicode names")
    _slice(data, ascii_at, ascii_len, "schema ASCII names")

    all_nodes = []
    for index in range(nodes):
        node_at = infos + index * 12
        flags = data[node_at + 7]
        offset = _u16(data, node_at + 8) | ((flags & 0x0F) << 16)
        named = _u16(data, node_at + 2) != 0
        name = ""
        if named and flags & 0x20:
            raw = _slice(data, ascii_at + offset, ascii_len - offset, "ASCII name")
            end = raw.find(b"\0")
            if end < 0:
                raise ValueError("Unterminated PRI ASCII name")
            name = raw[:end].decode("utf-8", errors="strict")
        elif named:
            start = unicode_at + offset * 2
            raw = _slice(data, start, (unicode_at + unicode_len * 2) - start, "Unicode name")
            units = []
            for pos in range(0, len(raw) - 1, 2):
                unit = _u16(raw, pos)
                if unit == 0:
                    break
                units.append(unit)
            else:
                raise ValueError("Unterminated PRI Unicode name")
            name = bytes().join(struct.pack("<H", unit) for unit in units).decode("utf-16le")
        all_nodes.append({
            "parent": _u16(data, node_at),
            "named": named,
            "scope": bool(flags & 0x10),
            "index": _u16(data, node_at + 10),
            "name": name,
        })

    def node_path(index):
        parts = []
        seen = set()
        for _ in range(64):
            if index < 0 or index >= len(all_nodes) or index in seen:
                raise ValueError("Invalid PRI schema parent chain")
            seen.add(index)
            node = all_nodes[index]
            if node["named"]:
                parts.append(node["name"])
            parent = node["parent"]
            if parent == index:
                break
            index = parent
        else:
            raise ValueError("PRI schema parent chain is too deep")
        return "\\".join(reversed(parts))

    return {
        node["index"]: node_path(index)
        for index, node in enumerate(all_nodes)
        if not node["scope"]
    }


def _first_data(data, wanted):
    env_len = _u16(data, 0)
    schema_ref_len = _u16(data, 6)
    type_count = _u16(data, 10)
    to_group_count = _u16(data, 12)
    group_count = _u16(data, 14)
    info_count = _u32(data, 16)
    candidate_count = _u32(data, 20)
    large_len = _u32(data, 28)
    at = 32 + env_len + schema_ref_len

    type_table = [
        _u32(data, at + index * 8 + 4)
        for index in range(type_count)
    ]
    at += type_count * 8
    to_groups = [
        (_u16(data, at + index * 4), _u16(data, at + index * 4 + 2))
        for index in range(to_group_count)
    ]
    at += to_group_count * 4
    groups = [
        (_u16(data, at + index * 4), _u16(data, at + index * 4 + 2))
        for index in range(group_count)
    ]
    at += group_count * 4
    infos = [
        _u16(data, at + index * 4 + 2)
        for index in range(info_count)
    ]
    at += info_count * 4

    if large_len:
        large = _slice(data, at, large_len, "large resource map")
        n_to = _u32(large, 0)
        n_groups = _u32(large, 4)
        n_infos = _u32(large, 8)
        pos = 12
        for _ in range(n_to):
            to_groups.append((_u32(large, pos), _u32(large, pos + 4)))
            pos += 8
        for _ in range(n_groups):
            groups.append((_u32(large, pos), _u32(large, pos + 4)))
            pos += 8
        for _ in range(n_infos):
            infos.append(_u32(large, pos + 4))
            pos += 8
        if pos > len(large):
            raise ValueError("Invalid PRI large resource map")
    at += large_len
    candidates = _slice(data, at, candidate_count * 8, "resource candidates")

    found = {}
    for first_item, group_index in to_groups:
        if group_index < len(groups):
            size, first_info = groups[group_index]
        else:
            size, first_info = 1, group_index - len(groups)
        for info_index in range(first_info, first_info + size):
            item = first_item + (info_index - first_info)
            if item not in wanted or info_index >= len(infos):
                continue
            candidate_at = infos[info_index] * 8
            candidate = _slice(candidates, candidate_at, 8, "resource candidate")
            type_index = candidate[1]
            if type_index >= len(type_table):
                raise ValueError("Invalid PRI candidate type")
            # Candidate 1 is kept in this PRI; type 2 is EmbeddedData.
            if candidate[0] == 1 and type_table[type_index] == 2:
                found[wanted[item]] = (_u16(candidate, 6), _u16(candidate, 4))
    return found


def _data_item(section, item):
    strings = _u16(section, 4)
    blobs = _u16(section, 6)
    data_at = 12 + strings * 4 + blobs * 8
    if item < strings:
        entry = _slice(section, 12 + item * 4, 4, "string entry")
        offset, length = struct.unpack("<HH", entry)
    elif item < strings + blobs:
        entry_at = 12 + strings * 4 + (item - strings) * 8
        entry = _slice(section, entry_at, 8, "blob entry")
        offset, length = struct.unpack("<II", entry)
    else:
        raise ValueError("PRI data item index outside section")
    return _slice(section, data_at + offset, length, "data item")


def embedded_resources(data, names):
    """Return the first embedded data item for each requested resource path."""
    if len(data) > MAX_PRI_BYTES:
        raise ValueError("PRI resource index exceeds size limit")
    sections = _toc(data)
    wanted = [name.replace("/", "\\").casefold() for name in names]
    result = [None] * len(wanted)

    for section_id, content in sections:
        if section_id not in MAP_IDS:
            continue
        schema_index = _u16(content, 4)
        if schema_index >= len(sections):
            raise ValueError("PRI resource map references an invalid schema")
        schema_id, schema_content = sections[schema_index]
        if schema_id not in SCHEMA_IDS:
            continue
        names_by_index = _item_names(schema_content, schema_id == SCHEMA_IDS[1])
        item_wanted = {}
        for item, name in names_by_index.items():
            normalized = name.replace("/", "\\").casefold()
            for wanted_index, target in enumerate(wanted):
                if normalized == target or normalized.endswith("\\" + target):
                    item_wanted[item] = wanted_index
                    break
        if not item_wanted:
            continue
        found = _first_data(content, item_wanted)
        for wanted_index, (data_section_index, data_item_index) in found.items():
            if data_section_index >= len(sections):
                raise ValueError("PRI candidate references an invalid data section")
            data_id, data_content = sections[data_section_index]
            if data_id != DATA_ID:
                continue
            if result[wanted_index] is None:
                result[wanted_index] = _data_item(data_content, data_item_index)
    return result


def embedded_resources_from_file(path, names):
    path = Path(path)
    size = path.stat().st_size
    if size > MAX_PRI_BYTES:
        raise ValueError("PRI resource index exceeds size limit")
    return embedded_resources(path.read_bytes(), names)
