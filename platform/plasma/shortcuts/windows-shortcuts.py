#!/usr/bin/env python3
"""Windows keyboard shortcuts for KDE Plasma, applied through kglobalaccel.

Keys KDE already maps like Windows (Win+E, Win+I, Win+L, Win+D, Win+.,
Win+P, Win+Shift+S, Win+Left/Right, Win+1..9) are left alone. This moves the
rest to where Windows has them:

  Win+Up / Win+Down   maximize / restore / minimize / quarter-snap (KWin script)
  Win+Tab             Task View (KWin Overview), not window cycling
  Win+R               themed Run dialog, native KRunner fallback
  Win+M, Win+Home     minimize all / all others
  Win+A / Win+N       Quick Settings / notifications (tray, see "tray" below)
  Win+V               themed Klipper history, native fallback
  Win+PrtSc           full screenshot saved silently; Alt+PrtSc active window
  Ctrl+Shift+Esc      Mission Center (group "apps")

The previous keys of every touched action are saved once to
~/.local/share/windows-modern/backup/shortcuts.json; --restore puts them back.

Usage: windows-shortcuts.py apply   [--group shortcuts|apps] [--dry-run]
       windows-shortcuts.py restore [--group shortcuts|apps]
       windows-shortcuts.py tray-apply | tray-restore   (Plasma Shell must be stopped)
       windows-shortcuts.py clipboard-apply | clipboard-release | run-apply | run-release [--dry-run]
       windows-shortcuts.py show
"""
import argparse
import json
import os
import pathlib
import subprocess
import sys
import time

from gi.repository import Gio, GLib

BACKUP = pathlib.Path(os.environ.get("WM_SHORTCUT_BACKUP",
    str(pathlib.Path(os.environ.get("XDG_DATA_HOME", pathlib.Path.home() / ".local/share")) / "windows-modern/backup/shortcuts.json")))

MODS = {"Meta": 0x10000000, "Ctrl": 0x04000000, "Alt": 0x08000000, "Shift": 0x02000000}
KEYS = {"F2": 0x01000031, "Search": 0x01000092, "Up": 0x01000013, "Down": 0x01000015, "Left": 0x01000012, "Right": 0x01000014,
        "Tab": 0x01000001, "Backtab": 0x01000002, "Print": 0x01000009, "Esc": 0x01000000,
        "Home": 0x01000010, "Space": 0x20}
MOD_MASK = 0xFE000000

# (group, component, action, friendly component, friendly action, change)
# change: ("remove", [keys]) | ("remove-mod", "Meta") | ("add", [keys]) | ("set", [keys])
# Removals run before additions, so a key is free before it is taken.
CHANGES = [
    ("shortcuts", "kwin", "Window Quick Tile Top", "", "", ("remove", ["Meta+Up"])),
    ("shortcuts", "kwin", "Window Quick Tile Bottom", "", "", ("remove", ["Meta+Down"])),
    ("shortcuts", "kwin", "Walk Through Windows", "", "", ("remove-mod", "Meta")),
    ("shortcuts", "kwin", "Walk Through Windows (Reverse)", "", "", ("remove-mod", "Meta")),
    ("shortcuts", "plasmashell", "next activity", "", "", ("remove", ["Meta+A"])),
    ("shortcuts", "org.kde.spectacle.desktop", "RecordRegion", "", "", ("remove", ["Meta+R"])),
    ("shortcuts", "kwin", "Windows Modern: Maximize or Snap Up", "", "", ("set", ["Meta+Up"])),
    ("shortcuts", "kwin", "Windows Modern: Restore, Minimize or Snap Down", "", "", ("set", ["Meta+Down"])),
    ("shortcuts", "kwin", "Overview", "", "", ("add", ["Meta+Tab"])),
    ("shortcuts", "kwin", "MinimizeAll", "", "", ("set", ["Meta+M"])),
    ("shortcuts", "kwin", "minimizeAllOthers", "", "", ("set", ["Meta+Home"])),
    ("shortcuts", "org.kde.krunner.desktop", "_launch", "", "", ("add", ["Meta+R"])),
    ("shortcuts", "org.kde.spectacle.desktop", "ActiveWindowScreenShot", "", "", ("set", ["Alt+Print"])),
    ("shortcuts", "windowsmodern-screenshot.desktop", "_launch", "Screenshot (full screen, saved)",
     "Screenshot (full screen, saved)", ("set", ["Meta+Print"])),
    ("apps", "org.kde.plasma-systemmonitor.desktop", "_launch", "", "", ("remove", ["Ctrl+Shift+Esc"])),
    ("apps", "io.missioncenter.MissionCenter.desktop", "_launch", "Mission Center", "Mission Center",
     ("add", ["Ctrl+Shift+Esc"])),
]


