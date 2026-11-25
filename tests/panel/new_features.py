#!/usr/bin/env python3
"""Click through the optional Search/Task View buttons and the calendar zoom.

  search    Search is wider than Start at the same height; both Search
            entrypoints and query changes retain the Search rectangle.
            Run on one display with a static desktop
  taskview  clicking Task View opens KWin's Overview
  calendar  the clock flyout's title zooms out to the year; reopening shows
            today's month again
  dayshape  picking a day leaves the calendar where it was (the agenda used
            to grow the popup upwards), and the picked day stays a circle while
            hovered (it turned into a rounded square)

Each scenario closes what it opened (Esc). Screenshots go to OUT_DIR.
Usage: tests/panel/new_features.py OUT_DIR [SCENARIO ...]
"""
import pathlib
import re
import subprocess
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from evdev import ecodes as e  # noqa: E402
from PIL import Image  # noqa: E402
import json  # noqa: E402

from e2e import a11y  # noqa: E402
from e2e.session import Checks, screenshot, popup_bounds  # noqa: E402
from e2e.vinput import VirtualInput  # noqa: E402


START_NAMES = ("Start", "开始")
SEARCH_NAMES = ("Search", "搜索")
HOME_FIELDS = ("Search for apps, settings, and files", "Search for apps, settings and files",
               "搜索应用、设置和文件")
SEARCH_FIELDS = ("Type here to search", "在此处输入以搜索")


def start_button():
    return next((n for n in a11y.nodes("plasmashell")
                 if n.name in START_NAMES and n.role == "button" and n.showing), None)


def search_field(searching=None):
    button = start_button()
    if button is None:
        return None
    names = HOME_FIELDS + SEARCH_FIELDS if searching is None else (SEARCH_FIELDS if searching else HOME_FIELDS)
    return next((n for n in a11y.nodes("plasmashell")
                 if n.showing and n.window != button.window and n.name in names
                 and n.role in ("entry", "text") and n.rect[2] > 0), None)


def search_result_node():
    button = start_button()
    if button is None:
        return None
    return next((n for n in a11y.nodes("plasmashell")
                 if n.showing and n.window != button.window
                 and n.name in ("All", "全部", "Apps", "应用", "Files", "文件", "Settings", "设置")
                 and n.rect[2] > 0), None)


def taskbar_query(query):
    button = start_button()
    if button is None:
        return None
    return next((n for n in a11y.nodes("plasmashell")
                 if n.showing and n.window == button.window and n.name == query
                 and n.rect[2] > 0), None)


def start_menu_open():
    return search_field() is not None or search_home_node() is not None or search_result_node() is not None


def search_home_node():
    button = start_button()
    if button is None:
        return None
    return next((n for n in a11y.nodes("plasmashell")
                 if n.showing and n.window != button.window
                 and n.name in ("Suggested", "建议", "推荐", "Quick searches", "快速搜索", "Top apps", "热门应用")
                 and n.rect[2] > 0), None)



def overview_active():
    out = subprocess.run(["dbus-send", "--session", "--print-reply", "--dest=org.kde.KWin", "/Effects",
                          "org.freedesktop.DBus.Properties.Get", "string:org.kde.kwin.Effects",
                          "string:activeEffects"], capture_output=True, text=True).stdout
    return '"overview"' in out


def wait_for(pred, timeout=4.0):
    end = time.time() + timeout
    while time.time() < end:
        if pred():
            return True
        time.sleep(0.2)
    return False


def click_node(vi, name):
    n = a11y.find("plasmashell", name, visible=False)
    if not n:
        raise RuntimeError(f"{name} not found")
    vi.move_to(*n.centre)
    time.sleep(0.3)
    vi.click()


