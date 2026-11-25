#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Configure the real Desktop containment's right-click plugin while the shell is stopped."""
import argparse
import configparser
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


def changes(layout, stock_defaults):
    config = read_config(layout)
    if config.has_section(GROUP):
        # Keep all existing middle-click/wheel/other gesture bindings.
        return {KEY: PLUGIN}
    defaults = read_config(stock_defaults)
    group = "Desktop][ContainmentActions"
    if not defaults.has_section(group):
        raise RuntimeError("Native desktop containment action defaults unavailable")
    result = dict(defaults.items(group))
    if KEY not in result:
        raise RuntimeError("Native desktop right-click action unavailable")
    result[KEY] = PLUGIN
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--layout", type=Path, required=True)
    parser.add_argument("--defaults", type=Path, required=True)
    args = parser.parse_args()
    for key, value in changes(args.layout, args.defaults).items():
        subprocess.run(["kwriteconfig6", "--file", str(args.layout), "--group",
                        "ActionPlugins", "--group", "0", "--key", key, value], check=True)
    print("Windows Modern: native desktop context menu selected")


if __name__ == "__main__":
    main()