def parse(text):
    *mods, key = text.split("+")
    value = KEYS.get(key) or ord(key.upper())
    for m in mods:
        value |= MODS[m]
    return value


def fmt(value):
    names = [m for m, bit in MODS.items() if value & bit]
    key = value & ~MOD_MASK
    names.append(next((k for k, v in KEYS.items() if v == key), chr(key) if 32 <= key < 127 else hex(key)))
    return "+".join(names)


class GlobalAccel:
    def __init__(self):
        self.proxy = Gio.DBusProxy.new_for_bus_sync(
            Gio.BusType.SESSION, Gio.DBusProxyFlags.NONE, None,
            "org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel", None)

    def _call(self, method, sig, args):
        return self.proxy.call_sync(method, GLib.Variant(sig, args), Gio.DBusCallFlags.NONE, 5000, None)

    def keys(self, aid):
        """Combined key values of an action (first key of each sequence)."""
        result = self._call("shortcutKeys", "(as)", (aid,)).unpack()[0]
        return [seq[0][0] for seq in result if seq[0] and seq[0][0]]

    def set_keys(self, aid, values, present=False):
        seqs = [([v, 0, 0, 0],) for v in values]
        if present:
            # A launcher entry registered at runtime only fires once it is
            # marked present (normally done when kglobalaccel loads it at
            # login); setForeignShortcutKeys stores the keys but never does.
            set_present, no_autoloading = 0x2, 0x4
            self._call("setShortcutKeys", "(asa(ai)u)", (aid, seqs, set_present | no_autoloading))
        else:
            self._call("setForeignShortcutKeys", "(asa(ai))", (aid, seqs))

    def actions(self, component):
        return self._call("allActionsForComponent", "(as)", ([component, "", "", ""],)).unpack()[0]

    def key_owner(self, value):
        return self._call("actionList", "((ai))", (([value, 0, 0, 0],),)).unpack()[0]

    def register(self, aid):
        self._call("doRegister", "(as)", (aid,))


def action_id(component, action, fcomp, faction):
    return [component, action, fcomp, faction]


def wanted(current, change):
    kind, arg = change
    if kind == "remove":
        drop = {parse(k) for k in arg}
        return [k for k in current if k not in drop]
    if kind == "remove-mod":
        return [k for k in current if not k & MODS[arg]]
    if kind == "add":
        return current + [parse(k) for k in arg if parse(k) not in current]
    return [parse(k) for k in arg]  # set


def load_backup():
    return json.loads(BACKUP.read_text()) if BACKUP.exists() else {}


CLIPBOARD_COMPONENTS = ("plasmashell", "klipper")
CLIPBOARD_ACTION = "show-on-mouse-pos"
THEMED_CLIPBOARD_COMPONENT = "org.kde.windowsmodern.clipboard"
THEMED_CLIPBOARD_ACTION = "show-history"
THEMED_RUN_COMPONENT = "org.kde.windowsmodern.run"
THEMED_RUN_ACTION = "show-run"
NATIVE_RUN_COMPONENT = "org.kde.krunner.desktop"
NATIVE_RUN_ACTION = "_launch"


def registered_action(ga, component, action):
    return next((aid for aid in ga.actions(component)
                 if len(aid) == 4 and aid[:2] == [component, action]), None)


def clipboard_target(ga):
    for component in CLIPBOARD_COMPONENTS:
        for aid in ga.actions(component):
            if len(aid) == 4 and aid[:2] == [component, CLIPBOARD_ACTION]:
                return aid
    return None


def themed_clipboard_target(ga):
    return registered_action(ga, THEMED_CLIPBOARD_COMPONENT, THEMED_CLIPBOARD_ACTION)


def save_backup(backup):
    BACKUP.parent.mkdir(parents=True, exist_ok=True)
    temporary = BACKUP.with_suffix(".tmp")
    temporary.write_text(json.dumps(backup, indent=1))
    temporary.replace(BACKUP)


