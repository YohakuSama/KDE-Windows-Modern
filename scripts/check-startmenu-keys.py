#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Reject nonexistent Qt Quick Keys attached signals before installation."""
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
START = ROOT / "plasma/applets/org.kde.windowsmodern.startmenu/contents/ui"
# Qt Quick Keys signal list (Qt 6): Home, End and PageUp/PageDown are
# intentionally not dedicated signals. They use Keys.onPressed + Qt.Key_*.
ALLOWED = {
    "AsteriskPressed", "BackPressed", "BacktabPressed", "CallPressed",
    "CancelPressed", "Context1Pressed", "Context2Pressed", "Context3Pressed",
    "Context4Pressed", "DeletePressed", "DownPressed", "EnterPressed",
    "EscapePressed", "FlipPressed", "HangupPressed", "LeftPressed",
    "MenuPressed", "NoPressed", "Pressed", "Released", "ReturnPressed",
    "RightPressed", "SelectPressed", "ShortcutOverride", "SpacePressed",
    "TabPressed", "UpPressed", "VolumeDownPressed", "VolumeUpPressed",
    "YesPressed", *(f"Digit{i}Pressed" for i in range(10)),
}

def main():
    if (ROOT / "core/source-map.json").is_file():
        subprocess.run([sys.executable, "-I", str(ROOT / "scripts/materialize-modules.py"),
                        "--prepare"], check=True)
    files = sorted(START.rglob("*.qml"))
    if not files:
        raise SystemExit("Start menu QML source is missing")
    errors = []
    count = 0
    for path in files:
        source = path.read_text(encoding="utf-8")
        for match in re.finditer(r"\bKeys\.on([A-Z][A-Za-z0-9]*)\s*:", source):
            count += 1
            if match[1] not in ALLOWED:
                line = source.count("\n", 0, match.start()) + 1
                errors.append(f"{path.relative_to(ROOT)}:{line}: unsupported Keys.on{match[1]}")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"Start menu key-signal preflight: {count} handlers in {len(files)} QML files")
    return 0

if __name__ == "__main__":
    sys.exit(main())
