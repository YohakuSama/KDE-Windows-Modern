#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Configure the real Desktop containment's right-click plugin while the shell is stopped."""
import argparse
import configparser
import os
from pathlib import Path
import subprocess

PLUGIN = "org.kde.windowsmodern.contextmenu"
GROUP = "ActionPlugins][0"
KEY = "RightButton;NoModifier"


def read_config(path):
    config = configparser.ConfigParser(interpolation=None, delimiters=("=",),
                                       comment_prefixes=("#",), strict=False)
    config.optionxform = str
    if path.exists():
        config.read(path, encoding="utf-8")
    return config


def find_defaults(preferred):
    if preferred.is_file():
        return preferred
    roots = os.environ.get("XDG_DATA_DIRS") or "/run/current-system/sw/share:/usr/local/share:/usr/share"
    for root in roots.split(os.pathsep):
        candidate = Path(root) / "plasma/shells/org.kde.plasma.desktop/contents/defaults"
        if candidate.is_file():
            return candidate
    raise RuntimeError("Native desktop containment action defaults unavailable")


def changes(layout, stock_defaults):
    config = read_config(layout)
    if config.has_section(GROUP):
        # Keep all existing middle-click/wheel/other gesture bindings.
        return {KEY: PLUGIN}
    defaults = read_config(find_defaults(stock_defaults))
    group = "Desktop][ContainmentActions"
    if not defaults.has_section(group):
        raise RuntimeError("Native desktop containment action defaults unavailable")
    result = dict(defaults.items(group))
    if KEY not in result:
        raise RuntimeError("Native desktop right-click action unavailable")
    result[KEY] = PLUGIN
    return result


def patch_defaults(source, destination):
    """Preserve all distribution defaults, replacing only the desktop right click."""
    lines = source.read_text(encoding="utf-8").splitlines(keepends=True)
    group = ""
    matches = 0
    for index, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            group = stripped
        elif group == "[Desktop][ContainmentActions]" and stripped.split("=", 1)[0].strip() == KEY:
            lines[index] = KEY + "=" + PLUGIN + "\n"
            matches += 1
    if matches != 1:
        raise RuntimeError("Expected exactly one desktop right-click default")
    if destination.is_symlink():
        raise RuntimeError("Refusing to modify the stock shell through a symlink")
    destination.write_text("".join(lines), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--layout", type=Path)
    parser.add_argument("--defaults", type=Path)
    parser.add_argument("--patch-defaults", nargs=2, type=Path, metavar=("SOURCE", "DESTINATION"))
    args = parser.parse_args()
    if args.patch_defaults:
        if args.layout or args.defaults:
            parser.error("--patch-defaults cannot be combined with layout editing")
        patch_defaults(*args.patch_defaults)
        return
    if args.layout is None or args.defaults is None:
        parser.error("--layout and --defaults are required")
    for key, value in changes(args.layout, args.defaults).items():
        subprocess.run(["kwriteconfig6", "--file", str(args.layout), "--group",
                        "ActionPlugins", "--group", "0", "--key", key, value], check=True)
    print("Windows Modern: native desktop context menu selected")


if __name__ == "__main__":
    main()
