#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Publish a Windows accent ramp through the active KDE color scheme."""
import argparse
import configparser
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET


def _load_adjacent(module_name, filename, fallback_relative=None):
    here = Path(__file__).absolute().parent
    path = here / filename
    if not path.exists() and fallback_relative is not None:
        path = (here.parents[2] / fallback_relative).absolute()
    key = f"{module_name}:{path.as_posix()}"
    cached = sys.modules.get(key)
    if cached is not None:
        return cached
    spec = importlib.util.spec_from_file_location(key, path)
    if spec is None or spec.loader is None:
        raise ImportError(f"Unable to load adjacent module: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[key] = module
    try:
        spec.loader.exec_module(module)
    except Exception:
        sys.modules.pop(key, None)
        raise
    return module


HERE = Path(__file__).absolute().parent
_theme_files = _load_adjacent(
    "windows_modern_theme_files", "theme-files.py", "core/transactions/theme-files.py")
_algorithms = _load_adjacent(
    "windows_modern_accent_algorithms", "accent-algorithms.py", "core/palette/accent-algorithms.py")
_renderers = _load_adjacent(
    "windows_modern_accent_renderers", "accent-renderers.py", "core/palette/accent-renderers.py")
_host = _load_adjacent(
    "windows_modern_appearance_host", "appearance-host.py")

# Explicit dependency table across transactions, color/wallpaper algorithms,
# and scheme/Kvantum renderers. Kept as a dict so callers and tests can inspect
# or stub individual Collaborator functions without `runpy` execution.
SYNC = {
    "owned_file": _theme_files.owned_file,
    "atomic_write": _theme_files.atomic_write,
    "restore_pending": _theme_files.restore_pending,
    "write_pending": _theme_files.write_pending,
    "PRESET_SHADE_ROLES": _algorithms.PRESET_SHADE_ROLES,
    "PRESET_SWATCH_GRID": _algorithms.PRESET_SWATCH_GRID,
    "PRESET_SWATCH_ORDER": _algorithms.PRESET_SWATCH_ORDER,
    "PRESET_SHADES": _algorithms.PRESET_SHADES,
    "WALLPAPER_ANALYSIS_REVISION": _algorithms.WALLPAPER_ANALYSIS_REVISION,
    "WallpaperFileChangedError": _algorithms.WallpaperFileChangedError,
    "rgb": _algorithms.rgb,
    "derive_manual_palette": _algorithms.derive_manual_palette,
    "derive_custom_palette": _algorithms.derive_custom_palette,
    "derive_custom_lab_palette": _algorithms.derive_custom_lab_palette,
    "derive_automatic_palette": _algorithms.derive_automatic_palette,
    "analyze_wallpapers": _algorithms.analyze_wallpapers,
    "wallpaper_file_identity": _algorithms.wallpaper_file_identity,
    "icc_reference_identity": _algorithms.icc_reference_identity,
    "decode_wallpaper_bitmap": _algorithms.decode_wallpaper_bitmap,
    "contrast_ink": _algorithms.contrast_ink,
    "ROLES": _renderers.ROLES,
    "accent_values": _renderers.accent_values,
    "render_scheme": _renderers.render_scheme,
    "make_bindings": _renderers.make_bindings,
    "patch": _renderers.patch,
    "plan_kvantum": _renderers.plan_kvantum,
    "publish_kvantum_reload": _renderers.publish_kvantum_reload,
}

CONFIG = _host.CONFIG
DATA = _host.DATA
GROUP = "WindowsModernAccent"
KEY = "Palette"
MISSING = _host.MISSING
MODES = _host.MODES
MODE_ROLES = {"dark": "AccentLight2", "light": "AccentDark1"}
LINK_ROLES = {"dark": "AccentLight3", "light": "AccentDark2"}
THEME_ID = _host.THEME_ID
MAX_SCREENS = _host.MAX_SCREENS

WallpaperChangedError = _host.WallpaperChangedError
read = _host.read
bus_string = _host.bus_string
active_activity = _host.active_activity
live_wallpaper_snapshot = _host.live_wallpaper_snapshot
wallpaper_fingerprint = _host.wallpaper_fingerprint
discover_wallpapers = _host.discover_wallpapers
scheme_name = _host.scheme_name
notify_palette = _host.notify_palette


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


def require_wallpaper_snapshot(state, primary_only=False):
    return _host.require_wallpaper_snapshot(
        state,
        primary_only=primary_only,
        file_identity=SYNC["wallpaper_file_identity"],
        icc_identity=SYNC["icc_reference_identity"],
    )


def automatic_state(previous):
    snapshot = discover_wallpapers()
    snapshot["icc_reference"] = SYNC["icc_reference_identity"]()
    revision = SYNC["WALLPAPER_ANALYSIS_REVISION"]
    if (previous and previous["source"] == "automatic"
            and previous.get("analysis_revision") == revision
            and all(previous.get(key) == value for key, value in snapshot.items())):
        return previous
    try:
        palette = SYNC["analyze_wallpapers"](
            [Path(image["path"]) for image in snapshot["wallpapers"]])["palette"]
    except SYNC["WallpaperFileChangedError"] as error:
        raise WallpaperChangedError(str(error)) from error
    except (OSError, ValueError):
        # The selected URL/activity or an input file may have changed even
        # before the analyzer captured its own fingerprints.
        require_wallpaper_snapshot(snapshot)
        raise
    state = {"schema_version": 1, "source": "automatic", "analysis_revision": revision,
             "palette": palette, **snapshot}
    require_wallpaper_snapshot(state)
    return state


def manual_state(selection):
    color = SYNC["rgb"](selection)
    return {"schema_version": 1, "source": "manual", "manual_color": color,
            "palette": SYNC["derive_manual_palette"](color)}


def pending_automatic_state():
    # The default blue is the measured preset, not a sampled wallpaper.
    # A separate pending flag prevents it from being cached as a result.
    return {"schema_version": 1, "source": "automatic", "pending": True,
            "palette": SYNC["derive_manual_palette"]("#0078D4")}


def decode_state(raw):
    if raw is None:
        return None
    state = json.loads(raw)
    if (not isinstance(state, dict) or type(state.get("schema_version")) is not int
            or state["schema_version"] != 1 or state.get("source") not in ("manual", "wallpaper", "automatic")):
        raise ValueError("Unrecognized Windows accent state")
    if "pending" in state:
        if state != pending_automatic_state() or state["pending"] is not True:
            raise ValueError("Invalid pending automatic accent state")
        return state["palette"]
    if state["source"] == "manual" and "manual_color" in state:
        if not isinstance(state["manual_color"], str):
            raise ValueError("Invalid original manual accent color")
        SYNC["rgb"](state["manual_color"])
    if state["source"] == "automatic":
        images = state.get("wallpapers")
        if (not isinstance(state.get("activity"), str) or not isinstance(images, list)
                or not 1 <= len(images) <= MAX_SCREENS
                or any(not isinstance(image, dict) or not isinstance(image.get("path"), str)
                       or not Path(image["path"]).is_absolute()
                       or ("source_path" in image
                           and (not isinstance(image["source_path"], str)
                                or not Path(image["source_path"]).is_absolute()))
                       for image in images)):
            raise ValueError("Invalid automatic wallpaper accent state")
    palette = state.get("palette")
    if (not isinstance(palette, dict) or set(palette) != {"Accent", *SYNC["PRESET_SHADE_ROLES"]}
            or any(not isinstance(value, str) for value in palette.values())):
        raise ValueError("Incomplete Windows accent ramp")
    return {role: SYNC["rgb"](value) for role, value in palette.items()}


def scheme_inputs():
    template = HERE / "WindowsModern.colors.in"
    if not template.is_file():
        template = HERE.parents[1] / "color-schemes/WindowsModern.colors.in"
    return (template.read_text(encoding="utf-8"),
            json.loads((HERE / "palette.json").read_text(encoding="utf-8")))


def render(template, fixed, mode, palette, *, legacy=False):
    selection = palette[MODE_ROLES[mode]] if palette is not None else None
    link = (palette[LINK_ROLES[mode]] if palette is not None and not legacy
            else selection)
    return SYNC["render_scheme"](template, fixed[mode], mode, selection, link).encode("utf-8")


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
        # Accept the exact previous renderer output during migration.
        # Independently edited schemes are still rejected.
        if old not in (base, render(template, fixed, mode, previous),
                       render(template, fixed, mode, previous, legacy=True)):
            raise ValueError(f"Color scheme differs from the installed Windows Modern palette: {path}")
        new = render(template, fixed, mode, desired)
        if old != new:
            pending[path] = (old, new)
    return pending


def active_mode(mode):
    return _host.active_mode(mode, config=CONFIG, reader=read)


def apply_current(mode, native):
    if not active_mode(mode):
        raise ValueError("Active Windows Modern appearance changed during accent synchronization")
    # With an explicit transparent accent, KDE copies the scheme roles
    # without accentBackground(), link adjustment or tinting. It also
    # reapplies the same scheme, unlike the positional scheme command.
    subprocess.run(["plasma-apply-colorscheme", "--accent-color", native[1] or "transparent"],
                   check=True, stdout=subprocess.DEVNULL)


def parse_colors(data):
    parser = configparser.ConfigParser(interpolation=None, strict=False, delimiters=("=",))
    parser.optionxform = str
    parser.read_string(data.decode("utf-8"))
    return parser


def live_matches(path, template, fixed, mode, palette):
    # With a transparent native accent, Plasma 6.8.3's colorsapplicator
    # copies all twelve roles in each Colors group and six WM roles.
    # A scheme hash alone does not establish that the roles were applied.
    # Read one local config snapshot instead of spawning a process per
    # color; values absent from that snapshot cannot count as verified.
    expected_data = render(template, fixed, mode, palette)
    if path.read_bytes() != expected_data:
        return False
    if read("General", "ColorSchemeHash") != hashlib.sha1(expected_data).hexdigest():
        return False
    try:
        expected = parse_colors(expected_data)
        actual = parse_colors((CONFIG / "kdeglobals").read_bytes())
        for group in expected.sections():
            if not (group.startswith("Colors:") or group == "WM"):
                continue
            if not actual.has_section(group):
                return False
            for key, value in expected.items(group):
                live = actual.get(group, key, fallback=None)
                if live is None or SYNC["rgb"](live) != SYNC["rgb"](value):
                    return False
        return True
    except (OSError, UnicodeError, ValueError, configparser.Error):
        return False


def synchronize(mode, action, inputs):
    if not active_mode(mode):
        raise ValueError("Select the active Windows Modern appearance first")
    raw = read(GROUP, KEY)
    previous = decode_state(raw)
    if action in ("sync", "reapply", "native") and previous is None:
        return None
    native = native_accent()
    initializing = action == "initialize"
    if initializing:
        # Initialization is only for an unconfigured install. An existing
        # Windows selection or explicit KDE wallpaper/manual choice wins.
        if raw is not None:
            return False
        if any(native) or read("General", "accentColorFromWallpaper") is not None:
            return None
        action = "automatic"
    fresh_state = None
    explicit_files = None
    explicit_reference = None

    def verify_source():
        if fresh_state is not None:
            require_wallpaper_snapshot(fresh_state)
        if explicit_files is not None:
            try:
                if (SYNC["icc_reference_identity"]() != explicit_reference
                        or any(SYNC["wallpaper_file_identity"](path) != identity
                               for path, identity in explicit_files.items())):
                    raise WallpaperChangedError("Selected wallpaper changed during publication")
            except WallpaperChangedError:
                raise
            except (OSError, ValueError) as error:
                raise WallpaperChangedError("Selected wallpaper changed during publication") from error

    if action in ("manual", "wallpaper", "automatic"):
        if any(native):
            raise ValueError("Select 'From current color scheme' in KDE Colors before using Windows accent control")
        state = {"schema_version": 1, "source": action}
        if action == "manual":
            state = manual_state(inputs[0])
        elif action == "wallpaper":
            paths = [Path(path) for path in inputs]
            explicit_files = {path: SYNC["wallpaper_file_identity"](path) for path in paths}
            explicit_reference = SYNC["icc_reference_identity"]()
            try:
                state["palette"] = SYNC["analyze_wallpapers"](paths)["palette"]
            except SYNC["WallpaperFileChangedError"] as error:
                raise WallpaperChangedError(str(error)) from error
            except (OSError, ValueError):
                verify_source()
                raise
        else:
            try:
                state = automatic_state(json.loads(raw) if raw is not None else None)
                fresh_state = state
            except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
                if not initializing:
                    raise
                # The shell may still be loading its new wallpaper. Store
                # the automatic request, but never cache a guessed sample.
                print(f"Automatic wallpaper accent awaiting a settled image: {error}", file=sys.stderr)
                state = pending_automatic_state()
        desired_raw = json.dumps(state, separators=(",", ":"), sort_keys=True)
        desired = decode_state(desired_raw)
    elif action == "native" or any(native):
        # An explicit native KDE color selection wins over our stored ramp.
        desired_raw = desired = None
    else:
        desired_raw, desired = raw, previous
        state = json.loads(raw)
        if state["source"] == "manual" and "manual_color" in state:
            # Recompute from the original input, not the normalized Accent.
            # Keep the saved ramp as the ownership/rollback reference.
            updated = manual_state(state["manual_color"])
            if updated != state:
                desired_raw = json.dumps(updated, separators=(",", ":"), sort_keys=True)
                desired = decode_state(desired_raw)
        elif action == "sync" and state["source"] == "automatic":
            try:
                updated = automatic_state(state)
                candidate_raw = json.dumps(updated, separators=(",", ":"), sort_keys=True)
                desired_raw, desired = candidate_raw, decode_state(candidate_raw)
                fresh_state = updated
            except WallpaperChangedError:
                # An accepted snapshot became stale while being analyzed.
                # Preserve the prior state and let the bounded shell retry run.
                raise
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
    # Non-Kvantum and system-only Kvantum setups may omit ~/.config/Kvantum/Windows-modern;
    # plan_kvantum cleanly returns {} when absent while still failing closed if
    # user-local Kvantum assets exist with missing, modified, or symlinked files.
    kvdir = CONFIG / "Kvantum/Windows-modern"
    for name in MODES:
        color = desired[MODE_ROLES[name]] if desired is not None else fixed[name]["accent"]
        link = desired[LINK_ROLES[name]] if desired is not None else color
        prepared = SYNC["plan_kvantum"](kvdir, name, color, link)
        # In native mode the active shade is only known after KDE applies
        # the base scheme. Validate the active atlas now but update it later.
        if desired is not None or name != mode:
            pending.update(prepared)
    scheme = directory / (scheme_name(mode) + ".colors")
    refresh = (desired is None or scheme in pending or not live_matches(scheme, template, fixed, mode, desired))
    if not pending and not refresh and desired_raw == raw:
        verify_source()
        if not active_mode(mode) or native_accent() != native or read(GROUP, KEY) != raw:
            raise ValueError("Appearance changed during accent verification")
        return False

    # Do not revalidate the deliberately retained ramp on a failed
    # discovery or a mode-switch reapply. Only a fresh automatic result
    # must still refer to the currently loaded wallpaper.
    verify_source()
    if not active_mode(mode) or native_accent() != native:
        raise ValueError("KDE appearance changed while preparing the accent")
    if read(GROUP, KEY) != raw:
        raise ValueError("Windows accent selection changed while preparing the accent")
    written = SYNC["write_pending"](pending)
    native_pending, native_written = {}, []
    state_write_attempted = False
    try:
        if refresh:
            apply_current(mode, native)
        if native_accent() != native or not active_mode(mode):
            raise ValueError("KDE appearance changed during accent synchronization")
        if desired is not None:
            if not live_matches(scheme, template, fixed, mode, desired):
                raise ValueError("KDE did not publish the requested Windows accent roles")
        else:
            selection = read("Colors:Selection", "BackgroundNormal")
            if selection is None:
                raise ValueError("Missing effective KDE selection color")
            native_pending = SYNC["plan_kvantum"](kvdir, mode, selection)
            native_written = SYNC["write_pending"](native_pending)
        verify_source()
        if native_accent() != native or not active_mode(mode):
            raise ValueError("KDE appearance changed while committing the accent")
        if read(GROUP, KEY) != raw:
            raise ValueError("Windows accent selection changed during accent synchronization")
        if desired_raw != raw:
            state_write_attempted = True
            write_state(desired_raw)
            if read(GROUP, KEY) != desired_raw:
                raise ValueError("Windows accent state was not saved")
        # Recheck the selection and source after writing the saved state.
        # An event arriving during publication must not become a false
        # successful update just because the renderer files were written.
        verify_source()
        if not active_mode(mode) or native_accent() != native or read(GROUP, KEY) != desired_raw:
            raise ValueError("Appearance changed after accent publication")
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
            if state_write_attempted and read(GROUP, KEY) == desired_raw:
                write_state(raw)
            if active_mode(mode):
                apply_current(mode, native_accent())
                notify_palette()
        except (OSError, ValueError, subprocess.CalledProcessError) as error:
            print(f"Accent configuration rollback incomplete: {error}", file=sys.stderr)
        raise
    return bool(pending or native_pending or refresh or desired_raw != raw)


def status_snapshot():
    lookfeel = read("KDE", "LookAndFeelPackage")
    if lookfeel is None and (CONFIG / "kdedefaults/package").is_file():
        try:
            lookfeel = (CONFIG / "kdedefaults/package").read_text(encoding="utf-8").strip()
        except OSError:
            lookfeel = None
    scheme = read("General", "ColorScheme")
    mode = "dark" if scheme == "WindowsModernDark" else "light" if scheme == "WindowsModernLight" else "custom"
    try:
        native_wp, native_rgb = native_accent()
    except ValueError:
        native_wp, native_rgb = False, None
    raw = read(GROUP, KEY)
    accent_source = "native"
    pending = False
    manual_color = None
    palette = None
    if raw is not None and not (native_wp or native_rgb):
        try:
            parsed = json.loads(raw)
            palette = decode_state(raw)
            accent_source = parsed.get("source", "native")
            pending = parsed.get("pending") is True
            manual_color = (SYNC["rgb"](parsed["manual_color"])
                            if "manual_color" in parsed else palette.get("Accent"))
        except (ValueError, KeyError, TypeError):
            palette = None
    selection_raw = read("Colors:Selection", "BackgroundNormal")
    try:
        effective_selection = SYNC["rgb"](selection_raw) if selection_raw else None
    except ValueError:
        effective_selection = None
    active_accent = palette["Accent"] if palette else (native_rgb or effective_selection or "#0078D4")
    home_off = Path.home() / ".local/share/windows-modern/transparency-off"
    data_off = DATA / "windows-modern/transparency-off"
    transparency_off = (data_off.exists() or data_off.is_symlink()
                        or home_off.exists() or home_off.is_symlink())
    return {
        "active_package": lookfeel == THEME_ID,
        "mode": mode,
        "accent_source": accent_source,
        "pending": pending,
        "manual_color": manual_color,
        "active_accent": active_accent,
        "palette": palette,
        "native_override": bool(native_wp or native_rgb),
        "native_wallpaper_accent": bool(native_wp),
        "native_accent_color": native_rgb,
        "transparency_enabled": not transparency_off,
        "swatch_grid": [list(row) for row in SYNC["PRESET_SWATCH_GRID"]],
    }


def main():
    if sys.argv[1:] == ["--status-json"]:
        if os.geteuid() == 0:
            sys.exit("Run accent control as the desktop user")
        print(json.dumps(status_snapshot(), separators=(",", ":"), sort_keys=True))
        return
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=MODES)
    parser.add_argument("action", choices=("sync", "reapply", "manual", "wallpaper", "automatic", "native", "initialize"))
    parser.add_argument("inputs", nargs="*")
    args = parser.parse_args()
    if ((args.action == "manual" and len(args.inputs) != 1)
            or (args.action == "wallpaper" and not args.inputs)
            or (args.action in ("sync", "reapply", "automatic", "native", "initialize") and args.inputs)):
        parser.error("manual requires one RGB value; wallpaper requires one or more image paths")
    if os.geteuid() == 0:
        parser.error("Run accent control as the desktop user")
    try:
        changed = synchronize(args.mode, args.action, args.inputs)
    except WallpaperChangedError as error:
        parser.exit(75, f"Windows accent control: {error}\n")
    except (OSError, ValueError, KeyError, TypeError, ET.ParseError, subprocess.SubprocessError) as error:
        parser.exit(1, f"Windows accent control: {error}\n")
    print("native" if changed is None else "changed" if changed else "unchanged")


if __name__ == "__main__":
    main()
