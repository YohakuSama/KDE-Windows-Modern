#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Inventory a local Windows shell package and extract verified original icon frames and fonts."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import shutil
import struct
import tempfile
import xml.etree.ElementTree as ET

from fontTools.ttLib import TTCollection, TTFont, TTLibError
from native_pe_resources import pe_resources
from native_pri_resources import embedded_resources

SHELL_MODULES = {"systemtray.dll", "taskbar.view.dll"}
MODULES = {name + suffix for name in SHELL_MODULES for suffix in ("", ".mui", ".mun")}
MODULES.update({"imageres.dll.mun", "imagesp1.dll.mun", "shell32.dll.mun"})
FONT_SIGNATURES = (b"\0\1\0\0", b"OTTO", b"ttcf", b"wOFF", b"wOF2")
SHELL_DATA = {".pri", ".xbf", ".xaml"}
SEARCH_ICONS = {
    "searchicononlight.scale-100.png": "search/search-on-light.png",
    "searchiconofflight.scale-100.png": "search/search-off-light.png",
    "searchiconondark.scale-100.png": "search/search-on-dark.png",
    "searchiconoffdark.scale-100.png": "search/search-off-dark.png",
}
TASK_VIEW_RESOURCES = (
    "Files/SystemSettings/Assets/Taskview_Light.svg",
    "Files/SystemSettings/Assets/Taskview_Dark.svg",
)


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
    sysbatt = any(
        "codepoints" in face and
        any(name.casefold().strip() == "sysbatt fluent icons" for name in face["families"])
        for face in faces
    )
    if sysbatt:
        dest = output / "shell" / "fonts" / "Sysbatt.ttf"
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(blob)
        target["original_font"] = dest.relative_to(output).as_posix()
        target["shell_font"] = "shell/fonts/Sysbatt.ttf"
    elif any("codepoints" in face for face in faces):
        folder = output / "fonts"
        folder.mkdir(exist_ok=True)
        ext = {b"ttcf": ".ttc", b"OTTO": ".otf", b"wOF2": ".woff2", b"wOFF": ".woff"}.get(blob[:4], ".ttf")
        dest = folder / (digest(blob) + ext)
        dest.write_bytes(blob)
        target["original_font"] = dest.relative_to(output).as_posix()


def write_shell_asset(output, assets, role, source, relative, content, kind):
    if not content:
        return
    if kind == "png":
        if (len(content) < 33 or content[:8] != b"\x89PNG\r\n\x1a\n"
                or content[12:16] != b"IHDR" or struct.unpack_from(">I", content, 8)[0] != 13):
            raise ValueError("Invalid original PNG shell asset: " + source)
        width, height = struct.unpack_from(">II", content, 16)
        if not (1 <= width <= 4096 and 1 <= height <= 4096):
            raise ValueError("Invalid PNG dimensions: " + source)
    elif kind == "svg":
        try:
            root = ET.fromstring(content)
        except ET.ParseError as exc:
            raise ValueError("Invalid original SVG shell asset: " + source) from exc
        if root.tag.rsplit("}", 1)[-1].lower() != "svg":
            raise ValueError("Expected an SVG root element: " + source)
    else:
        raise ValueError("Unknown shell asset type: " + kind)

    dest = output / relative
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(content)
    assets.append({
        "role": role,
        "source": source,
        "output": relative,
        "bytes": len(content),
        "sha256": digest(content),
        "format": kind,
    })


def install_shell_assets(output):
    output = output.resolve(strict=True)
    inventory = json.loads((output / "inventory.json").read_text(encoding="utf-8"))
    assets = inventory.get("shell_assets", [])
    if not assets:
        raise ValueError("No recognized Windows 11 shell assets were extracted")

    import os
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    data_home = data_home.expanduser().resolve()
    parent = data_home / "windows-modern" / "native-assets"
    destination = parent / "shell"
    parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=".shell-assets-", dir=parent))
    backup = None
    try:
        installed = []
        for asset in assets:
            relative = Path(asset["output"])
            if relative.is_absolute() or ".." in relative.parts or relative.parts[:1] != ("shell",):
                raise ValueError("Unsafe shell asset output path")
            source = (output / relative).resolve(strict=True)
            if (not source.is_relative_to(output) or source.is_symlink()
                    or not source.is_file() or digest(source.read_bytes()) != asset["sha256"]):
                raise ValueError("Shell asset hash/path verification failed: " + str(relative))
            target = stage.joinpath(*relative.parts[1:])
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            installed.append({**asset, "installed": target.relative_to(stage).as_posix()})
        (stage / "manifest.json").write_text(
            json.dumps({"assets": installed}, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        if destination.exists():
            backup = parent / ".shell-assets-backup"
            if backup.exists():
                shutil.rmtree(backup)
            destination.rename(backup)
        stage.rename(destination)
        if backup is not None:
            shutil.rmtree(backup)
    except Exception:
        if backup is not None and backup.exists() and not destination.exists():
            backup.rename(destination)
        raise
    finally:
        if stage.exists():
            shutil.rmtree(stage)
    print("Installed verified Windows shell assets into " + str(destination))


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


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path, help="new private output directory")
    args = parser.parse_args()
    findings = scan(args.source, args.output)
    print(f"Inventory: {args.output / 'inventory.json'} ({len(findings)} issues)")
    raise SystemExit(bool(findings))
