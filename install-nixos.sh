#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Reversible, full desktop test install on NixOS. No nixos-rebuild, sudo or
# modifications to configuration.nix / Home Manager / the running system profile.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/windows-modern-nixos-test"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
SERVICE=plasma-plasmashell.service
[ "$EUID" -ne 0 ] || { echo "请使用 KDE 桌面用户运行，不要 sudo。" >&2; exit 1; }
grep -Eq '^ID="?nixos"?$' /etc/os-release || { echo "此脚本只用于 NixOS。" >&2; exit 1; }
[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] || { echo "请在正在运行的 Plasma 桌面终端执行。" >&2; exit 1; }
command -v flock >/dev/null || { echo "当前系统缺少 flock。" >&2; exit 1; }
mkdir -p "$(dirname "$STATE")"
exec 9>"$(dirname "$STATE")/.windows-modern-nixos-test.lock"
flock -n 9 || { echo "另一项 Windows Modern 测试操作正在执行。" >&2; exit 1; }
action="${1:-}"
variant=dark
for arg in "$@"; do case "$arg" in --light) variant=light ;; --dark) variant=dark ;; esac; done
if [ -z "$action" ] || [ "$action" = menu ]; then
    printf 'Windows Modern · NixOS 完整测试安装\n1. 自动备份、构建、安装\n2. 卸载、恢复原配置、清理测试文件\n'
    read -r -p '请选择 [1/2]：' action
fi
case "$action" in 1|install|all) action=install ;; 2|uninstall|remove) action=uninstall ;; *) echo "仅支持 1 或 2。"; exit 2 ;; esac
systemctl --user cat "$SERVICE" >/dev/null || { echo "未找到 Plasma 用户服务。" >&2; exit 1; }

# Only restore these environment variables. Never reset the rest of the user's environment.
read_env() { systemctl --user show-environment | sed -n "s/^$1=//p" | head -n1; }
remember_env() {
    [ ! -f "$STATE/original-env" ] || return 0
    systemctl --user show-environment | grep -E '^(QT_PLUGIN_PATH|XDG_DATA_DIRS)=' > "$STATE/original-env" || true
}
restore_env() {
    [ -f "$STATE/original-env" ] || return 0
    local key line
    for key in QT_PLUGIN_PATH XDG_DATA_DIRS; do
        line="$(grep -m1 "^$key=" "$STATE/original-env" || true)"
        if [ -n "$line" ]; then systemctl --user set-environment "$line"; else systemctl --user unset-environment "$key"; fi
    done
}
set_profile_env() {
    local plugin="$1" old_qt old_data qt data
    old_qt="$(sed -n 's/^QT_PLUGIN_PATH=//p' "$STATE/original-env")"
    old_data="$(sed -n 's/^XDG_DATA_DIRS=//p' "$STATE/original-env")"
    old_data="${old_data:-/run/current-system/sw/share:/usr/local/share:/usr/share}"
    qt="$plugin${old_qt:+:$old_qt}"
    data="$PROFILE/share:$old_data"
    mkdir -p "$CONFIG/environment.d" "$CONFIG/systemd/user/$SERVICE.d"
    # systemd environment.d also makes the runtime available on the next login.
    printf 'QT_PLUGIN_PATH=%s\nXDG_DATA_DIRS=%s\n' "$qt" "$data" > "$CONFIG/environment.d/90-windows-modern-test.conf"
    printf '[Service]\nEnvironment="QT_PLUGIN_PATH=%s"\nEnvironment="XDG_DATA_DIRS=%s"\n' \
        "$qt" "$data" > "$CONFIG/systemd/user/$SERVICE.d/90-windows-modern-test.conf"
    systemctl --user daemon-reload
    systemctl --user set-environment "QT_PLUGIN_PATH=$qt" "XDG_DATA_DIRS=$data"
}
wait_shell() {
    local n
    for n in {1..30}; do
        if busctl --user status org.kde.plasmashell >/dev/null 2>&1; then return 0; fi
        sleep 1
    done
    echo "Plasma Shell 启动失败。" >&2
    return 1
}
start_shell() { systemctl --user start "$SERVICE"; wait_shell; }
stop_shell() { systemctl --user stop "$SERVICE"; }
unload_scripts() {
    for id in org.kde.windowsmodern.osd org.kde.windowsmodern.snapkeys org.kde.windowsmodern.snaplayouts; do
        busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting unloadScript s "$id" >/dev/null 2>&1 || true
    done
}
restore_original() {
    local result=0
    [ -f "$STATE/original/manifest.json" ] || return 0
    export WM_SHORTCUT_BACKUP="$STATE/shortcut-backup.json"
    "$PYTHON" "$ROOT/scripts/windows-shortcuts.py" restore --group apps || result=1
    "$PYTHON" "$ROOT/scripts/windows-shortcuts.py" restore --group shortcuts || result=1
    unload_scripts
    stop_shell || return 1
    if ! "$PYTHON" "$ROOT/scripts/nixos-test-state.py" restore --root "$ROOT" --state "$STATE" --profile "$PROFILE"; then
        start_shell || true
        return 1
    fi
    systemctl --user daemon-reload || result=1
    restore_env || result=1
    kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
    busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null 2>&1 || true
    start_shell || result=1
    return "$result"
}
finish_cleanup() {
    # Keep a copy of the original snapshot, but remove the test's GC root,
    # resource cache, generated images, build outputs and exact installed files.
    local backups="$(dirname "$STATE")/windows-modern-nixos-backups"
    mkdir -p "$backups"
    local saved
    saved="$(mktemp -d "$backups/$(date +%Y%m%d-%H%M%S).XXXXXX")"
    cp -a "$STATE/original" "$saved/"
    if [ -d "$STATE/before-uninstall" ]; then cp -a "$STATE/before-uninstall" "$saved/"; fi
    # Unlink only the test GC root; do not delete shared Nix store paths.
    rm -rf -- "$STATE"
    printf '原始备份保留于：%s\n' "$saved"
}