def search(vi, out, c):
    outputs = json.loads(subprocess.check_output(["kscreen-doctor", "-j"], text=True))["outputs"]
    active = [display for display in outputs if display["enabled"]]
    if len(active) != 1:
        raise RuntimeError("Search geometry capture requires a single active output")
    button = start_button()
    if button is None:
        raise RuntimeError("Start button not found")
    search_button = next((n for n in a11y.nodes("plasmashell")
                          if n.window == button.window and n.name in SEARCH_NAMES and n.showing), None)
    if search_button is None:
        raise RuntimeError("Enable the taskbar Search button before the test")
    vi.tap(e.KEY_ESC, after=0.6)
    if not c.check(not start_menu_open(), "Start and Search closed before baseline"):
        return

    def shot(name):
        path = out / (name + ".png")
        path.unlink(missing_ok=True)
        time.sleep(0.6)
        screenshot(path)
        return path

    baseline = shot("search-geometry-closed")
    expected = {}
    with Image.open(baseline) as img:
        screen_width = img.width

    def capture(name, searching=False, taskbar=False):
        field = search_field(searching)
        node = field or ((search_home_node() or search_result_node()) if taskbar else None)
        if node is None:
            raise RuntimeError("Search surface is not showing")
        window = next((n for n in a11y.nodes("plasmashell")
                       if n.window == node.window and n.depth == 0), None)
        if window is None or window.rect[2] <= 0 or window.rect[3] <= 0:
            raise RuntimeError("No accessible popup window extent")
        rect = popup_bounds(baseline, shot(name))
        local = (field.rect[0] - window.rect[0], field.rect[1] - window.rect[1],
                 field.rect[2], field.rect[3]) if field is not None and field.rect[3] > 0 else None
        print(f"        {name}: physical popup={rect}; logical field={local}")
        key = "taskbar" if taskbar else searching
        if key not in expected:
            expected[key] = (rect, local)
        else:
            # Compare geometry within each entrypoint, not across anchors.
            expected_rect, expected_field = expected[key]
            c.check(max(abs(a - b) for a, b in zip(expected_rect, rect)) <= 3,
                    f"mode position and outer size unchanged ({expected_rect} -> {rect})")
            if expected_field is not None and local is not None:
                c.check(max(abs(a - b) for a, b in zip(expected_field, local)) <= 1,
                        f"mode search field geometry unchanged ({expected_field} -> {local})")
        if searching and False in expected:
            start_rect, _ = expected[False]
            scale = rect[2] / window.rect[2]
            # On exceptionally narrow outputs the shared work-area clamp may
            # limit both surfaces to the same width.
            room_for_wider = screen_width - start_rect[2] > 56 * scale + 3
            c.check(rect[2] > start_rect[2] + 3 if room_for_wider
                    else rect[2] >= start_rect[2] - 3,
                    f"Search wider than Start when space permits ({start_rect[2]} -> {rect[2]})")
            c.check(abs(rect[1] - start_rect[1]) <= 3
                    and abs(rect[3] - start_rect[3]) <= 3,
                    f"same vertical position and height ({start_rect} -> {rect})")
        return rect, local, window.rect

    def click_button(node):
        vi.move_to(*node.centre)
        vi.click()

    try:
        click_button(button)
        if not c.check(wait_for(lambda: search_field(False) is not None), "Start opens normal home"):
            return
        rect, local, win = capture("start-home")
        # On Wayland the popup's AT-SPI children may report local coordinates.
        # Use the photographed surface origin, not guessed screen coordinates.
        scale = rect[2] / win[2]
        if not 0.75 <= scale <= 4:
            raise RuntimeError(f"Inconsistent screenshot/accessibility scale: {scale}")
        fx = round(rect[0] / scale + local[0] + local[2] / 2)
        fy = round(rect[1] / scale + local[1] + local[3] / 2)
        vi.move_to(fx, fy)
        vi.click()
        if not c.check(wait_for(lambda: search_field(True) is not None), "Start input opens search"):
            return
        capture("start-search-click", searching=True)
        vi.type_text("test")
        if not c.check(wait_for(lambda: search_field(True) is not None
                                and search_field(True).text() == "test"), "search accepts typed query"):
            return
        capture("start-search-results", searching=True)
        vi.tap(e.KEY_ESC, after=0.5)
        if c.check(wait_for(lambda: search_field(True) is not None
                            and search_field(True).text() == ""), "Escape clears query"):
            capture("start-search-cleared", searching=True)
        vi.tap(e.KEY_ESC, after=0.6)
        if not c.check(not start_menu_open(), "Escape closes search"):
            return
        click_button(search_button)
        if not c.check(wait_for(start_menu_open), "taskbar Search opens wider Search surface"):
            return
        capture("search-click", searching=True, taskbar=True)
        c.check(search_field(True) is None, "full taskbar Search has no duplicate popup header")
        vi.type_text("test")
        if not c.check(wait_for(lambda: taskbar_query("test") is not None), "taskbar Search mirrors the real typed query"):
            return
        c.check(search_field(True) is None, "committed query remains in taskbar, not popup header")
        capture("taskbar-search-results", searching=True, taskbar=True)
        vi.tap(e.KEY_ESC, after=0.5)
        vi.tap(e.KEY_ESC, after=0.6)
        if not c.check(not start_menu_open(), "taskbar search closes"):
            return
        vi.tap(e.KEY_LEFTMETA, after=0.6)
        if not c.check(wait_for(lambda: search_field(False) is not None), "Meta opens Start"):
            return
        capture("start-meta")
        vi.type_text("test")
        if c.check(wait_for(lambda: search_field(True) is not None
                            and search_field(True).text() == "test"), "Meta typing enters search"):
            capture("start-meta-search", searching=True)
    finally:
        if start_menu_open():
            vi.tap(e.KEY_ESC, after=0.3)
        if start_menu_open():
            vi.tap(e.KEY_ESC, after=0.3)


