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
    printf 'Windows Modern · NixOS 测试\n1. 初次安装（备份、完整构建、安装）\n2. 增量升级（仅更新变化的组件）\n3. 卸载（恢复原桌面、清理测试文件）\n'
    read -r -p '请选择 [1/2/3]：' action
fi
case "$action" in
    1|install|all|nixos) action=install ;;
    2|upgrade|update) action=upgrade ;;
    3|uninstall|remove) action=uninstall ;;
    *) echo "请选择 1、2 或 3。" >&2; exit 2 ;;
esac
systemctl --user cat "$SERVICE" >/dev/null || { echo "未找到 Plasma 用户服务。" >&2; exit 1; }

# Restore only the variables owned by this test. Migrate older backups once.
capture_env() {
    local destination="$1" current
    current="$(systemctl --user show-environment)" || return 1
    printf '%s\n' "$current" | grep -E '^(QT_PLUGIN_PATH|XDG_DATA_DIRS|QML_DISABLE_DISK_CACHE)=' > "$destination" || [ "$?" -eq 1 ]
}
remember_env() {
    if [ ! -f "$STATE/original-env" ]; then
        capture_env "$STATE/original-env" || return 1
    elif [ ! -f "$STATE/cache-env-saved" ]; then
        local current
        current="$(systemctl --user show-environment)" || return 1
        if ! grep -q '^QML_DISABLE_DISK_CACHE=' "$STATE/original-env"; then
            printf '%s\n' "$current" | grep '^QML_DISABLE_DISK_CACHE=' >> "$STATE/original-env" || [ "$?" -eq 1 ]
        fi
    fi
    touch "$STATE/cache-env-saved"
}
restore_env() {
    local source="${1:-$STATE/original-env}"
    [ -f "$source" ] || return 0
    local key line result=0
    for key in QT_PLUGIN_PATH XDG_DATA_DIRS QML_DISABLE_DISK_CACHE; do
        line="$(grep -m1 "^$key=" "$source" || true)"
        if [ -n "$line" ]; then
            systemctl --user set-environment "$line" || result=1
        else
            systemctl --user unset-environment "$key" || result=1
        fi
    done
    return "$result"
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
    printf 'QT_PLUGIN_PATH=%s\nXDG_DATA_DIRS=%s\nQML_DISABLE_DISK_CACHE=1\n' "$qt" "$data" > "$CONFIG/environment.d/90-windows-modern-test.conf"
    printf '[Service]\nEnvironment="QT_PLUGIN_PATH=%s"\nEnvironment="XDG_DATA_DIRS=%s"\nEnvironment="QML_DISABLE_DISK_CACHE=1"\n' \
        "$qt" "$data" > "$CONFIG/systemd/user/$SERVICE.d/90-windows-modern-test.conf"
    systemctl --user daemon-reload
    systemctl --user set-environment "QT_PLUGIN_PATH=$qt" "XDG_DATA_DIRS=$data" "QML_DISABLE_DISK_CACHE=1"
}
wait_shell() {
    for _ in {1..30}; do
        if busctl --user status org.kde.plasmashell >/dev/null 2>&1; then return 0; fi
        sleep 1
    done
    echo "Plasma Shell 启动失败。" >&2
    return 1
}
start_shell() {
    systemctl --user start "$SERVICE" || return 1
    wait_shell
}
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
cleanup_state() {
    # Only remove the exact test-owned directory. Never follow Nix store
    # symlinks, and never chmod or delete the archived original snapshot.
    [ -d "$STATE" ] && [ ! -L "$STATE" ] && [ -f "$STATE/owned-state" ] || return 1
    local retired
    retired="$(mktemp -d "$(dirname "$STATE")/.windows-modern-nixos-cleanup.XXXXXX")" || return 1
    rmdir -- "$retired" || return 1
    mv -T -- "$STATE" "$retired" || return 1
    if ! find -P "$retired" -type d -exec chmod u+rwx -- {} + ||
       ! rm -rf -- "$retired" || [ -e "$retired" ]; then
        printf '清理未完成，剩余测试文件位于：%s\n' "$retired" >&2
        return 1
    fi
}

