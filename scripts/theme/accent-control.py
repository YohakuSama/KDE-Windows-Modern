#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Publish a Windows accent ramp through the active KDE color scheme."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import subprocess
import sys
from urllib.parse import unquote, urlsplit
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
MAX_SCREENS = 16


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


def plasma_call(method, reply_type, *args):
    result = json.loads(subprocess.check_output(
        ["busctl", "--user", "--json=short", "--timeout=3s", "call",
         "org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell",
         method, *args], text=True, timeout=5))
    if (not isinstance(result, dict) or result.get("type") != reply_type
            or not isinstance(result.get("data"), list) or len(result["data"]) != 1):
        raise ValueError("Unexpected Plasma wallpaper API reply")
    return result["data"][0]


def desktop_snapshot():
    # A fixed read-only script supplies the current activity and actual
    # Plasma screen count. Do not infer active screens from saved containments.
    script = "print(JSON.stringify({activity:currentActivity(),screens:screenCount}));"
    info = json.loads(plasma_call("evaluateScript", "s", "s", script))
    count = info["screens"]
    if type(count) is not int or not 1 <= count <= MAX_SCREENS or not isinstance(info["activity"], str):
        raise ValueError("Plasma desktop topology is unavailable")
    return info


def string_parameter(parameters, key, default=None):
    value = parameters.get(key)
    if value is None:
        return default
    if (not isinstance(value, dict) or value.get("type") != "s"
            or not isinstance(value.get("data"), str)):
        raise ValueError("Unexpected Plasma wallpaper parameter: " + key)
    return value["data"]


def package_image(package, mode, fragment):
    if not ((package / "metadata.json").is_file() or (package / "metadata.desktop").is_file()):
        raise ValueError("Wallpaper directory is not a recognized Plasma image package")
    light = package / "contents/images"
    dark = package / "contents/images_dark"
    if not light.is_dir():
        raise ValueError("Wallpaper package has no light image directory")

    def entries(directory):
        # Plasma's package finder considers image entries with WxH names.
        # Keep its recognized formats in the candidate set, even if our
        # decoder cannot read all of them; never select a different image
        # just because it is easier for the accent algorithm to decode.
        suffixes = {".avif", ".bmp", ".gif", ".heif", ".heic", ".jpeg", ".jpg",
                    ".png", ".svg", ".svgz", ".tif", ".tiff", ".webp"}
        return sorted(path for path in directory.iterdir()
                      if path.is_file() and path.suffix.lower() in suffixes
                      and re.fullmatch(r"[1-9]\d*x[1-9]\d*", path.stem)) if directory.is_dir() else []

    # Follow the same variant policy as MediaProxy for an unambiguous
    # single-image package. Multi-resolution ranking is not guessed.
    light_images = entries(light)
    if not light_images:
        raise ValueError("Wallpaper package has no selectable light image")
    use_dark = fragment == "dark" or (fragment == "" and mode == "dark")
    candidates = entries(dark) if use_dark else []
    if not candidates:
        candidates = light_images
    if len(candidates) != 1:
        raise ValueError("Wallpaper package has no unambiguous selected image")
    return candidates[0]


def resolve_wallpaper(image, mode):
    if not image:
        raise ValueError("Plasma has not supplied an explicit wallpaper")
    path = Path(image)
    fragment = ""
    if not path.is_absolute() or not path.exists():
        url = urlsplit(image)
        if url.scheme != "file" or url.netloc not in ("", "localhost") or url.query:
            raise ValueError("Only local file wallpapers are supported")
        path = Path(unquote(url.path, errors="strict"))
        fragment = url.fragment
    if not path.is_absolute() or fragment not in ("", "light", "dark"):
        raise ValueError("Wallpaper selection is not a supported static image")
    if path.is_dir():
        path = package_image(path, mode, fragment)
    path = path.resolve(strict=True)
    if not path.is_file():
        raise ValueError("Wallpaper image is unavailable")
    return path


def wallpaper_fingerprint(path):
    info = path.stat()
    return {"path": str(path), "device": info.st_dev, "inode": info.st_ino,
            "size": info.st_size, "mtime_ns": info.st_mtime_ns, "ctime_ns": info.st_ctime_ns}


