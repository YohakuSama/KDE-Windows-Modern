#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Reject stale or mixed Plasma plugin mappings, even with identical filenames."""
import argparse
import os
from pathlib import Path
import sys


def verify_plugin(path, token, maps=None):
    expected = Path(path).resolve(strict=True)
    if token.encode() not in expected.read_bytes():
        raise RuntimeError(f"ELF is missing this build's token: {expected}")
    if maps is None:
        return expected
    st = expected.stat()
    matched = False
    seen = []
    for line in maps.splitlines():
        fields = line.split(maxsplit=5)
        if len(fields) != 6:
            continue
        address, perms, offset, device, inode, mapped = fields
        clean = mapped.removesuffix(" (deleted)")
        if Path(clean).name != expected.name:
            continue
        seen.append(mapped)
        if mapped != clean or not clean.startswith("/"):
            raise RuntimeError(f"Deleted or invalid loaded plugin: {mapped}")
        resolved = Path(clean).resolve()
        major, minor = (int(x, 16) for x in device.split(":"))
        if (resolved != expected or int(inode) != st.st_ino
                or (major, minor) != (os.major(st.st_dev), os.minor(st.st_dev))):
            raise RuntimeError(f"Wrong plugin loaded: {mapped}; expected {expected}")
        matched = True
    if not matched:
        raise RuntimeError(f"New plugin not loaded: {expected}; found {seen}")
    return expected


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--tray-token", required=True)
    p.add_argument("--tasks-token", required=True)
    p.add_argument("--tray", required=True, type=Path)
    p.add_argument("--tasks", required=True, type=Path)
    p.add_argument("--pid", type=int)
    p.add_argument("--quiet", action="store_true")
    args = p.parse_args()
    try:
        if args.pid is not None and args.pid <= 0:
            raise RuntimeError("Plasma has no valid PID")
        maps = Path(f"/proc/{args.pid}/maps").read_text() if args.pid is not None else None
        if args.pid is not None:
            env = Path(f"/proc/{args.pid}/environ").read_bytes().split(b"\0")
            if b"QML_DISABLE_DISK_CACHE=1" not in env:
                raise RuntimeError("Plasma is not running with the test QML disk cache disabled")
        for label, path, token in (("systemtray", args.tray, args.tray_token),
                                   ("icontasks", args.tasks, args.tasks_token)):
            resolved = verify_plugin(path, token, maps)
            if not args.quiet:
                print(f"{label} {'LOADED' if maps is not None else 'BUILT'}: {resolved}")
    except (OSError, ValueError, RuntimeError) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