def bind_native_shortcut(ga, aid, key_text, label, dry_run=False):
    """Bind only the registered previous action; never create a fake shortcut."""
    key = parse(key_text)
    current = ga.keys(aid)
    if key in current:
        print(f"  {label}: previous action already bound")
        return 0
    owner = ga.key_owner(key)
    if owner and owner[:2] != aid[:2]:
        print(f"  {label} is already used by {owner[0]} :: {owner[1]}; keeping the existing binding", file=sys.stderr)
        return 1
    if dry_run:
        print(f"  {label}: would add previous binding")
        return 0
    backup = load_backup()
    backup.setdefault(f"{aid[0]}|{aid[1]}", current)
    save_backup(backup)
    expected = current + [key]
    ga.set_keys(aid, expected)
    if sorted(ga.keys(aid)) != sorted(expected):
        ga.set_keys(aid, current)
        print(f"  {label}: previous binding failed verification", file=sys.stderr)
        return 1
    print(f"  {label}: previous binding verified")
    return 0


def transfer_shortcut(ga, target, previous, key_text, label, dry_run=False):
    """Move one key, preserving all other bindings and rolling back on failure."""
    key = parse(key_text)
    owner = ga.key_owner(key)
    if owner and owner[:2] not in (target[:2], previous[:2]):
        print(f"  {label} is already used by {owner[0]} :: {owner[1]}; keeping the existing binding", file=sys.stderr)
        return 1
    target_keys = ga.keys(target)
    previous_keys = ga.keys(previous)
    if key in target_keys and key not in previous_keys:
        return 0
    if dry_run:
        print(f"  {label}: would transfer shortcut")
        return 0
    backup = load_backup()
    previous_backup = dict(backup)
    if key in previous_keys:
        backup.setdefault(f"{previous[0]}|{previous[1]}", previous_keys)
    backup.setdefault(f"{target[0]}|{target[1]}", target_keys)
    save_backup(backup)
    new_previous = [value for value in previous_keys if value != key]
    new_target = target_keys + ([key] if key not in target_keys else [])
    try:
        if new_previous != previous_keys:
            ga.set_keys(previous, new_previous)
        ga.set_keys(target, new_target)
        if sorted(ga.keys(target)) != sorted(new_target) or sorted(ga.keys(previous)) != sorted(new_previous):
            raise RuntimeError("shortcut verification failed")
    except Exception as exc:
        ga.set_keys(target, target_keys)
        ga.set_keys(previous, previous_keys)
        save_backup(previous_backup)
        print(f"  {label}: restored previous binding: {exc}", file=sys.stderr)
        return 1
    print(f"  {label}: shortcut bound and verified")
    return 0


def bind_clipboard(ga, aid, dry_run=False):
    return bind_native_shortcut(ga, aid, "Meta+V", "Win+V", dry_run)


def bind_themed_clipboard(ga, themed, native, dry_run=False):
    return transfer_shortcut(ga, themed, native, "Meta+V", "Win+V", dry_run)


def run_apply(dry_run=False):
    ga = GlobalAccel()
    native = registered_action(ga, NATIVE_RUN_COMPONENT, NATIVE_RUN_ACTION)
    # Never release KRunner until the live tray action has registered.
    for attempt in range(20):
        themed = registered_action(ga, THEMED_RUN_COMPONENT, THEMED_RUN_ACTION)
        if themed and native:
            return transfer_shortcut(ga, themed, native, "Meta+R", "Win+R", dry_run)
        if attempt < 19:
            time.sleep(0.5)
    if native:
        return bind_native_shortcut(ga, native, "Meta+R", "Win+R", dry_run)
    print("  Win+R: no registered Run action found", file=sys.stderr)
    return 1


def run_release(dry_run=False):
    # Removing the tray alone must not strand Win+R. A full uninstall
    # restores the original shortcuts first, so this becomes a no-op.
    ga = GlobalAccel()
    themed = registered_action(ga, THEMED_RUN_COMPONENT, THEMED_RUN_ACTION)
    if not themed or parse("Meta+R") not in ga.keys(themed):
        return 0
    native = registered_action(ga, NATIVE_RUN_COMPONENT, NATIVE_RUN_ACTION)
    if not native:
        return 1
    return transfer_shortcut(ga, native, themed, "Meta+R", "Win+R", dry_run)


def clipboard_release(dry_run=False):
    # Removing the tray alone must not strand Win+V when no shell router
    # binary remains installed. A full uninstall restores backups first.
    ga = GlobalAccel()
    themed = themed_clipboard_target(ga)
    if not themed or parse("Meta+V") not in ga.keys(themed):
        return 0
    native = clipboard_target(ga)
    if not native:
        return 1
    return transfer_shortcut(ga, native, themed, "Meta+V", "Win+V", dry_run)