if [ "$action" = uninstall ]; then
    if [ ! -f "$STATE/original/manifest.json" ]; then
        if [ -f "$STATE/owned-state" ]; then
            rm -rf -- "$STATE"
            echo "已清理未完成安装的构建链接和临时资源。"
        else
            echo "没有本脚本的安装记录，不删除其他安装或系统文件。"
        fi
        exit 0
    fi
    PROFILE="$(readlink -f "$STATE/runtime")"
    PYTHON="$PROFILE/bin/python3"
    export GI_TYPELIB_PATH="$(cat "$PROFILE/wm-gi-typelib-path")${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
    [ -x "$PYTHON" ] || { echo "测试运行时缺失，保留备份以免丢失原配置。" >&2; exit 1; }
    stop_shell
    if ! "$PYTHON" "$ROOT/scripts/nixos-test-state.py" snapshot-current --root "$ROOT" --state "$STATE" --profile "$PROFILE"; then
        start_shell || true
        echo "卸载前备份失败，未删除测试文件。" >&2
        exit 1
    fi
    restore_original || { echo "恢复未完成，已保留全部备份；请重新运行选项 2。" >&2; exit 1; }
    finish_cleanup
    echo "已卸载测试安装，原始桌面配置已恢复。"
    exit 0
fi

for cmd in nix-build nix systemctl busctl plasmashell plasma-apply-lookandfeel plasma-apply-wallpaperimage \
           kwriteconfig6 kreadconfig6 kbuildsycoca6; do
    command -v "$cmd" >/dev/null || { echo "缺少当前 Plasma 系统命令：$cmd" >&2; exit 1; }
done
systemctl --user is-active --quiet "$SERVICE" || { echo "Plasma 桌面服务未运行。" >&2; exit 1; }
umask 077
if [ -e "$STATE" ] && [ ! -f "$STATE/owned-state" ]; then
    echo "测试目录已存在但没有本脚本的所有权记录：$STATE" >&2
    exit 1
