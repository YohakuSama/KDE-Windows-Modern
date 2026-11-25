#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Reject fatal Windows Modern QML entrypoint errors in the new shell's journal."""
import re
import sys

APPLET = re.compile(r"(?:org\.kde\.windowsmodern\.|org/kde/windowsmodern/)")
FATAL = re.compile(
    r"Cannot assign (?:object|to non-existent property)|"
    r"Type\s+\S+\s+unavailable|is not a type|"
    r"module\s+.+\s+is not installed|"
    r"Invalid property assignment|Expected token|"
    r"Error loading QML|Failed to load (?:QML|component)|"
    r"No such file or directory",
    re.IGNORECASE,
)


def fatal_lines(lines):
    return [line.rstrip() for line in lines if APPLET.search(line) and FATAL.search(line)]


def main():
    errors = fatal_lines(sys.stdin)
    if errors:
        print("Windows Modern: fatal applet QML errors in the new shell:", file=sys.stderr)
        print("\n".join(errors), file=sys.stderr)
        return 1
    print("Windows Modern: no matching fatal applet QML errors in the new shell journal")
    return 0


if __name__ == "__main__":
    sys.exit(main())
