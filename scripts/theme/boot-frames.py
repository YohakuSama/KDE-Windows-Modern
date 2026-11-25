#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build optional Plymouth artwork at packaging time, not in the initrd."""
import argparse
import math
from pathlib import Path
import shutil
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
FRAMES = 80
RING_SIZE = 48
LOGO_SIZE = 112
SUPERSAMPLE = 4

def ring_frame(index):
    size = RING_SIZE * SUPERSAMPLE
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    phase = index / FRAMES
    wave = (1 - math.cos(2 * math.pi * phase)) / 2
    start = -90 + 720 * phase
    sweep = 180 * (0.25 + 1.25 * wave)
    center = size / 2
    radius = 16 * SUPERSAMPLE
    stroke = 3 * SUPERSAMPLE
    # Pillow's arc stroke is inside the bounding ellipse.
    outer = radius + stroke / 2
    draw.arc((center-outer, center-outer, center+outer, center+outer),
             start, start+sweep, fill=(255,255,255,255), width=stroke)
    for angle in (start, start+sweep):
        radians = math.radians(angle)
        x = center + radius * math.cos(radians)
        y = center + radius * math.sin(radians)
        cap = stroke / 2
        draw.ellipse((x-cap, y-cap, x+cap, y+cap), fill=(255,255,255,255))
    return image.resize((RING_SIZE, RING_SIZE), Image.Resampling.LANCZOS)

def logo_frame():
    # A locally drawn flat four-pane compatibility logo.
    image = Image.new("RGBA", (LOGO_SIZE, LOGO_SIZE), (0,0,0,0))
    draw = ImageDraw.Draw(image)
    for x in (0, 58):
        for y in (0, 58):
            draw.rectangle((x, y, x+53, y+53), fill=(0,120,212,255))
    return image

def build(destination, image_dir=None):
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    runtime_dir = str(image_dir or destination.resolve())
    if "\n" in runtime_dir or "\r" in runtime_dir:
        raise ValueError("Invalid Plymouth path")
    logo_frame().save(destination / "logo.png")
    for index in range(FRAMES):
        ring_frame(index).save(destination / f"ring-{index}.png")
    shutil.copyfile(ROOT / "boot/plymouth/windows-modern.script",
                    destination / "windows-modern.script")
    (destination / "windows-modern.plymouth").write_text(
        "[Plymouth Theme]\nName=Windows Modern\n"
        "Description=Windows-style logo and loading ring\nModuleName=script\n\n"
        f"[script]\nImageDir={runtime_dir}\n"
        f"ScriptFile={runtime_dir}/windows-modern.script\n", encoding="utf-8")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--image-dir", help="Final installed theme path, for a staging build")
    args = parser.parse_args()
    build(args.destination, args.image_dir)
