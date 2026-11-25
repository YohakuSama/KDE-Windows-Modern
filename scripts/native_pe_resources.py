# SPDX-License-Identifier: GPL-3.0-or-later
"""Read numeric and named resources from a Windows PE image."""
import struct


def pe_resources(data, *, named=False):
    def u16(pos):
        return struct.unpack_from('<H', data, pos)[0]
    def u32(pos):
        return struct.unpack_from('<I', data, pos)[0]
    pe = u32(0x3c)
    if data[:2] != b'MZ' or data[pe:pe+4] != b'PE\0\0':
        raise ValueError('Not a PE resource library')
    opt = pe + 24
    magic = u16(opt)
    if magic not in (0x10b, 0x20b):
        raise ValueError('Unknown PE optional header')
    dd = opt + (112 if magic == 0x20b else 96)
    sections = []
    for i in range(u16(pe + 6)):
        p = opt + u16(pe + 20) + 40*i
        sections.append((u32(p+12), u32(p+16), u32(p+20)))
    def offset(rva):
        for addr, size, pos in sections:
            if addr <= rva < addr + size:
                return pos + rva - addr
        raise ValueError('Unmapped resource RVA')
    if not u32(dd+16):
        return {}
    base = offset(u32(dd+16))
    result = {}
    def walk(rel, path):
        if len(path) > 3:
            raise ValueError('Invalid resource tree depth')
        o = base + rel
        for i in range(u16(o+12) + u16(o+14)):
            name, child = struct.unpack_from('<II', data, o+16+8*i)
            if name & 0x80000000:
                if not named:
                    continue
                pos = base + (name & 0x7fffffff)
                end = pos + 2 + 2 * u16(pos)
                if end > len(data):
                    raise ValueError('Truncated resource name')
                name = data[pos+2:end].decode('utf-16le')
            key = path + (name,)
            if child & 0x80000000:
                walk(child & 0x7fffffff, key)
            else:
                rva, size = struct.unpack_from('<II', data, base+child)
                start = offset(rva)
                if start+size > len(data):
                    raise ValueError('Truncated resource')
                result[key] = data[start:start+size]
    walk(0, ())
    return result