# Older versions could successfully restore the desktop, copy its snapshot
# to the backup directory, then partially fail to delete the read-only
# logout tree. If the ownership marker has already been removed, do not
# guess that an unknown directory is disposable: preserve the recognized
# residue beside the backups and free the active test path.
recover_legacy_residue() {
    [ ! -L "$STATE" ] || { echo "测试目录是符号链接，拒绝操作。" >&2; return 1; }
    [ -e "$STATE" ] || return 0
    [ -f "$STATE/owned-state" ] && return 0
    [ -d "$STATE" ] && [ ! -f "$STATE/original/manifest.json" ] || return 1
    if [ ! -d "$STATE/staged-shell" ] && [ ! -d "$STATE/original/files" ]; then
        echo "无法确认旧测试目录的来源，已保留。" >&2
        return 1
    fi
    local backups
    backups="$(dirname "$STATE")/windows-modern-nixos-backups"
    local archived saved
    [ -d "$backups" ] || return 1
    archived="$(find -P "$backups" -mindepth 3 -maxdepth 3 -type f -path '*/original/manifest.json' -print -quit)" || return 1
    [ -n "$archived" ] || { echo "未找到已保存的原始备份，保留旧目录。" >&2; return 1; }
    saved="$(mktemp -d "$backups/legacy-cleanup.XXXXXX")" || return 1
    mv -T -- "$STATE" "$saved/residue" || return 1
    printf '旧版清理残留已隔离：%s\n' "$saved/residue"
}

finish_cleanup() {
    # Save the original snapshot before removing test files or GC roots.
    # Explicitly check every command: rollback runs with errexit disabled.
    local backups
    backups="$(dirname "$STATE")/windows-modern-nixos-backups"
    mkdir -p "$backups" || return 1
    local saved
    saved="$(mktemp -d "$backups/$(date +%Y%m%d-%H%M%S).XXXXXX")" || return 1
    cp -a "$STATE/original" "$saved/" || return 1
    [ -f "$saved/original/manifest.json" ] || return 1
    if [ -d "$STATE/before-uninstall" ]; then
        cp -a "$STATE/before-uninstall" "$saved/" || return 1
    fi
    printf '原始备份保留于：%s\n' "$saved"
    cleanup_state || return 1
}

recover_legacy_residue || {
    echo "无法安全处理旧测试目录，未修改桌面。" >&2
    exit 1
}

