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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    for mode in MATERIALS:
        base = ROOT / "plasma/desktoptheme" / ("Windows-modern-" + mode)
        role = "widgets/panel-background.svg"
        solid = (base / "solid" / role).read_text(encoding="utf-8")
        expected = render(solid, mode)
        for target in (base / role, base / "translucent" / role):
            if args.check:
                if target.read_text(encoding="utf-8") != expected:
                    parser.exit(1, "Panel material drift: " + str(target) + "\n")
            else:
                target.write_text(expected, encoding="utf-8")
    print("Taskbar material variants and native masks are consistent.")


if __name__ == "__main__":
    main()
