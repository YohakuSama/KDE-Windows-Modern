#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Keep every taskbar frame on the same geometry, masks and material policy."""
import argparse
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
MATERIALS = {
    "dark": ("#1C1C1C", "0.88"),
    "light": ("#F3F3F3", "0.94"),
}
POSITIONS = ("center", "top", "bottom", "left", "right", "topleft",
             "topright", "bottomleft", "bottomright")


def render(solid, mode):
    fill, alpha = MATERIALS[mode]
    token = "opacity:1;fill:" + fill
    if solid.count(token) != 3:
        raise ValueError("Unexpected panel paint structure")
    ids = {element.get("id") for element in ET.fromstring(solid).iter()}
    if not set(POSITIONS).issubset(ids) or not {"mask-" + p for p in POSITIONS}.issubset(ids):
        raise ValueError("Missing frame or blur mask geometry")
    return solid.replace(token, "opacity:" + alpha + ";fill:" + fill)


def write_frames(directory, mode, check=False):
    role = "widgets/panel-background.svg"
    solid = (directory / "solid" / role).read_text(encoding="utf-8")
    expected = render(solid, mode)
    for target in (directory / role, directory / "translucent" / role):
        if check:
            if not target.is_file() or target.read_text(encoding="utf-8") != expected:
                raise ValueError("Panel material drift: " + str(target))
        else:
            target.write_text(expected, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--directory", type=Path, help="Complete renderer package directory")
    parser.add_argument("--mode", choices=tuple(MATERIALS), default="dark")
    args = parser.parse_args()
    if args.mode == "light" and args.directory is None:
        parser.error("Light renderer frames require an explicit staged directory")
    # Regenerate the editable atlas in a source checkout, not its mirror.
    source = ("platform/plasma/appearance/atlas/Windows-modern-dark"
              if (ROOT / "core/source-map.json").is_file() else
              "plasma/desktoptheme/Windows-modern-dark")
    directory = args.directory or ROOT / source
    try:
        write_frames(directory, args.mode, args.check)
    except ValueError as error:
        parser.exit(1, str(error) + "\n")
    print(f"{args.mode.capitalize()} taskbar material variants and native masks are consistent.")


if __name__ == "__main__":
    main()