# Each build has its own stable GC root. Keep the active runtime until a
# verified upgrade commits. Never remove shared Nix store objects.
remove_build_dir() {
    local d="$1"
    [ -d "$d" ] && [ ! -L "$d" ] && [ -f "$d/owned-build" ] || return 1
    find -P "$d" -type d -exec chmod u+rwx -- {} + || return 1
    rm -rf -- "$d" || return 1
    [ ! -e "$d" ]
}
restore_previous_version() {
    local d="$1" old oldpython result=0
    [ -f "$d/previous-runtime" ] && [ -f "$d/previous-env" ] || return 1
    old="$(cat "$d/previous-runtime")" || return 1
    case "$old" in /nix/store/*) ;; *) return 1 ;; esac
    oldpython="$old/bin/python3"
    [ -x "$oldpython" ] || return 1
    stop_shell || return 1
    if [ -f "$d/previous/manifest.json" ]; then
        "$oldpython" "$ROOT/scripts/nixos-test-state.py" restore-upgrade --root "$ROOT" --state "$STATE" --profile "$old" --upgrade-backup "$d/previous" || { start_shell || true; return 1; }
    fi
    # Even if one restoration step fails, attempt to bring the shell back.
    # Retain the recovery marker and both build roots until every step passes.
    ln -sfn "$old" "$STATE/runtime" || result=1
    systemctl --user daemon-reload || result=1
    restore_env "$d/previous-env" || result=1
    kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
    busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null 2>&1 || true
    start_shell || result=1
    [ "$result" -eq 0 ] || return 1
    rm -f -- "$STATE/pending-build" || return 1
    echo "已恢复升级前的运行时和桌面配置：$old"
}
if [ -f "$STATE/pending-build" ]; then
    pending="$(cat "$STATE/pending-build")"
    if [[ ! "$pending" =~ ^run\.[a-zA-Z0-9]+$ ]] ||
       ! restore_previous_version "$STATE/builds/$pending"; then
        echo "上次升级中断，恢复未完成；保留全部备份。" >&2
        exit 1
    fi
fi

if [ "$action" = uninstall ]; then
    if [ ! -f "$STATE/original/manifest.json" ]; then
        if [ -f "$STATE/owned-state" ]; then
            cleanup_state || exit 1
            echo "已清理未完成安装的构建链接和临时资源。"
        else
            echo "没有本脚本的安装记录，不删除其他安装或系统文件。"
        fi
        exit 0
    fi
    PROFILE="$(readlink -f "$STATE/runtime")"
    PYTHON="$PROFILE/bin/python3"
    GI_TYPELIB_PATH="$(cat "$PROFILE/wm-gi-typelib-path")${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
    export GI_TYPELIB_PATH
    [ -x "$PYTHON" ] || { echo "测试运行时缺失，保留备份以免丢失原配置。" >&2; exit 1; }
    remember_env
    stop_shell
    if ! "$PYTHON" "$ROOT/scripts/nixos-test-state.py" snapshot-current --root "$ROOT" --state "$STATE" --profile "$PROFILE"; then
        start_shell || true
        echo "卸载前备份失败，未删除测试文件。" >&2
        exit 1
    fi
    restore_original || { echo "恢复未完成，已保留全部备份；请重新运行选项 3。" >&2; exit 1; }
    finish_cleanup
    echo "已卸载测试安装，原始桌面配置已恢复。"
    exit 0
fi

upgrading=0
if [ "$action" = upgrade ]; then
    [ -f "$STATE/original/manifest.json" ] || {
        echo "没有有效的测试安装记录。请重新运行并选择 1 初次安装。" >&2; exit 1;
    }
    upgrading=1
    old_profile="$(readlink -f "$STATE/runtime")"
    [ -x "$old_profile/bin/python3" ] || { echo "旧测试运行时缺失，保留备份，停止升级。" >&2; exit 1; }
    echo "增量升级：保留现有任务栏及原始卸载备份。"
    echo "当前运行时：$old_profile"
elif [ -f "$STATE/original/manifest.json" ]; then
    echo "已安装测试版，请选择 2 增量升级，或 3 卸载。" >&2
    exit 1
fi

# Validate the extracted source before creating a build or touching the desktop.
# No legacy nix-hash invocation on a directory or locale-sensitive path.
for required in nix/test-runtime.nix scripts/nixos-test-state.py scripts/verify-nixos-runtime.py \
    plasma/applets/org.kde.windowsmodern.systemtray/CMakeLists.txt \
    plasma/applets/org.kde.windowsmodern.systemtray/contents/ui/main.qml \
    plasma/applets/org.kde.windowsmodern.icontasks/CMakeLists.txt \
    plasma/applets/org.kde.windowsmodern.icontasks/contents/ui/main.qml \
    plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/main.qml \
    plasma/applets/org.kde.windowsmodern.digitalclock/contents/ui/main.qml; do
    [ -s "$ROOT/$required" ] || {
        printf '测试包缺少源码：%s\n未修改桌面。请完整解压 ZIP。\n' "$ROOT/$required" >&2
        exit 1
    }
done

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
mkdir -p "$STATE/builds"
touch "$STATE/owned-state"
BUILD_DIR="$(mktemp -d "$STATE/builds/run.XXXXXXXXXXXX")"
touch "$BUILD_DIR/owned-build"
BUILD_TOKEN="$(basename "$BUILD_DIR")"
source_revision=unknown
if [ -f "$ROOT/INTEGRATION-BUILD" ]; then
    source_revision="$(head -n 1 "$ROOT/INTEGRATION-BUILD")"
elif command -v git >/dev/null && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    source_revision="$(git -C "$ROOT" rev-parse HEAD)"
fi
printf '源码版本：%s\n构建编号：%s\n' "$source_revision" "$BUILD_TOKEN"
# Before switching, a failed build or resource import cannot affect the
# active desktop; remove only this attempt's own GC root and staging.
trap 'rc=$?; if [ "$rc" -ne 0 ]; then remove_build_dir "$BUILD_DIR" || true; fi' EXIT
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
echo "检查 Plasma $version 构建输入，只构建源码或依赖变化的插件……"
nix-build "$ROOT/nix/test-runtime.nix" --argstr nixpkgsPath "$nixpkgs" --argstr plasmaVersion "$version" \
    --argstr buildToken "$BUILD_TOKEN" --out-link "$BUILD_DIR/runtime"
PROFILE="$(readlink -f "$BUILD_DIR/runtime")"
[ "$(cat "$PROFILE/wm-build-token")" = "$BUILD_TOKEN" ] || { echo "构建编号错误，拒绝旧运行时。" >&2; exit 1; }
printf '新运行时：%s\n' "$PROFILE"
if [ "$upgrading" -eq 1 ] && [ "$PROFILE" = "$old_profile" ]; then
    echo "新旧运行时路径相同，拒绝继续安装。" >&2; exit 1
fi
PYTHON="$PROFILE/bin/python3"
export PATH="$PROFILE/bin:$PATH"
GI_TYPELIB_PATH="$(cat "$PROFILE/wm-gi-typelib-path")${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
export GI_TYPELIB_PATH
"$PYTHON" -c 'from gi.repository import Gio, GLib; import PIL, fontTools'
"$PYTHON" "$ROOT/scripts/check-startmenu-keys.py"
prefix="$(cat "$PROFILE/wm-qt-plugin-prefix")"
plugin="$PROFILE/$prefix"
tray="$plugin/plasma/applets/org.kde.windowsmodern.systemtray.so"
tasks="$plugin/plasma/applets/org.kde.windowsmodern.icontasks.so"
if [[ ! -s "$tray" || ! -s "$tasks" ]]; then
    echo "两个 C++ 插件未完整构建。" >&2
    exit 1
fi
tray_token="$(cat "$PROFILE/wm-token-systemtray")"
tasks_token="$(cat "$PROFILE/wm-token-icontasks")"
verify_args=(--tray-token "$tray_token" --tasks-token "$tasks_token" --tray "$tray" --tasks "$tasks")
"$PYTHON" "$ROOT/scripts/verify-nixos-runtime.py" "${verify_args[@]}"
printf '系统托盘源码及 ABI 标识：%s\n任务栏源码及 ABI 标识：%s\n' "$tray_token" "$tasks_token"
printf '系统托盘构建输入：%s\n任务栏构建输入：%s\n' "$(cat "$PROFILE/wm-source-systemtray")" "$(cat "$PROFILE/wm-source-icontasks")"

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
# Reuse the imported assets only if the pinned input manifest, mapping and
# every generated file still match. No repeated import on an ordinary upgrade.
if "$PYTHON" "$ROOT/scripts/check-nixos-assets.py" "$STATE/native" "$input" "$ROOT/scripts/native-assets-map.json"; then
    echo "原版图标、壁纸、音效未变化，跳过导入。"
else
    WM_NATIVE_RESOURCE_SOURCE="$input" WM_NATIVE_ASSETS_DIR="$STATE/native" bash "$ROOT/scripts/prepare-native-assets.sh"
fi
# A successful build/import is not a configuration change. Back up the
# running desktop after stopping the shell so its final settings are flushed.
remember_env
upgrade_args=()
if [ "$upgrading" -eq 1 ]; then
    printf '%s\n' "$old_profile" > "$BUILD_DIR/previous-runtime"
    capture_env "$BUILD_DIR/previous-env"
    upgrade_args=(--upgrade-backup "$BUILD_DIR/previous")
fi
rollback() {
    local rc="${1:-$?}"
    trap - ERR EXIT INT TERM
    set +e
    echo "安装未完成，正在恢复安装前的桌面……" >&2
    if [ "$upgrading" -eq 1 ]; then
        if restore_previous_version "$BUILD_DIR"; then
            remove_build_dir "$BUILD_DIR" || echo "失败构建残留：$BUILD_DIR" >&2
        else
            echo "升级回滚失败，保留原始和升级前备份：$STATE" >&2
        fi
    elif [ -f "$STATE/original/manifest.json" ]; then
        restore_original && finish_cleanup || echo "自动恢复失败，备份已保留：$STATE" >&2
    else
        start_shell || true
        remove_build_dir "$BUILD_DIR" || true
    fi
    exit "$rc"
}
# Run destructive rollback once in the main shell, including signals.
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'rc=$?; if [ "$rc" -ne 0 ]; then rollback "$rc"; fi' EXIT
# Publish recovery information only after replacing the pre-build cleanup
# trap. A failure here must never delete the build named by pending-build.
if [ "$upgrading" -eq 1 ]; then
    printf '%s\n' "$(basename "$BUILD_DIR")" > "$BUILD_DIR/pending-marker"
    mv -T -- "$BUILD_DIR/pending-marker" "$STATE/pending-build"
else
    # Keep the recovery interpreter reachable even if the first installation
    # fails between creating its original manifest and switching the shell.
    ln -sfn "$PROFILE" "$STATE/runtime"
fi
echo "正在自动备份原始桌面配置和将被替换的资源……"
stop_shell
"$PYTHON" "$ROOT/scripts/nixos-test-state.py" install --root "$ROOT" --state "$STATE" --profile "$PROFILE" "${upgrade_args[@]}"
"$PYTHON" "$ROOT/scripts/nixos-test-state.py" verify-sources --root "$ROOT" --state "$STATE" --profile "$PROFILE"
ln -sfn "$PROFILE" "$STATE/runtime"
set_profile_env "$plugin"
start_shell

export WM_SHORTCUT_BACKUP="$STATE/shortcut-backup.json"
kbuildsycoca6 --noincremental >/dev/null
# The shell popup supplies its bottom/top/side edge slide hint. Preserve
# explicit user animation settings, including reduced-motion preferences.
if [ -z "$(kreadconfig6 --file kwinrc --group Plugins --key slidingpopupsEnabled)" ]; then
    kwriteconfig6 --file kwinrc --group Plugins --key slidingpopupsEnabled true
fi
if [ "$upgrading" -eq 0 ]; then
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
else
    # Do not apply global theme defaults or reset wallpaper, shortcuts,
    # pinned apps, layout or the user's light/dark preference on upgrade.
    busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null
fi

"$PYTHON" "$ROOT/scripts/app-appearance.py" apply

# Do not report success with stock fallback applets or a stale C++ plugin.
layout="$CONFIG/plasma-org.kde.plasma.desktop-appletsrc"
for id in org.kde.windowsmodern.startmenu org.kde.windowsmodern.systemtray \
          org.kde.windowsmodern.icontasks org.kde.windowsmodern.digitalclock org.kde.windowsmodern.showdesktop; do
    grep -qx "plugin=$id" "$layout" || { echo "任务栏未加载 $id" >&2; false; }
done
# A filename match is NOT sufficient. Verify both mapped objects have
# exactly the new immutable store paths, inodes, and compiled build token.
verified=0
for _ in {1..20}; do
    pid="$(systemctl --user show "$SERVICE" -p MainPID --value)"
    if "$PYTHON" "$ROOT/scripts/verify-nixos-runtime.py" "${verify_args[@]}" --pid "$pid" --quiet 2>/dev/null; then
        verified=1
        break
    fi
    sleep 1
done
[ "$verified" -eq 1 ] || {
    "$PYTHON" "$ROOT/scripts/verify-nixos-runtime.py" "${verify_args[@]}" --pid "$pid"
    echo "Plasma 未加载本次构建，拒绝报告安装成功。" >&2
    false
}
"$PYTHON" "$ROOT/scripts/verify-nixos-runtime.py" "${verify_args[@]}" --pid "$pid"
"$PYTHON" "$ROOT/scripts/nixos-test-state.py" verify-sources --root "$ROOT" --state "$STATE" --profile "$PROFILE"
if [ "$upgrading" -eq 1 ]; then
    backups="$(dirname "$STATE")/windows-modern-nixos-backups"
    mkdir -p "$backups"
    saved="$(mktemp -d "$backups/upgrade-$(date +%Y%m%d-%H%M%S).XXXXXX")"
    cp -a "$BUILD_DIR/previous" "$BUILD_DIR/previous-env" "$BUILD_DIR/previous-runtime" "$saved/"
    echo "升级前备份：$saved"
    rm -f -- "$STATE/pending-build"
fi
printf '%s\n' "$BUILD_TOKEN" > "$STATE/active-build"
trap - ERR EXIT INT TERM
# Only after verification and backup: retire the previous build roots.
for old_build in "$STATE"/builds/run.*; do
    [ "$old_build" = "$BUILD_DIR" ] && continue
    [ -d "$old_build" ] || continue
    remove_build_dir "$old_build" || echo "保留无法安全清理的旧构建：$old_build" >&2
done
if [ -L "$STATE/runtime-next" ]; then rm -f -- "$STATE/runtime-next"; fi
# The previous snapshot is safely archived; leave only the active build root.
if [ -d "$BUILD_DIR/previous" ] && [ ! -L "$BUILD_DIR/previous" ]; then
    if find -P "$BUILD_DIR/previous" -type d -exec chmod u+rwx -- {} + &&
       rm -rf -- "$BUILD_DIR/previous"; then
        rm -f -- "$BUILD_DIR/previous-env" "$BUILD_DIR/previous-runtime"
    else
        echo "已保留重复升级备份：$BUILD_DIR/previous" >&2
    fi
fi
printf '安装完成，当前运行时：%s\n构建编号：%s\n' "$PROFILE" "$BUILD_TOKEN"
echo "原版壁纸、锁屏、开始菜单、任务栏及快捷设置已更新。"
echo "运行同一脚本：1 初次安装，2 增量升级，3 卸载。"
