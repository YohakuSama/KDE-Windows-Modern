#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Publish a Windows accent ramp through the active KDE color scheme."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parent
SYNC = runpy.run_path(str(HERE / "sync-accent.py"))
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
DATA = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
GROUP = "WindowsModernAccent"
KEY = "Palette"
MISSING = "__windows_modern_missing_accent_key__"
MODES = ("dark", "light")
MODE_ROLES = {"dark": "AccentLight2", "light": "AccentDark1"}
THEME_ID = "org.kde.windowsmodern.dark"


def read(group, key):
    value = subprocess.check_output(["kreadconfig6", "--file", "kdeglobals",
                                     "--group", group, "--key", key,
                                     "--default", MISSING], text=True).rstrip("\n")
    return None if value == MISSING else value


def write_state(value):
    args = ["kwriteconfig6", "--notify", "--file", "kdeglobals", "--group", GROUP, "--key", KEY]
    subprocess.run(args + (["--delete"] if value is None else [value]), check=True)


def native_accent():
    wallpaper = read("General", "accentColorFromWallpaper")
    accent = read("General", "AccentColor")
    if wallpaper is not None:
        wallpaper = wallpaper.lower()
    if accent is not None:
        accent = ",".join(part.strip() for part in accent.split(","))
    if wallpaper not in (None, "false", "true", "0", "1"):
        raise ValueError("Unrecognized KDE wallpaper accent setting")
    if accent in (None, "0,0,0,0", "transparent"):
        accent = None
    else:
        accent = SYNC["rgb"](accent)
    return wallpaper in ("true", "1"), accent


def decode_state(raw):
    if raw is None:
        return None
    state = json.loads(raw)
    if state["schema_version"] != 1 or state["source"] not in ("manual", "wallpaper"):
        raise ValueError("Unrecognized Windows accent state")
    palette = state["palette"]
    if set(palette) != {"Accent", *SYNC["PRESET_SHADE_ROLES"]}:
        raise ValueError("Incomplete Windows accent ramp")
    return {role: SYNC["rgb"](value) for role, value in palette.items()}


def scheme_name(mode):
    return "WindowsModern" + mode.capitalize()


def scheme_inputs():
    template = HERE / "WindowsModern.colors.in"
    if not template.is_file():
        template = HERE.parents[1] / "color-schemes/WindowsModern.colors.in"
    return (template.read_text(encoding="utf-8"),
            json.loads((HERE / "palette.json").read_text(encoding="utf-8")))


def render(template, fixed, mode, palette):
    selection = palette[MODE_ROLES[mode]] if palette is not None else None
    return SYNC["render_scheme"](template, fixed[mode], mode, selection).encode("utf-8")


def plan_schemes(directory, template, fixed, previous, desired):
    if directory.is_symlink() or directory.parent.is_symlink():
        raise ValueError("Refusing externally managed color-scheme directory")
    pending = {}
    for mode in MODES:
        path = SYNC["owned_file"](directory / (scheme_name(mode) + ".colors"))
        old = path.read_bytes()
        base = render(template, fixed, mode, None)
        # A reinstall may have restored the pristine file. Never overwrite a
        # user's independently edited scheme or an externally managed file.
        if old not in (base, render(template, fixed, mode, previous)):
            raise ValueError(f"Color scheme differs from the installed Windows Modern palette: {path}")
        new = render(template, fixed, mode, desired)
        if old != new:
            pending[path] = (old, new)
    return pending


def active_mode(mode):
    package = read("KDE", "LookAndFeelPackage")
    defaults = CONFIG / "kdedefaults/package"
    if package is None and defaults.is_file():
        package = defaults.read_text(encoding="utf-8").strip()
    return package == THEME_ID and read("General", "ColorScheme") == scheme_name(mode)


def notify_palette():
    # KDE's same-scheme CLI may emit its notification before the last
    # config sync. Publish once more after verifying the on-disk roles.
    subprocess.run(["busctl", "--user", "emit", "/KGlobalSettings",
                    "org.kde.KGlobalSettings", "notifyChange", "ii", "0", "0"],
                   check=True)


def apply_current(mode, native):
    if not active_mode(mode):
        raise ValueError("Active Windows Modern appearance changed during accent synchronization")
    # With an explicit transparent accent, KDE copies the scheme roles
    # without accentBackground(), link adjustment or tinting. It also
    # reapplies the same scheme, unlike the positional scheme command.
    subprocess.run(["plasma-apply-colorscheme", "--accent-color", native[1] or "transparent"],
                   check=True, stdout=subprocess.DEVNULL)


def live_matches(mode, fixed, palette, path):
    selection = palette[MODE_ROLES[mode]]
    values = SYNC["accent_values"](mode, fixed[mode], selection)
    file_hash = read("General", "ColorSchemeHash")
    if file_hash != hashlib.sha1(path.read_bytes()).hexdigest():
        return False
    for group, key, role in (
            ("Colors:Selection", "BackgroundNormal", "accent"),
            ("Colors:Selection", "BackgroundAlternate", "accent"),
            ("Colors:Selection", "ForegroundNormal", "highlight_text"),
            ("Colors:Window", "DecorationFocus", "accent"),
            ("Colors:Button", "DecorationFocus", "accent"),
            ("Colors:View", "ForegroundLink", "accent"),
            ("Colors:Window", "BackgroundNormal", "window"),
            ("WM", "activeBackground", "window")):
        color = read(group, key)
        if color is None or SYNC["rgb"](color) != SYNC["rgb"](values[role]):
            return False
    return True


