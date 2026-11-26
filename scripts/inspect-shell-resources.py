#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Inventory a local Windows shell package and extract verified original icon frames and fonts."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import struct

from fontTools.ttLib import TTCollection, TTFont, TTLibError
from native_pe_resources import pe_resources

SHELL_MODULES = {"systemtray.dll", "taskbar.view.dll"}
MODULES = {name + suffix for name in SHELL_MODULES for suffix in ("", ".mui", ".mun")}
MODULES.update({"imageres.dll.mun", "imagesp1.dll.mun", "shell32.dll.mun"})
FONT_SIGNATURES = (b"\0\1\0\0", b"OTTO", b"ttcf", b"wOFF", b"wOF2")
SHELL_DATA = {".pri", ".xbf", ".xaml"}


def digest(blob):
    return hashlib.sha256(blob).hexdigest()


def font_info(data):
    source = io.BytesIO(data)
    faces = TTCollection(source, lazy=True).fonts if data.startswith(b"ttcf") else [TTFont(source, lazy=True)]
    try:
        results = []
        for face in faces:
            names = sorted({n.toUnicode() for n in face["name"].names if n.nameID in (1, 16)})
            record = {"families": names}
            if any(name.casefold().strip() == "sysbatt fluent icons" for name in names):
                record["codepoints"] = sorted((face.getBestCmap() or {}).keys())
            results.append(record)
        return results
    finally:
        for face in faces:
            face.close()


def icon_group(resources, key):
    group = resources[key]
    reserved, kind, count = struct.unpack_from("<HHH", group)
    if reserved or kind != 1 or not count or len(group) != 6 + count * 14:
        raise ValueError("Invalid group directory")
    directory = bytearray(group[:6])
    frames = []
    payloads = []
    offset = 6 + 16 * count
    for n in range(count):
        pos = 6 + n * 14
        size, rid = struct.unpack_from("<IH", group, pos + 8)
        matches = [k for k in resources if k[:2] == (3, rid)]
        frame_key = (3, rid, key[2])
        if frame_key not in resources:
            if len(matches) != 1:
                raise ValueError(f"Missing or ambiguous RT_ICON {rid} for language {key[2]}")
            frame_key = matches[0]
        frame = resources[frame_key]
        if not size or size != len(frame):
            raise ValueError(f"Invalid frame length for RT_ICON {rid}")
        directory += group[pos:pos+12] + struct.pack("<I", offset)
        frames.append({"id": rid, "language": frame_key[2], "width": group[pos] or 256,
                       "height": group[pos+1] or 256, "sha256": digest(frame)})
        payloads.append(frame)
        offset += size
    return bytes(directory) + b"".join(payloads), frames


def note_font(blob, target, output):
    faces = font_info(blob)
    target["faces"] = faces
    if any("codepoints" in face for face in faces):
        folder = output / "fonts"
        folder.mkdir(exist_ok=True)
        ext = {b"ttcf": ".ttc", b"OTTO": ".otf", b"wOF2": ".woff2", b"wOFF": ".woff"}.get(blob[:4], ".ttf")
        dest = folder / (digest(blob) + ext)
        dest.write_bytes(blob)
        target["original_font"] = dest.relative_to(output).as_posix()


def scan(source, output):
    source = source.resolve(strict=True)
    if not source.is_dir():
        raise ValueError("Provide an extracted Windows or SystemApps directory")
    output = output.resolve()
    if output.is_relative_to(source):
        raise ValueError("Choose a separate output directory")
    output.mkdir(mode=0o700, parents=True, exist_ok=False)
    records, issues = [], []
    for path in sorted(source.rglob("*")):
        suffix = path.suffix.lower()
        module = path.name.lower() in MODULES
        if path.is_symlink() or not path.is_file() or not (module or suffix in SHELL_DATA | {".otf", ".ttf", ".ttc"}):
            continue
        name = path.relative_to(source).as_posix()
        data = path.read_bytes()
        record = {"path": name, "sha256": digest(data), "bytes": len(data)}
        records.append(record)
        try:
            if module:
                resources = pe_resources(data, named=True)
                record["groups"], record["embedded_fonts"] = [], []
                for key, raw in resources.items():
                    if len(key) != 3:
                        continue
                    if key[0] == 14:
                        try:
                            ico, frames = icon_group(resources, key)
                        except (ValueError, struct.error) as exc:
                            issues.append({"path": name, "resource": key, "error": str(exc)})
                            continue
                        dest = output / "icons" / (digest(ico) + ".ico")
                        dest.parent.mkdir(exist_ok=True)
                        dest.write_bytes(ico)
                        record["groups"].append({"id": key[1], "language": key[2], "frames": frames,
                                                 "ico": dest.relative_to(output).as_posix()})
                    elif raw.startswith(FONT_SIGNATURES):
                        candidate = {"resource": key, "sha256": digest(raw)}
                        try:
                            note_font(raw, candidate, output)
                            record["embedded_fonts"].append(candidate)
                        except (ValueError, KeyError, TTLibError, struct.error):
                            continue  # Image data can start with a font signature.
            elif suffix in SHELL_DATA:
                record["format"] = suffix[1:]
                term = "SysBatt Fluent Icons"
                record["contains_family_string"] = any(term.encode(enc) in data for enc in ("utf-8", "utf-16le"))
            else:
                note_font(data, record, output)
        except (ValueError, KeyError, TTLibError, struct.error) as exc:
            issues.append({"path": name, "error": str(exc)})
    (output / "inventory.json").write_text(json.dumps({"files": records, "issues": issues}, ensure_ascii=False, indent=2) + "\n")
    return issues