def taskview(vi, out, c):
    click_node(vi, "Task View")
    c.check(wait_for(overview_active), "clicking Task View opens the Overview")
    vi.tap(e.KEY_ESC, after=0.3)
    c.check(wait_for(lambda: not overview_active()), "Esc closes it")


def texts():
    return {n.name for n in a11y.nodes("plasmashell") if n.showing and n.name}


def calendar(vi, out, c):
    click_node(vi, "Clock")
    time.sleep(1.2)
    screenshot(out / "calendar-month.png")
    # "listopad 2026", "November 2026": a word and a year, nothing else
    month_title = next((t for t in texts() if re.fullmatch(r"[^\d\W][^\d]* \d{4}", t)), None)
    c.check(month_title is not None, f"the flyout shows a 'Month Year' title ({month_title!r})")
    if not month_title:
        vi.tap(e.KEY_ESC, after=0.5)
        return
    click_node(vi, month_title)
    time.sleep(0.8)
    screenshot(out / "calendar-year.png")
    year = month_title[-4:]
    c.check(wait_for(lambda: year in texts() and month_title not in texts()),
            f"the title zooms out to the year ({year})")
    vi.tap(e.KEY_ESC, after=0.6)
    click_node(vi, "Clock")
    time.sleep(1.2)
    c.check(month_title in texts(), "reopening the flyout shows today's month again")
    screenshot(out / "calendar-reopen.png")
    vi.tap(e.KEY_ESC, after=0.5)


def dayshape(vi, out, c):
    click_node(vi, "Clock")
    time.sleep(1.2)
    days = [n for n in a11y.nodes("plasmashell") if n.showing and n.role == "button"
            and re.fullmatch(r"\d{1,2}(, .*)?", n.name) and n.rect[2] > 0]
    today = next((n for n in days if ", today" in n.name), None)
    number = lambda n: int(n.name.split(",")[0])  # noqa: E731
    # A neighbour of today in this month (spill-over days of other months are far off in number).
    pick = next((n for n in days if today and n is not today and 0 < abs(number(n) - number(today)) <= 6), None)
    c.check(pick is not None, f"a day other than today to pick ({pick and (pick.name, pick.rect)!r}, today {today and today.rect!r})")
    if not pick:
        vi.tap(e.KEY_ESC, after=0.5)
        return
    x, y = pick.centre
    vi.move_to(x, y, steps=8)
    time.sleep(0.3)
    vi.click()
    time.sleep(0.8)                                   # picked, pointer still on it: ring + hover fill
    moved = next((n for n in a11y.nodes("plasmashell") if n.showing and n.role == "button"
                  and n.name.split(",")[0] == pick.name.split(",")[0] and n.rect[0] == pick.rect[0]), None)
    c.check(moved is not None and moved.rect == pick.rect,
            f"the calendar does not move when a day is picked ({pick.rect} -> {moved and moved.rect})")
    shot = out / "dayshape.png"
    screenshot(shot)
    im = Image.open(shot).convert("RGB")
    left, top, w, h = pick.rect
    corner = im.getpixel((left + 3, top + 3))
    background = im.getpixel((left + 1, top + 1))      # the very edge of the cell
    fill = im.getpixel((x - w // 4, y))
    painted = lambda p, q: max(abs(a - b) for a, b in zip(p, q)) > 8  # noqa: E731
    c.check(painted(fill, corner), f"the hovered picked day is filled ({fill} vs corner {corner})")
    c.check(not painted(corner, background),
            f"its corners stay unpainted: a circle, not a rounded square ({corner} vs {background})")
    vi.tap(e.KEY_ESC, after=0.5)


SCENARIOS = {"search": search, "taskview": taskview, "calendar": calendar, "dayshape": dayshape}


def main():
    out = pathlib.Path(sys.argv[1]).resolve()
    out.mkdir(parents=True, exist_ok=True)
    chosen = sys.argv[2:] or list(SCENARIOS)
    failed = []
    with a11y.enabled():
        time.sleep(2)
        vi = VirtualInput()
        try:
            vi.announce()
            for name in chosen:
                print(f"scenario {name}")
                c = Checks()
                try:
                    SCENARIOS[name](vi, out, c)
                except Exception as ex:  # noqa: BLE001
                    c.check(False, f"{name} raised {ex!r}")
                    vi.tap(e.KEY_ESC, after=0.5)
                if c.failures:
                    failed.append(name)
        finally:
            vi.close()
    print(f"FAILED: {', '.join(failed)}" if failed else "ALL PASSED")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