def synchronize(mode, action, inputs):
    if not active_mode(mode):
        raise ValueError("Select the active Windows Modern appearance first")
    raw = read(GROUP, KEY)
    previous = decode_state(raw)
    if action in ("sync", "native") and previous is None:
        return None
    native = native_accent()
    if action in ("manual", "wallpaper"):
        if any(native):
            raise ValueError("Select 'From current color scheme' in KDE Colors before using Windows accent control")
        state = {"schema_version": 1, "source": action}
        if action == "manual":
            state["manual_color"] = SYNC["rgb"](inputs[0])
            state["palette"] = SYNC["derive_manual_palette"](state["manual_color"])
        else:
            state["palette"] = SYNC["analyze_wallpapers"]([Path(path) for path in inputs])["palette"]
        desired_raw = json.dumps(state, separators=(",", ":"), sort_keys=True)
        desired = decode_state(desired_raw)
    elif action == "native" or any(native):
        # An explicit native KDE color selection wins over our stored ramp.
        desired_raw = desired = None
    else:
        desired_raw, desired = raw, previous

    if CONFIG.is_symlink() or CONFIG.joinpath("kdeglobals").is_symlink():
        raise ValueError("Refusing externally managed KDE configuration")
    SYNC["owned_file"](CONFIG / "kdeglobals")
    template, fixed = scheme_inputs()
    directory = DATA / "color-schemes"
    pending = plan_schemes(directory, template, fixed, previous, desired)
    kvdir = CONFIG / "Kvantum/Windows-modern"
    if not kvdir.is_dir():
        raise ValueError("Windows Modern accent control requires user-local Kvantum assets")
    for name in MODES:
        color = desired[MODE_ROLES[name]] if desired is not None else fixed[name]["accent"]
        prepared = SYNC["plan_kvantum"](kvdir, name, color)
        # In native mode the active shade is only known after KDE applies
        # the base scheme. Validate the active atlas now but update it later.
        if desired is not None or name != mode:
            pending.update(prepared)
    scheme = directory / (scheme_name(mode) + ".colors")
    if not active_mode(mode) or native_accent() != native:
        raise ValueError("KDE appearance changed while preparing the accent")
    if read(GROUP, KEY) != raw:
        raise ValueError("Windows accent selection changed while preparing the accent")
    refresh = (desired is None or scheme in pending or not live_matches(mode, fixed, desired, scheme))
    if not pending and not refresh and desired_raw == raw:
        return False

    written = SYNC["write_pending"](pending)
    native_pending, native_written = {}, []
    try:
        if refresh:
            apply_current(mode, native)
        if native_accent() != native or not active_mode(mode):
            raise ValueError("KDE appearance changed during accent synchronization")
        if desired is not None:
            if not live_matches(mode, fixed, desired, scheme):
                raise ValueError("KDE did not publish the requested Windows accent roles")
        else:
            selection = read("Colors:Selection", "BackgroundNormal")
            if selection is None:
                raise ValueError("Missing effective KDE selection color")
            native_pending = SYNC["plan_kvantum"](kvdir, mode, selection)
            native_written = SYNC["write_pending"](native_pending)
        if native_accent() != native or not active_mode(mode):
            raise ValueError("KDE appearance changed while committing the accent")
        if desired_raw != raw:
            write_state(desired_raw)
            if read(GROUP, KEY) != desired_raw:
                raise ValueError("Windows accent state was not saved")
        if refresh:
            notify_palette()
    except Exception:
        # Restore only files and state still belonging to this transaction.
        # Respect a concurrent native KDE selection rather than undoing it.
        for changes, completed in ((native_pending, native_written), (pending, written)):
            try:
                SYNC["restore_pending"](changes, completed)
            except (OSError, ValueError) as error:
                print(f"Accent asset rollback incomplete: {error}", file=sys.stderr)
        try:
            if desired_raw != raw and read(GROUP, KEY) == desired_raw:
                write_state(raw)
            if active_mode(mode):
                apply_current(mode, native_accent())
                notify_palette()
        except (OSError, ValueError, subprocess.CalledProcessError) as error:
            print(f"Accent configuration rollback incomplete: {error}", file=sys.stderr)
        raise
    return bool(pending or native_pending or refresh or desired_raw != raw)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=MODES)
    parser.add_argument("action", choices=("sync", "manual", "wallpaper", "native"))
    parser.add_argument("inputs", nargs="*")
    args = parser.parse_args()
    if ((args.action == "manual" and len(args.inputs) != 1)
            or (args.action == "wallpaper" and not args.inputs)
            or (args.action in ("sync", "native") and args.inputs)):
        parser.error("manual requires one RGB value; wallpaper requires one or more image paths")
    if os.geteuid() == 0:
        parser.error("Run accent control as the desktop user")
    try:
        changed = synchronize(args.mode, args.action, args.inputs)
    except (OSError, ValueError, KeyError, TypeError, ET.ParseError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Windows accent control: {error}\n")
    print("native" if changed is None else "changed" if changed else "unchanged")


if __name__ == "__main__":
    main()