fi
mkdir -p "$STATE"
touch "$STATE/owned-state"
# Prefer the exact nixpkgs revision of the running system, then its pinned
# registry/channel. The build expression and ABI check reject mismatches.
version="$(plasmashell --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
[ -n "$version" ] || { echo "无法获取当前 Plasma 版本。" >&2; exit 1; }
revision="$(nixos-version --json 2>/dev/null | sed -n 's/.*"nixpkgsRevision"[[:space:]]*:[[:space:]]*"\([0-9a-f]\{40\}\)".*/\1/p' || true)"
nixpkgs=""
if [ -n "$revision" ]; then
    nixpkgs="$(nix --extra-experimental-features 'nix-command flakes' eval --raw --impure \
        --expr "(builtins.getFlake \"github:NixOS/nixpkgs/$revision\").outPath" 2>/dev/null || true)"
fi
if [ -z "$nixpkgs" ]; then
    nixpkgs="$(nix --extra-experimental-features 'nix-command flakes' eval --raw --impure \
        --expr '(builtins.getFlake "nixpkgs").outPath' 2>/dev/null || true)"
fi
if [ -z "$nixpkgs" ]; then nixpkgs="$(nix-instantiate --find-file nixpkgs 2>/dev/null || true)"; fi
[ -d "$nixpkgs" ] || { echo "找不到当前系统对应的 nixpkgs。" >&2; exit 1; }
echo "构建 Plasma $version 的系统托盘、任务栏及完整测试运行时……"
nix-build "$ROOT/nix/test-runtime.nix" --argstr nixpkgsPath "$nixpkgs" --argstr plasmaVersion "$version" \
    --out-link "$STATE/runtime-next"
PROFILE="$(readlink -f "$STATE/runtime-next")"
PYTHON="$PROFILE/bin/python3"
export PATH="$PROFILE/bin:$PATH"
export GI_TYPELIB_PATH="$(cat "$PROFILE/wm-gi-typelib-path")${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
"$PYTHON" -c 'from gi.repository import Gio, GLib; import PIL, fontTools'
prefix="$(cat "$PROFILE/wm-qt-plugin-prefix")"
plugin="$PROFILE/$prefix"
tray="$plugin/plasma/applets/org.kde.windowsmodern.systemtray.so"
tasks="$plugin/plasma/applets/org.kde.windowsmodern.icontasks.so"
[ -s "$tray" ] && [ -s "$tasks" ] || { echo "两个 C++ 插件未完整构建。" >&2; exit 1; }

# Exact Qt/Plasma library paths must agree with the live shell, not just
# their major version. An incompatible update is stopped before any settings change.
pid="$(systemctl --user show "$SERVICE" -p MainPID --value)"
"$PYTHON" - "$pid" "$tray" "$tasks" <<'PY'
import pathlib, re, subprocess, sys
pid, *plugins = sys.argv[1:]
maps = pathlib.Path("/proc", pid, "maps").read_text()
for plugin in plugins:
    out = subprocess.check_output(["ldd", plugin], text=True)
    if "not found" in out:
        raise SystemExit("Missing plugin dependency: " + out)
    for stem in ("libQt6Core.so", "libPlasma.so", "libKF6CoreAddons.so"):
        match = re.search(r"^\s*" + re.escape(stem) + r"\S*\s+=>\s+(\S+)", out, re.M)
        if match:
            path = str(pathlib.Path(match[1]).resolve())
            if path not in maps:
                raise SystemExit("Runtime ABI differs from live Plasma: " + path)
PY
# Original owner inputs are staged outside the live desktop. Their exact
# paths and hash verification are shared with the normal importer.
if [ -f "$ROOT/native-resources/resource-manifest.json" ]; then
    input="$ROOT/native-resources"
else
    if [ ! -f "$STATE/resources/resource-manifest.json" ]; then
        bash "$ROOT/scripts/stage-native-resources.sh" "$STATE/resources"
    fi
    input="$STATE/resources"