def draw_review_glyph(tile, font, code, area_height):
    """Draw one FreeType mask, without text shaping or multiline interpretation."""
    from PIL import Image

    mask = font.getmask(chr(code), mode="L")
    if not all(mask.size):
        return False
    bitmap = Image.frombytes("L", mask.size, bytes(mask))
    bounds = bitmap.getbbox()
    if bounds is None:
        return False
    bitmap = bitmap.crop(bounds)
    bitmap.thumbnail((tile.width - 4, area_height - 4), Image.Resampling.LANCZOS)
    x = (tile.width - bitmap.width) // 2
    y = (area_height - bitmap.height) // 2
    tile.paste((0, 0, 0), (x, y, x + bitmap.width, y + bitmap.height), bitmap)
    return True


def font_review(source, output):
    """Export review sheets and a metadata catalog, never the font files."""
    from PIL import Image, ImageDraw, ImageFont

    root = source.resolve(strict=True)
    output = output.resolve()
    if not root.is_dir() or output.is_relative_to(root):
        raise ValueError("Use an extracted Windows directory and a separate output directory")
    output.mkdir(mode=0o700, parents=True, exist_ok=False)
    wanted = {"segoeicons.ttf", "settingsicons.ttf", "axpicons.ttf"}
    candidates = {}
    records, issues = [], []
    for directory in ("Fonts", "SystemApps", "SystemResources"):
        for path in sorted((root / directory).rglob("*")):
            if (path.name.casefold() not in wanted or path.is_symlink()
                    or not path.is_file() or not path.resolve().is_relative_to(root)):
                continue
            try:
                data = path.read_bytes()
            except OSError as exc:
                issues.append({"path": path.relative_to(root).as_posix(), "error": str(exc)})
                continue
            key = digest(data)
            if key not in candidates:
                candidates[key] = {"data": data, "sources": []}
            candidates[key]["sources"].append(path.relative_to(root).as_posix())

    if not candidates:
        issues.append({"error": "No original Segoe, Settings or AXP icon fonts found"})
    columns, rows_per_page = 12, 12
    cell_width, cell_height = 84, 76
    label_font = ImageFont.load_default()
    for sha, candidate in sorted(candidates.items()):
        record = {"sha256": sha, "sources": candidate["sources"], "pages": [],
                  "blank_glyphs": [], "failed_glyphs": []}
        records.append(record)
        try:
            with TTFont(io.BytesIO(candidate["data"])) as font:
                record["families"] = sorted({name.toUnicode() for name in font["name"].names
                                             if name.nameID in (1, 16)})
                glyphs = sorted((font.getBestCmap() or {}).items())
            glyphs = [(code, name) for code, name in glyphs
                      if 0 <= code <= 0x10ffff and not 0xd800 <= code <= 0xdfff]
            if not glyphs:
                raise ValueError("No Unicode glyph mapping")
            record["glyphs"] = {f"U+{code:04X}": name for code, name in glyphs}
            # A review tile is a single cmap entry. RAQM shaping is neither
            # needed nor desirable for control and private-use code points.
            preview_font = ImageFont.truetype(io.BytesIO(candidate["data"]), 36,
                                              layout_engine=ImageFont.Layout.BASIC)
            page_size = columns * rows_per_page
            directory = output / sha
            directory.mkdir()
            for page, start in enumerate(range(0, len(glyphs), page_size), 1):
                chunk = glyphs[start:start + page_size]
                height = ((len(chunk) + columns - 1) // columns) * cell_height
                image = Image.new("RGB", (columns * cell_width, height), "white")
                for index, (code, name) in enumerate(chunk):
                    # Keep the codepoint label and the rest of the page even
                    # when a particular FreeType glyph cannot be rendered.
                    tile = Image.new("RGB", (cell_width, cell_height), "white")
                    draw = ImageDraw.Draw(tile)
                    codepoint = f"U+{code:04X}"
                    try:
                        if not draw_review_glyph(tile, preview_font, code, 52):
                            record["blank_glyphs"].append(codepoint)
                    except (RuntimeError, OSError, ValueError) as exc:
                        record["failed_glyphs"].append(codepoint)
                        issues.append({"sha256": sha, "codepoint": codepoint,
                                       "glyph": name, "error": str(exc)})
                        draw.text((cell_width / 2, 26), "ERROR", font=label_font,
                                  fill="black", anchor="mm")
                    draw.text((cell_width / 2, 64), f"{code:04X}",
                              font=label_font, fill="black", anchor="mm")
                    image.paste(tile, ((index % columns) * cell_width,
                                       (index // columns) * cell_height))
                dest = directory / f"page-{page:03d}.png"
                image.save(dest)
                record["pages"].append({"file": dest.relative_to(output).as_posix(),
                                        "first": f"U+{chunk[0][0]:04X}",
                                        "last": f"U+{chunk[-1][0]:04X}"})
        except (RuntimeError, OSError, ValueError, KeyError, TTLibError, struct.error) as exc:
            issues.append({"sha256": sha, "sources": candidate["sources"], "error": str(exc)})
    (output / "font-review.json").write_text(
        json.dumps({"fonts": records, "issues": issues}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8")
    return issues


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path, help="new private output directory")
    parser.add_argument("--font-review", action="store_true",
                        help="Create private deduplicated icon font glyph sheets and catalog (requires Pillow)")
    args = parser.parse_args()
    findings = (font_review(args.source, args.output) if args.font_review
                else scan(args.source, args.output))
    name = "font-review.json" if args.font_review else "inventory.json"
    print(f"Inventory: {args.output / name} ({len(findings)} issues)")
    raise SystemExit(bool(findings))
