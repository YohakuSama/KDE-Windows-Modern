#!/usr/bin/env python3
"""Apply reversible Explorer/Terminal appearance without replacing user profiles."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).absolute().parents[1]
DATA = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
BACKUP = DATA / "windows-modern/backup/app-appearance.json"
OLD_DOLPHIN_BLOBS = {
    "5dfeecc37067f7c8a7bcbc0aa229f7b0e36728c2",
    "91f0611fac219f896ab231ec7b6e3864edbf94af",
}
MISSING = "__windows_modern_missing_7b6801__"

def blob(content):
    return hashlib.sha1(b"blob " + str(len(content)).encode() + b"\0" + content).hexdigest()

FILES = {
    "kxmlgui5/dolphin/dolphinui.rc": "config/kxmlgui5/dolphin/dolphinui.rc",
    "kxmlgui5/konsole/konsoleui.rc": "config/kxmlgui5/konsole/konsoleui.rc",
    "kxmlgui5/konsole/sessionui.rc": "config/kxmlgui5/konsole/sessionui.rc",
    "konsole/WindowsModern.profile": "config/konsole/WindowsModern.profile",
    "konsole/WindowsModern-tabs.css": "config/konsole/WindowsModern-tabs.css",
}


def source_file(relative):
    """Use the editable configuration without requiring generated mirrors."""
    manifest = ROOT / "core/source-map.json"
    if not manifest.is_file():
        return ROOT / relative
    trees = json.loads(manifest.read_text(encoding="utf-8"))["trees"]
    for source, destination in trees.items():
        prefix = destination + "/"
        if relative.startswith(prefix):
            return ROOT / source / relative[len(prefix):]
    raise ValueError("Unmapped application appearance input: " + relative)


def settings():
    return [
        ("dolphinrc", "General", "AlwaysShowTabBar", "true"),
        ("dolphinrc", "General", "EditableUrl", "false"),
        ("dolphinrc", "General", "ShowCloseButtonOnTabs", "true"),
        ("dolphinrc", "General", "ShowZoomSlider", "false"),
        ("dolphinrc", "General", "ShowStatusBar", "FullWidth"),
        ("dolphinrc", "General", "TabStyle", "AutoSize"),
        ("dolphinrc", "General", "OpenNewTabAfterLastTab", "true"),
        ("dolphinrc", "MainWindow", "MenuBar", "Disabled"),
        ("dolphinrc", "MainWindow", "ToolBarsMovable", "Disabled"),
        ("dolphinrc", "MainWindow", "State", MISSING),
        (str(STATE / "dolphinstaterc"), "MainWindow", "State", MISSING),
        ("konsolerc", "Desktop Entry", "DefaultProfile", "WindowsModern.profile"),
        ("konsolerc", "KonsoleWindow", "ShowWindowTitleOnTitleBar", "false"),
        ("konsolerc", "MainWindow", "MenuBar", "Disabled"),
        ("konsolerc", "MainWindow", "ToolBarsMovable", "Disabled"),
        ("konsolerc", "MainWindow", "State", MISSING),
        # KF6 stores QMainWindow state separately, including toolbar visibility.
        (str(STATE / "konsolestaterc"), "MainWindow", "State", MISSING),
        ("konsolerc", "Main Toolbar", "Hidden", "true"),
        ("konsolerc", "Toolbar mainToolBar", "Hidden", "true"),
        ("konsolerc", "TabBar", "ExpandTabWidth", "false"),
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
    layout_changed = set()
    for relative, source in FILES.items():
        path = DATA / relative
        if path.is_symlink() or not path.parent.resolve().is_relative_to(DATA.resolve()):
            print("Keeping managed app file:", path)
            continue
        old = path.read_bytes() if path.is_file() else None
        new = source_file(source).read_bytes()
        record = state["files"].get(relative)
        if record is None:
            if old is not None and old != new and not (
                relative == "kxmlgui5/dolphin/dolphinui.rc" and blob(old) in OLD_DOLPHIN_BLOBS
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
        if old != new:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(new)
            if relative.startswith("kxmlgui5/"):
                layout_changed.add(relative.split("/")[1])

    def installed_by_theme(relative):
        path = DATA / relative
        return (relative in state["files"] and path.is_file() and not path.is_symlink()
                and path.read_bytes() == source_file(FILES[relative]).read_bytes())

    for file, group, key, value in settings():
        if file in ("dolphinrc", str(STATE / "dolphinstaterc")):
            relative = "kxmlgui5/dolphin/dolphinui.rc"
            if not installed_by_theme(relative):
                continue
        if file == "konsolerc" or file == str(STATE / "konsolestaterc"):
            required = ("konsole/WindowsModern.profile", "konsole/WindowsModern-tabs.css",
                        "kxmlgui5/konsole/konsoleui.rc", "kxmlgui5/konsole/sessionui.rc")
            if not all(installed_by_theme(relative) for relative in required):
                continue
        if (CONFIG / file).is_symlink():
            print("Keeping managed app config:", file)
            continue
        name = "/".join((file, group, key))
        old = read(file, group, key)
        record = state["keys"].get(name)
        if value == MISSING and old == MISSING and record is None:
            continue
        if record is None:
            record = {"original": old, "applied": value}
            state["keys"][name] = record
        elif old != record["applied"]:
            # QMainWindow writes a fresh State after every application run.
            # Reset it once when our own XML layout revision changes, not
            # on every reinstall, and keep the pre-theme rollback value.
            name_of_app = "dolphin" if "dolphin" in Path(file).name else "konsole"
            if not (key == "State" and value == MISSING and name_of_app in layout_changed):
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
