"""Live-session helpers: screenshots, KWin D-Bus calls, the user journal."""

import json
import pathlib
import subprocess
import time


def _spectacle_last_save(value=None):
    """Read, or with value write back, Spectacle's remembered save location."""
    args = ["--file", "spectaclerc", "--group", "ImageSave", "--key", "lastImageSaveLocation"]
    if value is None:
        return subprocess.run(["kreadconfig6", *args], capture_output=True, text=True).stdout.strip()
    if value:
        subprocess.run(["kwriteconfig6", *args, value], check=False)
    else:
        subprocess.run(["kwriteconfig6", *args, "--delete"], check=False)
    return value


def screenshot(path):
    # Spectacle remembers every --output path as the user's last save
    # location ("Save As" then opens in our temp folder). Put it back.
    pathlib.Path(path).parent.mkdir(parents=True, exist_ok=True)
    saved = _spectacle_last_save()
    try:
        subprocess.run(["spectacle", "--background", "--nonotify", "--fullscreen", "--output", str(path)],
                       timeout=30, check=True)
        # spectacle can return before it has saved (it may hand the capture
        # to a running instance) and writes its config after the file.
        end = time.time() + 10
        while time.time() < end and not pathlib.Path(path).exists():
            time.sleep(0.1)
        time.sleep(0.5)
    finally:
        _spectacle_last_save(saved)


def kwin_call(path, method, *args):
    return subprocess.run(["dbus-send", "--session", "--print-reply", "--type=method_call",
                           "--dest=org.kde.KWin", path, method, *args],
                          capture_output=True, text=True).stdout


def kwin_property(name):
    reply = kwin_call("/KWin", "org.freedesktop.DBus.Properties.Get", "string:org.kde.KWin", f"string:{name}")
    return reply.split()[-1] if reply else None


def kwin_reconfigure():
    kwin_call("/KWin", "org.kde.KWin.reconfigure")


def now():
    return time.strftime("%Y-%m-%d %H:%M:%S")


def journal(since, comm=None):
    args = ["journalctl", "--user", "-b", "--since", since, "--no-pager", "-o", "cat"]
    if comm:
        args.append(f"_COMM={comm}")
    return subprocess.run(args, capture_output=True, text=True).stdout.splitlines()


def qml_warnings(since, comm="plasmashell", ignore=()):
    """QML warnings (lines carrying a qrc:/ or file:/ location) since a time."""
    return [line for line in journal(since, comm)
            if ("qrc:/" in line or "file:/" in line) and not any(i in line for i in ignore)]


class Checks:
    """Collects PASS/FAIL lines; a scenario fails if any check fails."""

    def __init__(self):
        self.failures = []

    def check(self, ok, message):
        print(("  PASS  " if ok else "  FAIL  ") + message)
        if not ok:
            self.failures.append(message)
        return ok


def dump(obj):
    return json.dumps(obj, ensure_ascii=False)


def _longest_span(values):
    threshold = max(10, max(values, default=0) * 0.25)
    spans = []
    start = None
    for i, value in enumerate([*values, 0]):
        if value >= threshold:
            if start is None:
                start = i
        elif start is not None:
            spans.append((start, i))
            start = None
    if not spans:
        raise RuntimeError("No stable popup edge detected in screenshot")
    return max(spans, key=lambda span: span[1] - span[0])


def popup_bounds(closed_path, opened_path, minimum_fraction=0.15):
    """Physical screenshot bounds, independent of Wayland client coordinates.

    Compare with a static closed desktop. Ignore small taskbar/cursor changes
    using the longest substantial changed row and column spans. Fail instead
    of reporting an invented location when contrast is insufficient.
    """
    from PIL import Image, ImageChops

    with Image.open(closed_path) as a, Image.open(opened_path) as b:
        if a.size != b.size:
            raise RuntimeError("Display geometry changed during capture")
        diff = ImageChops.difference(a.convert("RGB"), b.convert("RGB"))
        red, green, blue = diff.split()
        mask = ImageChops.lighter(ImageChops.lighter(red, green), blue).point(
            lambda v: 255 if v > 12 else 0)
        width, height = mask.size
        top, bottom = _longest_span(list(mask.resize((1, height), Image.Resampling.BOX).getdata()))
        middle = mask.crop((0, top, width, bottom))
        left, right = _longest_span(list(middle.resize((width, 1), Image.Resampling.BOX).getdata()))
        if right - left < width * minimum_fraction or bottom - top < height * minimum_fraction:
            raise RuntimeError("Popup capture is inconclusive; use a static, contrasting desktop")
        if right - left >= width * 0.98 or bottom - top >= height * 0.98:
            raise RuntimeError("Background changed or capture has no reliable popup boundary")
        return (left, top, right - left, bottom - top)
