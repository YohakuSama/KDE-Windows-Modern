#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Opt-in integration capture: run under xvfb-run and dbus-run-session
# as a separate disposable desktop-test user, never the owner's session.
set -euo pipefail
build=$(realpath "${1:?compiled applet build root}")
mkdir -p "${2:?screenshot output directory}"
out=$(realpath "$2")
src=$(cd "$(dirname "$0")/../.." && pwd)
if [[ ${WM_DISPOSABLE_DESKTOP:-} != 1 || -z ${DISPLAY:-} || -z ${DBUS_SESSION_BUS_ADDRESS:-} || $UID == 0 ]]; then
    echo "Requires a disposable non-root user, Xvfb and a private D-Bus session." >&2
    exit 1
fi
if busctl --user --list --no-pager | awk '$1 == "org.kde.plasmashell" {found=1} END {exit !found}'; then
    echo "Refusing to modify an existing Plasma session." >&2
    exit 1
fi
for command in weston kwin_wayland plasmashell kscreen-doctor plasma-apply-lookandfeel kreadconfig6 import dbus-update-activation-environment busctl python3; do
    command -v "$command" >/dev/null || { echo "Missing dependency: $command" >&2; exit 1; }
done
for plugin in systemtray/lib/plasma/applets/org.kde.windowsmodern.systemtray.so icontasks/lib/plasma/applets/org.kde.plasma.icontasks.so contextmenu/lib/plasma/containmentactions/org.kde.windowsmodern.contextmenu.so; do
    [[ -s "$build/$plugin" ]] || { echo "Missing compiled plugin: $build/$plugin" >&2; exit 1; }
done
work=$(mktemp -d)
export XDG_RUNTIME_DIR="$work/run" XDG_DATA_HOME="$work/data" XDG_CONFIG_HOME="$work/config" XDG_CACHE_HOME="$work/cache"
mkdir -m 700 "$XDG_RUNTIME_DIR" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
export QT_PLUGIN_PATH="$build/systemtray/lib:$build/icontasks/lib:$build/contextmenu/lib${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
export XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE KDE_SESSION_VERSION=6
export WAYLAND_DISPLAY=wm-ci-wayland
mkdir -p "$XDG_DATA_HOME/plasma/plasmoids"
for kind in desktoptheme look-and-feel layout-templates; do
    ln -s "$src/plasma/$kind" "$XDG_DATA_HOME/plasma/$kind"
done
for name in startmenu digitalclock search taskview showdesktop; do
    ln -s "$src/plasma/applets/org.kde.windowsmodern.$name" "$XDG_DATA_HOME/plasma/plasmoids/"
done
ln -s "$src/color-schemes" "$XDG_DATA_HOME/color-schemes"
ln -s "$src/icons" "$XDG_DATA_HOME/icons"
ln -s "$src/wallpaper" "$XDG_DATA_HOME/wallpapers"
shell_pid=""
kwin_pid=""
host_pid=""
finish() {
    local rc=$?
    if ((rc)); then
        for log in "$out/host.log" "$out/kwin.log" "$out/plasma.log"; do
            [[ -f "$log" ]] && tail -45 "$log" >&2
        done
    fi
    if [[ -n "$shell_pid" ]]; then kill "$shell_pid" 2>/dev/null || true; fi
    if [[ -n "$kwin_pid" ]]; then kill "$kwin_pid" 2>/dev/null || true; fi
    if [[ -n "$host_pid" ]]; then kill "$host_pid" 2>/dev/null || true; fi
    for pid in "$shell_pid" "$kwin_pid" "$host_pid"; do
        if [[ -n "$pid" ]]; then wait "$pid" 2>/dev/null || true; fi
    done
    rm -rf -- "$work"
}
trap finish EXIT
export QT_FORCE_STDERR_LOGGING=1
# A GL/DMA-BUF-capable renderer is required by recent nested KWin builds.
# Do not force software rendering or claim success if capture cannot start.
renderer=${WM_NESTED_WESTON_RENDERER:-gl}
if [[ $renderer != gl && $renderer != pixman ]]; then
    echo "WM_NESTED_WESTON_RENDERER must be gl or pixman." >&2
    exit 1
