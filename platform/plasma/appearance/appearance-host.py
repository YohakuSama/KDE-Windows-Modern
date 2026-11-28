# SPDX-License-Identifier: GPL-3.0-or-later
"""Shared KDE desktop session queries and live wallpaper discovery.

Both `accent-control.py` and `window-frames.py` consume this module for KDE
configuration reads, active mode/renderer checks, live wallpaper snapshots
through the shell D-Bus bridge, and desktop refresh signals without executing
each other via `runpy`.
"""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys


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


_algorithms = _load_adjacent(
    "windows_modern_accent_algorithms", "accent-algorithms.py", "core/palette/accent-algorithms.py")

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
DATA = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
MISSING = "__windows_modern_missing_accent_key__"
MODES = ("dark", "light")
THEME_ID = "org.kde.windowsmodern.dark"
MAX_SCREENS = 16


class WallpaperChangedError(ValueError):
    """A previously accepted wallpaper snapshot became stale; retry the event."""


def scheme_name(mode):
    return "WindowsModern" + mode.capitalize()


def kvantum_style_for_mode(mode):
    return "kvantum-dark" if mode == "dark" else "kvantum"


def read(group, key):
    value = subprocess.check_output(["kreadconfig6", "--file", "kdeglobals",
                                     "--group", group, "--key", key,
                                     "--default", MISSING], text=True).rstrip("\n")
    return None if value == MISSING else value


def read_config(file, group, key):
    return subprocess.check_output(
        ["kreadconfig6", "--file", file, "--group", group, "--key", key],
        text=True).rstrip("\n")


def active_mode(mode, *, config=None, reader=None):
    cfg = CONFIG if config is None else config
    get = read if reader is None else reader
    package = get("KDE", "LookAndFeelPackage")
    defaults = cfg / "kdedefaults/package"
    if package is None and defaults.is_file():
        package = defaults.read_text(encoding="utf-8").strip()
    return package == THEME_ID and get("General", "ColorScheme") == scheme_name(mode)


def kvantum_active(mode, *, reader=None, config_reader=None):
    get = read if reader is None else reader
    get_cfg = read_config if config_reader is None else config_reader
    style = get("KDE", "widgetStyle")
    if style is None or style.lower() != kvantum_style_for_mode(mode):
        return False
    return get_cfg("Kvantum/kvantum.kvconfig", "General", "theme") == "Windows-modern"


def aurorae_active(mode, *, config_reader=None):
    get_cfg = read_config if config_reader is None else config_reader
    return (get_cfg("kwinrc", "org.kde.kdecoration2", "library") == "org.kde.kwin.aurorae"
            and get_cfg("kwinrc", "org.kde.kdecoration2", "theme")
            == f"__aurorae__svg__windows-modern-{mode}-aurorae")


def bus_string(service, path, interface, method, *args):
    result = json.loads(subprocess.check_output(
        ["busctl", "--user", "--json=short", "--timeout=3s", "call",
         service, path, interface, method, *args], text=True, timeout=5))
    if (not isinstance(result, dict) or result.get("type") != "s"
            or not isinstance(result.get("data"), list) or len(result["data"]) != 1
            or not isinstance(result["data"][0], str)):
        raise ValueError("Unexpected desktop D-Bus reply")
    return result["data"][0]


def active_activity():
    return bus_string("org.kde.ActivityManager", "/ActivityManager/Activities",
                      "org.kde.ActivityManager.Activities", "CurrentActivity")


def live_wallpaper_snapshot(activity, primary_only=False):
    # The shell bridge reads the committed, loaded image from the native
    # Plasma 6.8 ImageStackView. No package ranking or DPI guess is needed.
    return json.loads(bus_string(
        "org.kde.plasmashell", "/WindowsModernWallpaper",
        "org.kde.WindowsModern.Wallpaper",
        "primarySnapshot" if primary_only else "snapshot", "s", activity))


def wallpaper_fingerprint(path, *, file_identity=None):
    identify = _algorithms.wallpaper_file_identity if file_identity is None else file_identity
    return {"path": str(path), **identify(path)}


def discover_wallpapers(primary_only=False, *, file_identity=None):
    activity = active_activity()
    snapshot = (live_wallpaper_snapshot(activity, primary_only=True)
                if primary_only else live_wallpaper_snapshot(activity))
    if not isinstance(snapshot, dict):
        raise ValueError("Invalid live wallpaper snapshot")
    if "error" in snapshot:
        raise ValueError(str(snapshot["error"]))
    count = snapshot.get("screens")
    images = snapshot.get("images")
    if (type(count) is not int or not 1 <= count <= MAX_SCREENS
            or not isinstance(images, list) or len(images) != count):
        raise ValueError("Incomplete live wallpaper snapshot")
    if primary_only and count != 1:
        raise ValueError("Expected a primary-only wallpaper snapshot")
    wallpapers = []
    for screen, image in enumerate(images):
        if (not isinstance(image, dict) or type(image.get("screen")) is not int
                or image["screen"] != screen or not isinstance(image.get("path"), str)):
            raise ValueError("Invalid or duplicate live wallpaper screen")
        path = Path(image["path"])
        if not path.is_absolute():
            raise ValueError("Expected a local absolute wallpaper image path")
        source = path
        path = source.resolve(strict=True)
        fingerprint = wallpaper_fingerprint(path, file_identity=file_identity)
        # Retain the selected path as well as its resolved file. Watching
        # only the latter misses replacement of a selected symbolic link.
        if source != path:
            fingerprint["source_path"] = str(source)
        # Preserve one occurrence per active screen, even for identical paths.
        wallpapers.append(fingerprint)
    if activity != active_activity():
        raise WallpaperChangedError("Desktop activity changed during wallpaper discovery")
    return {"activity": activity, "wallpapers": wallpapers}


def require_wallpaper_snapshot(state, primary_only=False, *, file_identity=None, icc_identity=None):
    expected = {key: state[key] for key in ("activity", "wallpapers")}
    try:
        current = (discover_wallpapers(primary_only=True, file_identity=file_identity)
                   if primary_only else discover_wallpapers(file_identity=file_identity))
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        raise WallpaperChangedError("Previously accepted wallpaper is no longer ready") from error
    if current != expected:
        raise WallpaperChangedError("Desktop wallpaper changed during color analysis or publication")
    if "icc_reference" in state:
        resolve_icc = _algorithms.icc_reference_identity if icc_identity is None else icc_identity
        try:
            reference = resolve_icc()
        except (OSError, ValueError) as error:
            raise WallpaperChangedError("ICC reference changed during publication") from error
        if reference != state["icc_reference"]:
            raise WallpaperChangedError("ICC reference changed during publication")


def notify_palette():
    # KDE's same-scheme CLI may emit its notification before the last
    # config sync. Publish once more after verifying the on-disk roles.
    subprocess.run(["busctl", "--user", "emit", "/KGlobalSettings",
                    "org.kde.KGlobalSettings", "notifyChange", "ii", "0", "0"],
                   check=True)