def clipboard_apply(dry_run=False):
    ga = GlobalAccel()
    # Plasma starts Klipper asynchronously when loading the native clipboard
    # applet. Do not register an invented action when that backend is absent.
    for attempt in range(20):
        service = subprocess.run(["busctl", "--user", "status", "org.kde.klipper"],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        aid = clipboard_target(ga) if service.returncode == 0 else None
        if aid:
            themed = themed_clipboard_target(ga)
            if themed:
                return bind_themed_clipboard(ga, themed, aid, dry_run)
            return bind_clipboard(ga, aid, dry_run)
        if attempt < 19:
            time.sleep(0.5)
    print("  Native Klipper service or its clipboard history action is unavailable", file=sys.stderr)
    return 1


def restore_clipboard(ga, backup):
    targets = [(THEMED_CLIPBOARD_COMPONENT, THEMED_CLIPBOARD_ACTION)]
    targets.extend((component, CLIPBOARD_ACTION) for component in CLIPBOARD_COMPONENTS)
    for component, action in targets:
        name = f"{component}|{action}"
        if name not in backup:
            continue
        aid = [component, action, "", ""]
        ga.set_keys(aid, backup[name])
        if sorted(ga.keys(aid)) != sorted(backup[name]):
            print("  Could not restore the original clipboard shortcut", file=sys.stderr)
            return 1
        backup.pop(name)
    return 0


def apply(group, dry_run):
    ga = GlobalAccel()
    backup = load_backup()
    changes = [c for c in CHANGES if c[0] == group]
    failed = 0
    for _, comp, action, fcomp, faction, change in changes:
        aid = action_id(comp, action, fcomp, faction)
        if fcomp and not dry_run:
            ga.register(aid)  # a launcher entry for an app or our .desktop
        current = ga.keys(aid)
        # A previously migrated Win+R belongs to the themed tray, not KRunner.
        if comp == NATIVE_RUN_COMPONENT and action == NATIVE_RUN_ACTION:
            owner = ga.key_owner(parse("Meta+R"))
            if owner and owner[:2] == [THEMED_RUN_COMPONENT, THEMED_RUN_ACTION]:
                continue
        new = wanted(current, change)
        backup.setdefault(f"{comp}|{action}", current)
        line = f"  {comp} :: {action}: {', '.join(map(fmt, current)) or '-'} -> {', '.join(map(fmt, new)) or '-'}"
        if new == current or dry_run:
            print(line + ("" if new != current else "  (already)"))
            continue
        ga.set_keys(aid, new, present=bool(fcomp))
        got = ga.keys(aid)
        ok = sorted(got) == sorted(new)
        failed += not ok
        print(line + ("" if ok else f"  FAILED (now {', '.join(map(fmt, got)) or '-'})"))
    if not dry_run:
        BACKUP.parent.mkdir(parents=True, exist_ok=True)
        BACKUP.write_text(json.dumps(backup, indent=1))
    return 1 if failed else 0


def restore(group):
    ga = GlobalAccel()
    backup = load_backup()
    if group == "shortcuts":
        if restore_clipboard(ga, backup):
            return 1
        name = f"{THEMED_RUN_COMPONENT}|{THEMED_RUN_ACTION}"
        if name in backup:
            aid = [THEMED_RUN_COMPONENT, THEMED_RUN_ACTION, "", ""]
            ga.set_keys(aid, backup[name])
            if sorted(ga.keys(aid)) != sorted(backup[name]):
                print("  Could not restore the themed Run shortcut", file=sys.stderr)
                return 1
            backup.pop(name)
    # Reverse order: our actions give their keys up before the original
    # owners take them back.
    for _, comp, action, fcomp, faction, _change in reversed([c for c in CHANGES if c[0] == group]):
        key = f"{comp}|{action}"
        if key not in backup:
            continue
        ga.set_keys(action_id(comp, action, fcomp, faction), backup.pop(key))
        print(f"  restored {comp} :: {action}")
    if backup:
        BACKUP.write_text(json.dumps(backup, indent=1))
    elif BACKUP.exists():
        BACKUP.unlink()
    return 0


# ── Tray: Win+A opens Quick Settings, Win+N the notifications ────────────
# Plasma keeps an applet's global shortcut in its own config group
# ([...][Applets][N][Shortcuts] global=...), read when Plasma Shell starts.
APPLETSRC = pathlib.Path(os.environ.get("XDG_CONFIG_HOME", pathlib.Path.home() / ".config")) / "plasma-org.kde.plasma.desktop-appletsrc"
TRAYS = ("org.kde.windowsmodern.systemtray", "org.kde.plasma.systemtray")
CLOCK = "org.kde.windowsmodern.digitalclock"
NOTIFICATIONS = "org.kde.plasma.notifications"


def _groups():
    """{group path tuple: {key: value}} from the applets config."""
    groups, cur = {}, None
    for line in APPLETSRC.read_text(errors="replace").splitlines():
        if line.startswith("[") and line.endswith("]"):
            cur = tuple(line[1:-1].split("]["))
            groups.setdefault(cur, {})
        elif cur and "=" in line:
            k, v = line.split("=", 1)
            groups[cur][k] = v
    return groups


def tray_targets():
    """[(group path, key)] for Quick Settings and notification/calendar.

    Prefer the Windows Modern clock for Win+N. Release the previous
    notification applet binding before assigning it to the clock. Preserve
    unrelated shortcuts and fall back to the native tray if no clock exists.
    """
    groups = _groups()
    panels = sorted((int(g[1]) for g, kv in groups.items()
                     if len(g) == 2 and g[0] == "Containments" and kv.get("plugin") == "org.kde.panel"
                     and kv.get("lastScreen") == "0"))
    for panel in panels:
        prefix = ("Containments", str(panel), "Applets")
        applets = [(g, kv) for g, kv in groups.items() if len(g) == 4 and g[:3] == prefix]
        clock = next((g for g, kv in applets if kv.get("plugin") == CLOCK), None)
        tray = next((g for g, kv in applets if kv.get("plugin") in TRAYS), None)
        if not clock and not tray:
            continue
        out = [(tray, "Meta+A")] if tray else []
        notification = next((g for g, kv in groups.items()
                             if tray and len(g) == 6 and g[:4] == tray and g[4] == "Applets"
                             and kv.get("plugin") == NOTIFICATIONS), None)
        if clock:
            if notification and groups.get(notification + ("Shortcuts",), {}).get("global") == "Meta+N":
                out.append((notification, ""))
            out.append((clock, "Meta+N"))
        elif notification:
            out.append((notification, "Meta+N"))
        return out
    return []

def _kconfig(path, value=None, delete=False):
    args = ["--file", str(APPLETSRC)]
    for g in path + ("Shortcuts",):
        args += ["--group", g]
    args += ["--key", "global"]
    if delete:
        return subprocess.run(["kwriteconfig6", *args, "--delete"], check=True)
    if value is not None:
        return subprocess.run(["kwriteconfig6", *args, value], check=True)
    return subprocess.run(["kreadconfig6", *args], check=False, capture_output=True, text=True).stdout.strip()


def tray_apply():
    targets = tray_targets()
    if not targets:
        print("  no supported tray or clock found on the primary screen's panel — skipped")
        return 0
    backup = load_backup()
    for path, key in targets:
        backup.setdefault("applet|" + "/".join(path), _kconfig(path))
        _kconfig(path, key)
        print(f"  {'/'.join(path[1:])}: {key}")
    BACKUP.parent.mkdir(parents=True, exist_ok=True)
    BACKUP.write_text(json.dumps(backup, indent=1))
    return 0


def tray_restore():
    backup = load_backup()
    for name in [k for k in backup if k.startswith("applet|")]:
        path = tuple(name.split("|", 1)[1].split("/"))
        old = backup.pop(name)
        if old:
            _kconfig(path, old)
        else:
            _kconfig(path, delete=True)
        print(f"  restored {'/'.join(path[1:])}")
    if backup:
        BACKUP.write_text(json.dumps(backup, indent=1))
    elif BACKUP.exists():
        BACKUP.unlink()
    return 0


def show():
    ga = GlobalAccel()
    for group, comp, action, fcomp, faction, _ in CHANGES:
        keys = ga.keys(action_id(comp, action, fcomp, faction))
        print(f"  [{group}] {comp} :: {action}: {', '.join(map(fmt, keys)) or '-'}")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("command", choices=["apply", "restore", "tray-apply", "tray-restore", "clipboard-apply", "clipboard-release", "run-apply", "run-release", "show"])
    ap.add_argument("--group", choices=["shortcuts", "apps"], default="shortcuts")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    if args.command == "tray-apply":
        return tray_apply()
    if args.command == "tray-restore":
        return tray_restore()
    try:
        if args.command == "clipboard-apply":
            return clipboard_apply(args.dry_run)
        if args.command == "clipboard-release":
            return clipboard_release(args.dry_run)
        if args.command == "run-apply":
            return run_apply(args.dry_run)
        if args.command == "run-release":
            return run_release(args.dry_run)
        if args.command == "apply":
            return apply(args.group, args.dry_run)
        if args.command == "restore":
            return restore(args.group)
        return show()
    except GLib.Error as ex:
        print(f"kglobalaccel not reachable ({ex.message}) — is a Plasma session running?")
        return 1


if __name__ == "__main__":
    sys.exit(main())
