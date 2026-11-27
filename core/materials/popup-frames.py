#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Generate the shared Plasma popup frames without a runtime dependency."""
import argparse
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = Path(__file__).with_name("popup-frame.svg.in")
POSITIONS = ("center", "top", "bottom", "left", "right", "topleft",
             "topright", "bottomleft", "bottomright")


def render(template, mode, role, variant):
    dialog = role == "dialogs/background.svg"
    r = 8 if dialog else 4
    acrylic = dialog and variant == "translucent"
    # Light shell values sampled from the Windows reference. The same
    # neutral tint is used by the opaque fallback and acrylic variant.
    # Keep tooltip geometry and material separate.
    if dialog:
        fill = "#202020" if mode == "dark" else "#F2F2F2"
        opacity = ("0.95" if mode == "dark" else "0.97") if acrylic else "1"
        border = "#383838" if mode == "dark" else "#DCDCDC"
    else:
        fill = "#2C2C2C" if mode == "dark" else "#F9F9F9"
        opacity = "1"
        border = "#3F3F3F" if mode == "dark" else "#E5E5E5"
    a, b, far = 4+r, 4+r+48, 4+2*r+48
    sr, send = r+12, 2*(r+12)+48
    values = dict(R=r, I=r-1, A=a, B=b, FAR=far, SR=sr,
                  SA=84+sr, SB=84+send-12, SX=send-12,
                  SEND=send, SYEND=84+send,
                  FILL=f'fill="{fill}" fill-opacity="{opacity}"',
                  BORDER=border)
    # Content padding is independent of the nine-slice corner geometry.
    # WinUI DefaultToolTipStyle directly references ToolTipBorderPadding.
    top, bottom, left, right = (r, r, r, r) if dialog else (6, 8, 9, 9)
    values.update(MT=top, MB=bottom, ML=left, MR=right)
    result = re.sub(r"@([A-Z]+)@", lambda m: str(values[m[1]]), template)
    # Validate unique required frame IDs and masks for KSVG.
    root = ET.fromstring(result)
    ids = [node.attrib["id"] for node in root.iter() if "id" in node.attrib]
    required = set(POSITIONS) | {"mask-"+p for p in POSITIONS}
    required |= {"shadow-"+p for p in POSITIONS if p != "center"}
    required |= {"hint-stretch-borders"} | {
        prefix+"hint-"+side+"-margin"
        for prefix in ("", "shadow-")
        for side in ("left", "right", "top", "bottom")
    }
    if len(ids) != len(set(ids)) or not required.issubset(ids):
        raise ValueError("Duplicate or missing frame element IDs")
    return result


def write_frames(directory, mode, check=False):
    template = TEMPLATE.read_text(encoding="utf-8")
    stale = []
    for role in ("dialogs/background.svg", "widgets/tooltip.svg"):
        for variant in ("", "solid", "translucent"):
            path = directory / variant / role
            expected = render(template, mode, role, variant)
            if check:
                if not path.is_file() or path.read_text(encoding="utf-8") != expected:
                    stale.append(str(path))
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(expected, encoding="utf-8")
    if stale:
        raise ValueError("Regenerate popup frames: " + ", ".join(stale))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--directory", type=Path, help="Complete renderer package directory")
    parser.add_argument("--mode", choices=("dark", "light"), default="dark")
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
    print(f"6 {args.mode} popup frames: geometry and element IDs consistent.")


if __name__ == "__main__":
    main()
