#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Run under xvfb-run and a private session bus as a new CI user with no desktop.
set -euo pipefail
build=$(realpath "${1:?compiled applet build root}")
out=$(realpath "${2:?screenshot output directory}")
src=$(cd "$(dirname "$0")/../.." && pwd)
[[ ${WM_DISPOSABLE_DESKTOP:-} == 1 && -n ${DISPLAY:-} && -n ${DBUS_SESSION_BUS_ADDRESS:-} ]]
work=$(mktemp -d)
export XDG_RUNTIME_DIR="$work/run" XDG_DATA_HOME="$work/data" XDG_CONFIG_HOME="$work/config" XDG_CACHE_HOME="$work/cache"
mkdir -m 700 "$XDG_RUNTIME_DIR" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
export QT_PLUGIN_PATH="$build/systemtray/lib:$build/icontasks/lib${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
export XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE KDE_SESSION_VERSION=6
export WAYLAND_DISPLAY=wm-ci-wayland LIBGL_ALWAYS_SOFTWARE=1
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
}
trap finish EXIT
export QT_FORCE_STDERR_LOGGING=1
# Nested KWin 6.8 needs DRI3 on an X11 parent. Weston supplies a wl_shm
# parent on Xvfb, allowing KWin's Wayland backend to use software rendering.
weston --no-config --backend=x11 --renderer=pixman --shell=kiosk-shell.so --width=1920 --height=1080 --socket=wm-host --idle-time=0 >"$out/host.log" 2>&1 &
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
    done
done
if grep -Ei '(qrc:/qt/qml/plasma/applet/org/kde/windowsmodern|org\.kde\.windowsmodern\.).*(Type .* unavailable|Property has already been assigned|Cannot assign|is not a type)' "$out/plasma.log"; then exit 1; fi