fi
weston --no-config --backend=x11 --renderer="$renderer" --shell=kiosk-shell.so --width=1920 --height=1080 --socket=wm-host --idle-time=0 >"$out/host.log" 2>&1 &
host_pid=$!
for _ in {1..100}; do
    [[ -S "$XDG_RUNTIME_DIR/wm-host" ]] && break
    kill -0 "$host_pid"
    sleep 0.2
done
[[ -S "$XDG_RUNTIME_DIR/wm-host" ]]
# The distro binary may carry CAP_SYS_NICE, outside the CI capability set.
# Execute the same bytes as an ordinary user without requesting that capability.
install -m 0755 "$(command -v kwin_wayland)" "$work/kwin_wayland"
"$work/kwin_wayland" --wayland-display wm-host --fullscreen --width 1920 --height 1080 --socket "$WAYLAND_DISPLAY" --no-lockscreen >"$out/kwin.log" 2>&1 &
kwin_pid=$!
export QT_QPA_PLATFORM=wayland
dbus-update-activation-environment QT_FORCE_STDERR_LOGGING DISPLAY WAYLAND_DISPLAY QT_QPA_PLATFORM QT_PLUGIN_PATH XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_RUNTIME_DIR XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME
for _ in {1..100}; do
    [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]] && break
    kill -0 "$kwin_pid"
    sleep 0.2
done
[[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]
plasmashell >"$out/plasma.log" 2>&1 &
shell_pid=$!
for _ in {1..100}; do
    busctl --user --list --no-pager | awk '$1 == "org.kde.plasmashell" {found=1} END {exit !found}' && break
    kill -0 "$shell_pid"
    sleep 0.2
done
for mode in dark light; do
    timeout 60 plasma-apply-lookandfeel -a "org.kde.windowsmodern.$mode" --resetLayout
    [[ $(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage) == "org.kde.windowsmodern.$mode" ]]
    for _ in {1..100}; do
        if grep -Fq "$build/systemtray/lib/plasma/applets/org.kde.windowsmodern.systemtray.so" "/proc/$shell_pid/maps" &&
           grep -Fq "$build/icontasks/lib/plasma/applets/org.kde.plasma.icontasks.so" "/proc/$shell_pid/maps"; then break; fi
        sleep 0.2
    done
    grep -Fq "$build/systemtray/lib/plasma/applets/org.kde.windowsmodern.systemtray.so" "/proc/$shell_pid/maps"
    grep -Fq "$build/icontasks/lib/plasma/applets/org.kde.plasma.icontasks.so" "/proc/$shell_pid/maps"
    for scale in 1 1.25 1.5 2; do
        output=$(kscreen-doctor -j | python3 -c 'import json,sys; print(next(x["id"] for x in json.load(sys.stdin)["outputs"] if x["enabled"]))')
        kscreen-doctor "output.$output.scale.$scale"
        python3 - "$out/$mode-$scale.json" "$output" "$scale" <<'CHECK_SCALE'
import json
from pathlib import Path
import subprocess
import sys
import time

destination, output_id, scale = sys.argv[1:]
for _ in range(35):
    snapshot = subprocess.check_output(["kscreen-doctor", "-j"], text=True)
    for display in json.loads(snapshot)["outputs"]:
        if display["enabled"] and display["id"] == int(output_id) and abs(display["scale"] - float(scale)) < 0.001:
            Path(destination).write_text(snapshot)
            sys.exit(0)
    time.sleep(0.2)
sys.exit(f"Output {output_id} did not reach scale {scale}")
CHECK_SCALE
        sleep 1
        import -display "$DISPLAY" -window root "$out/$mode-$scale.png"
        [[ -s "$out/$mode-$scale.png" ]]
    done
done
if grep -Ei '(qrc:/qt/qml/plasma/applet/org/kde/windowsmodern|org\.kde\.windowsmodern\.).*(Type .* unavailable|Property has already been assigned|Cannot assign|is not a type|is not a function)' "$out/plasma.log"; then exit 1; fi
