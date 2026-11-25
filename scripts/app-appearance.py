#!/usr/bin/env python3
"""Apply reversible Explorer/Terminal appearance without replacing user profiles."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
DATA = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
BACKUP = DATA / "windows-modern/backup/app-appearance.json"
OLD_DOLPHIN_BLOB = "5dfeecc37067f7c8a7bcbc0aa229f7b0e36728c2"
MISSING = "__windows_modern_missing_7b6801__"

def blob(content):
    return hashlib.sha1(b"blob " + str(len(content)).encode() + b"\0" + content).hexdigest()

FILES = {
    "kxmlgui5/dolphin/dolphinui.rc": "config/kxmlgui5/dolphin/dolphinui.rc",
    "konsole/WindowsModern.profile": "config/konsole/WindowsModern.profile",
    "konsole/WindowsModern-tabs.css": "config/konsole/WindowsModern-tabs.css",
}

def settings():
    return [
        ("dolphinrc", "General", "AlwaysShowTabBar", "true"),
        ("dolphinrc", "General", "EditableUrl", "false"),
        ("dolphinrc", "General", "ShowCloseButtonOnTabs", "true"),
        ("dolphinrc", "General", "ShowZoomSlider", "false"),
        ("konsolerc", "Desktop Entry", "DefaultProfile", "WindowsModern.profile"),
        ("konsolerc", "MainWindow", "MenuBar", "Disabled"),
        ("konsolerc", "MainWindow", "ToolBarsMovable", "Disabled"),
        ("konsolerc", "MainWindow Toolbar mainToolBar", "Hidden", "true"),
        ("konsolerc", "TabBar", "TabBarVisibility", "AlwaysShowTabBar"),
        ("konsolerc", "TabBar", "TabBarPosition", "Top"),
        ("konsolerc", "TabBar", "NewTabButton", "true"),
        ("konsolerc", "TabBar", "SearchTabsButton", "HideSearchTabsButton"),
        ("konsolerc", "TabBar", "CloseTabButton", "OnEachTab"),
        ("konsolerc", "TabBar", "TabBarUseUserStyleSheet", "true"),
        ("konsolerc", "TabBar", "TabBarUserStyleSheetFile",
         (DATA / "konsole/WindowsModern-tabs.css").absolute().as_uri()),
    ]

def read(file, group, key):
    return subprocess.check_output(["kreadconfig6", "--file", file, "--group", group,
                                    "--key", key, "--default", MISSING], text=True).rstrip("\n")

def write(file, group, key, value):
    args = ["kwriteconfig6", "--file", file, "--group", group, "--key", key]
    subprocess.run(args + (["--delete"] if value == MISSING else [value]), check=True)

def save(state):
    BACKUP.parent.mkdir(parents=True, exist_ok=True)
    temporary = BACKUP.with_suffix(".tmp")
    temporary.write_text(json.dumps(state, indent=2), encoding="utf-8")
    temporary.replace(BACKUP)

def apply():
    state = json.loads(BACKUP.read_text()) if BACKUP.is_file() else {"keys": {}, "files": {}}
    for relative, source in FILES.items():
        path = DATA / relative
        if path.is_symlink() or not path.parent.resolve().is_relative_to(DATA.resolve()):
            print("Keeping managed app file:", path)
            continue
        old = path.read_bytes() if path.is_file() else None
        new = (ROOT / source).read_bytes()
        record = state["files"].get(relative)
        if record is None:
            if old is not None and old != new and not (
                relative.startswith("kxmlgui5/") and blob(old) == OLD_DOLPHIN_BLOB
            ):
                print("Keeping custom app file:", path)
                continue
            record = {"original": old.hex() if old is not None else None, "applied": new.hex()}
            state["files"][relative] = record
        elif old is not None and old.hex() != record["applied"]:
            print("Keeping modified app file:", path)
            continue
        record["applied"] = new.hex()
        save(state)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(new)
    for file, group, key, value in settings():
        if (CONFIG / file).is_symlink():
            print("Keeping managed app config:", file)
            continue
        name = "/".join((file, group, key))
        old = read(file, group, key)
        record = state["keys"].get(name)
        if record is None:
            record = {"original": old, "applied": value}
            state["keys"][name] = record
        elif old != record["applied"]:
            continue
        record["applied"] = value
        save(state)
        write(file, group, key, value)

def restore():
    if not BACKUP.is_file():
        return
    state = json.loads(BACKUP.read_text())
    for file, group, key, _ in settings():
        record = state["keys"].get("/".join((file, group, key)))
        if record and not (CONFIG / file).is_symlink() and read(file, group, key) == record["applied"]:
            write(file, group, key, record["original"])
    for relative in FILES:
        record = state["files"].get(relative)
        path = DATA / relative
        if (record and not path.is_symlink() and path.is_file()
                and path.parent.resolve().is_relative_to(DATA.resolve())
                and path.read_bytes().hex() == record["applied"]):
            if record["original"] is None:
                path.unlink()
            else:
                path.write_bytes(bytes.fromhex(record["original"]))
    BACKUP.unlink()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("apply", "restore"))
    if parser.parse_args().action == "apply":
        apply()
    else:
        restore()
