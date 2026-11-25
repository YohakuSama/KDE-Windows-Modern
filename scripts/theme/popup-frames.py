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
        opacity = ("0.94" if mode == "dark" else "0.96") if acrylic else "1"
        border = "#3C3C3C" if mode == "dark" else "#DCDCDC"
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    template = TEMPLATE.read_text(encoding="utf-8")
    stale = []
    for mode in ("dark", "light"):
        for role in ("dialogs/background.svg", "widgets/tooltip.svg"):
            for variant in ("", "solid", "translucent"):
                path = ROOT / "plasma/desktoptheme" / ("Windows-modern-"+mode) / variant / role
                expected = render(template, mode, role, variant)
                if args.check:
                    if not path.is_file() or path.read_text(encoding="utf-8") != expected:
                        stale.append(str(path.relative_to(ROOT)))
                else:
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text(expected, encoding="utf-8")
    if stale:
        parser.exit(1, "Regenerate popup frames: " + ", ".join(stale) + "\n")
    print("12 popup frames: geometry and element IDs consistent.")


if __name__ == "__main__":
    main()