fi
WM_NATIVE_RESOURCE_SOURCE="$input" WM_NATIVE_ASSETS_DIR="$STATE/native" bash "$ROOT/scripts/prepare-native-assets.sh"
# A successful build/import is not a configuration change. Back up the
# running desktop after stopping the shell so its final settings are flushed.
remember_env
ln -sfn "$STATE/runtime-next" "$STATE/runtime"
rollback() {
    local rc="${1:-$?}"
    trap - ERR EXIT INT TERM
    set +e
    echo "安装未完成，正在恢复安装前的桌面……" >&2
    if [ -f "$STATE/original/manifest.json" ]; then
        restore_original && finish_cleanup || echo "自动恢复失败，备份已保留：$STATE" >&2
    else
        start_shell || true
    fi
    exit "$rc"
}
# Run destructive rollback once in the main shell, including signals.
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'rc=$?; if [ "$rc" -ne 0 ]; then rollback "$rc"; fi' EXIT
stop_shell
"$PYTHON" "$ROOT/scripts/nixos-test-state.py" install --root "$ROOT" --state "$STATE" --profile "$PROFILE"
set_profile_env "$plugin"
start_shell

export WM_SHORTCUT_BACKUP="$STATE/shortcut-backup.json"
kbuildsycoca6 --noincremental >/dev/null
plasma-apply-lookandfeel -a "org.kde.windowsmodern.$variant" --resetLayout
kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle "$( [ "$variant" = dark ] && echo kvantum-dark || echo kvantum )"
kwriteconfig6 --file Kvantum/kvantum.kvconfig --group General --key theme Windows-modern
kwriteconfig6 --file kdeglobals --group Icons --key Theme windows-modern
kwriteconfig6 --file kdeglobals --group Sounds --key Theme windows-modern
kwriteconfig6 --file kscreenlockerrc --group Greeter --key Theme --delete
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key BorderSize Tiny
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key BorderSizeAuto false
kwriteconfig6 --file kwinrc --group TabBox --key LayoutName org.kde.windowsmodern.alttab
kwriteconfig6 --file kwinrc --group TabBox --key MultiScreenMode 1
for dir in "$ROOT"/plasma/kwinscripts/*/; do
    kwriteconfig6 --file kwinrc --group Plugins --key "$(basename "$dir")Enabled" true
done
kwriteconfig6 --file kwinrc --group Plugins --key minimizeallEnabled true
kwriteconfig6 --file spectaclerc --group General --key useReleaseToCapture true
kwriteconfig6 --file spectaclerc --group General --key autoSaveImage true
kwriteconfig6 --file spectaclerc --group General --key clipboardGroup PostScreenshotCopyImage
if [ ! -e "$DATA/kxmlgui5/dolphin/dolphinui.rc" ]; then
    mkdir -p "$DATA/kxmlgui5/dolphin"
    cp "$ROOT/config/kxmlgui5/dolphin/dolphinui.rc" "$DATA/kxmlgui5/dolphin/"
fi
# Keep the system font and user's existing input method.
"$PYTHON" "$ROOT/scripts/theme/window-frames.py" --apply-local --aurorae-dir "$DATA/aurorae/themes" \
    --kvantum-dir "$CONFIG/Kvantum/Windows-modern" --wallpaper-package "$DATA/wallpapers/Windows-modern"
busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null
sleep 2
"$PYTHON" "$ROOT/scripts/windows-shortcuts.py" apply --group shortcuts
"$PYTHON" "$ROOT/scripts/windows-shortcuts.py" apply --group apps
stop_shell
"$PYTHON" "$ROOT/scripts/windows-shortcuts.py" tray-apply
start_shell
bash "$ROOT/scripts/set-wallpaper.sh"

# Do not report success with stock fallback applets or a stale C++ plugin.
layout="$CONFIG/plasma-org.kde.plasma.desktop-appletsrc"
for id in org.kde.windowsmodern.startmenu org.kde.windowsmodern.systemtray \
          org.kde.windowsmodern.icontasks org.kde.windowsmodern.digitalclock org.kde.windowsmodern.showdesktop; do
    grep -qx "plugin=$id" "$layout" || { echo "任务栏未加载 $id" >&2; false; }
done
pid="$(systemctl --user show "$SERVICE" -p MainPID --value)"
grep -Fq 'org.kde.windowsmodern.systemtray.so' "/proc/$pid/maps"
grep -Fq 'org.kde.windowsmodern.icontasks.so' "/proc/$pid/maps"
trap - ERR EXIT INT TERM
echo "完整测试安装已完成。原版壁纸、锁屏、开始菜单、任务栏及快捷设置已安装。"
echo "运行同一脚本并选择 2，即可恢复原桌面并清理本次安装。"