def discover_wallpapers(mode):
    desktop = desktop_snapshot()
    wallpapers = []
    for screen in range(desktop["screens"]):
        parameters = plasma_call("wallpaper", "a{sv}", "u", str(screen))
        if not isinstance(parameters, dict) or string_parameter(parameters, "wallpaperPlugin") != "org.kde.image":
            raise ValueError(f"Screen {screen} has no supported static image wallpaper")
        if string_parameter(parameters, "PreviewImage", "null") not in ("", "null"):
            raise ValueError(f"Screen {screen} is previewing a wallpaper")
        image = resolve_wallpaper(string_parameter(parameters, "Image"), mode)
        # Retain screen multiplicity: identical images on two displays
        # contribute twice, while disconnected screens contribute nothing.
        wallpapers.append(wallpaper_fingerprint(image))
    if desktop != desktop_snapshot():
        raise ValueError("Desktop topology changed during wallpaper discovery")
    return {"activity": desktop["activity"], "wallpapers": wallpapers}


def automatic_state(mode, previous):
    snapshot = discover_wallpapers(mode)
    if previous and previous["source"] == "automatic" and all(
            previous.get(key) == value for key, value in snapshot.items()):
        return previous
    palette = SYNC["analyze_wallpapers"](
        [Path(image["path"]) for image in snapshot["wallpapers"]])["palette"]
    if snapshot != discover_wallpapers(mode):
        raise ValueError("Desktop wallpaper changed during color analysis")
    return {"schema_version": 1, "source": "automatic", "palette": palette, **snapshot}


def decode_state(raw):
    if raw is None:
        return None
    state = json.loads(raw)
    if state["schema_version"] != 1 or state["source"] not in ("manual", "wallpaper", "automatic"):
        raise ValueError("Unrecognized Windows accent state")
    if state["source"] == "automatic":
        images = state["wallpapers"]
        if (not isinstance(state["activity"], str) or not isinstance(images, list)
                or not 1 <= len(images) <= MAX_SCREENS
                or any(not isinstance(image, dict) or not isinstance(image.get("path"), str)
                       or not Path(image["path"]).is_absolute() for image in images)):
            raise ValueError("Invalid automatic wallpaper accent state")
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
    if action in ("manual", "wallpaper", "automatic"):
        if any(native):
            raise ValueError("Select 'From current color scheme' in KDE Colors before using Windows accent control")
        state = {"schema_version": 1, "source": action}
        if action == "manual":
            state["manual_color"] = SYNC["rgb"](inputs[0])
            state["palette"] = SYNC["derive_manual_palette"](state["manual_color"])
        elif action == "wallpaper":
            state["palette"] = SYNC["analyze_wallpapers"]([Path(path) for path in inputs])["palette"]
        else:
            state = automatic_state(mode, json.loads(raw) if raw is not None else None)
        desired_raw = json.dumps(state, separators=(",", ":"), sort_keys=True)
        desired = decode_state(desired_raw)
    elif action == "native" or any(native):
        # An explicit native KDE color selection wins over our stored ramp.
        desired_raw = desired = None
    else:
        desired_raw, desired = raw, previous
        state = json.loads(raw)
        if state["source"] == "automatic":
            try:
                updated = automatic_state(mode, state)
                candidate_raw = json.dumps(updated, separators=(",", ":"), sort_keys=True)
                desired_raw, desired = candidate_raw, decode_state(candidate_raw)
            except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
                # A missing/unsupported or transiently changing wallpaper
                # is not a reason to erase the last verified ramp or block
                # a light/dark switch. The next wallpaper event retries it.
                print(f"Automatic wallpaper accent retained: {error}", file=sys.stderr)

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
    parser.add_argument("action", choices=("sync", "manual", "wallpaper", "automatic", "native"))
    parser.add_argument("inputs", nargs="*")
    args = parser.parse_args()
    if ((args.action == "manual" and len(args.inputs) != 1)
            or (args.action == "wallpaper" and not args.inputs)
            or (args.action in ("sync", "automatic", "native") and args.inputs)):
        parser.error("manual requires one RGB value; wallpaper requires one or more image paths")
    if os.geteuid() == 0:
        parser.error("Run accent control as the desktop user")
    try:
        changed = synchronize(args.mode, args.action, args.inputs)
    except (OSError, ValueError, KeyError, TypeError, ET.ParseError, subprocess.SubprocessError) as error:
        parser.exit(1, f"Windows accent control: {error}\n")
    print("native" if changed is None else "changed" if changed else "unchanged")


if __name__ == "__main__":
    main()
