#!/bin/bash
# This is a library: its colors and *_DIR paths are used by the scripts that
# source it, so "assigned but unused" does not apply.
# shellcheck disable=SC2034
# ───────────────────────────────────────────────────────────────────
#  Shared library — sourced by all install-*.sh scripts
#
#  Provides install paths, logging, and reusable apply/reload helpers.
#  WM_BATCH=1 in the environment tells component scripts to install
#  files only — skip prompts, apply, and plasmashell restarts — because
#  the parent 'all' driver applies everything once at the end.
# ───────────────────────────────────────────────────────────────────
set -euo pipefail

# Only import the owner's local resources in their own session, never from
# an arbitrary user's directory during a system-wide root install.
NATIVE_ASSETS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/windows-modern/native-assets"

# Always resolve to this file's own location so SRC_DIR is correct no
# matter which script sources us (install.sh, uninstall.sh, or a
# component script invoked directly).
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BOLD="\033[1m"; GREEN="\033[32m"; BLUE="\033[34m"; YELLOW="\033[33m"; RED="\033[31m"; CYAN="\033[36m"; RESET="\033[0m"
info()  { echo -e "${GREEN}==>${RESET} ${BOLD}$*${RESET}"; }
warn()  { echo -e "${YELLOW}==>${RESET} $*"; }
err()   { echo -e "${RED}==>${RESET} $*"; }
step()  { echo -e "${CYAN}  >>${RESET} $*"; }

# ── Detect install target ──────────────────────────────────────────

if [ "$UID" -eq 0 ]; then
    AURORAE_DIR="/usr/share/aurorae/themes"
    SCHEMES_DIR="/usr/share/color-schemes"
    PLASMA_DIR="/usr/share/plasma/desktoptheme"
    LAYOUT_DIR="/usr/share/plasma/layout-templates"
    LOOKFEEL_DIR="/usr/share/plasma/look-and-feel"
    KVANTUM_DIR="/usr/share/Kvantum"
    WALLPAPER_DIR="/usr/share/wallpapers"
    ICONS_DIR="/usr/share/icons"
    APPLETS_DIR="/usr/share/plasma/plasmoids"
    TABBOX_DIR="/usr/share/kwin/tabbox"
else
    AURORAE_DIR="$HOME/.local/share/aurorae/themes"
    SCHEMES_DIR="$HOME/.local/share/color-schemes"
    PLASMA_DIR="$HOME/.local/share/plasma/desktoptheme"
    LAYOUT_DIR="$HOME/.local/share/plasma/layout-templates"
    LOOKFEEL_DIR="$HOME/.local/share/plasma/look-and-feel"
    KVANTUM_DIR="$HOME/.config/Kvantum"
    WALLPAPER_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/wallpapers"
    ICONS_DIR="$HOME/.local/share/icons"
    APPLETS_DIR="$HOME/.local/share/plasma/plasmoids"
    TABBOX_DIR="$HOME/.local/share/kwin/tabbox"
fi

ensure_dir() {
    mkdir -p "$1" 2>/dev/null || { err "Cannot create $1 — try running as root (sudo)"; exit 1; }
}

# ── Reusable helpers ───────────────────────────────────────────────

# True when running on a terminal (safe to prompt).
is_interactive() { [ -t 0 ]; }

# True when the parent 'all' driver is in charge — component scripts
# should then install files only and stay silent.
is_batch() { [ "${WM_BATCH:-0}" = "1" ]; }

# Wait up to ~5 s for the plasmashell process to disappear.
_wait_plasmashell_exit() {
    local i
    for i in {1..25}; do
        pgrep -x plasmashell >/dev/null 2>&1 || return 0
        sleep 0.2
    done
    return 1
}

# Return the name of the available KDE launcher (kstart6 or kstart).
_kstart_cmd() {
    if command -v kstart6 &>/dev/null; then
        echo "kstart6"
    elif command -v kstart &>/dev/null; then
        echo "kstart"
    else
        echo ""
    fi
}

# Restart Plasma Shell for the running user session (no-op if not running).
restart_plasmashell() {
    # Only when running inside a graphical session (never from a TTY or root).
    [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] || return 0
    if command -v systemctl &>/dev/null && systemctl --user cat plasma-plasmashell.service &>/dev/null; then
        # restart also *starts* the shell when it is stopped — the C++ applet
        # installers stop it in batch mode and leave the start to us.
        info "Restarting Plasma Shell..."
        systemctl --user restart plasma-plasmashell.service
        return 0
    fi
    if ! pgrep -x plasmashell >/dev/null 2>&1; then
        info "Starting Plasma Shell..."
        local kstart
        kstart="$(_kstart_cmd)"
        if [ -n "$kstart" ]; then $kstart plasmashell >/dev/null 2>&1; else (setsid plasmashell >/dev/null 2>&1 &); fi
        return 0
    fi
    info "Restarting Plasma Shell..."

    # Graceful quit first, fall back to killall.
    if command -v kquitapp6 &>/dev/null; then
        kquitapp6 plasmashell 2>/dev/null || true
    else
        killall plasmashell 2>/dev/null || true
    fi

    if ! _wait_plasmashell_exit; then
        warn "Plasma Shell did not stop gracefully; forcing..."
        killall -9 plasmashell 2>/dev/null || true
        sleep 0.5
    fi

    # Let the session bus release the old plasma-shell name before restarting.
    sleep 0.5

    local kstart
    kstart="$(_kstart_cmd)"
    if [ -n "$kstart" ]; then
        $kstart plasmashell >/dev/null 2>&1
    else
        warn "kstart not found; launching plasmashell directly..."
        plasmashell >/dev/null 2>&1 &
    fi

    # Verify the shell actually came back; retry once if it didn't.
    sleep 1
    if ! pgrep -x plasmashell >/dev/null 2>&1; then
        warn "Plasma Shell did not restart; trying once more..."
        if [ -n "$kstart" ]; then
            $kstart plasmashell >/dev/null 2>&1
        else
            plasmashell >/dev/null 2>&1 &
        fi
        sleep 2
    fi

    if ! pgrep -x plasmashell >/dev/null 2>&1; then
        err "Plasma Shell could not be restarted."
        err "Run manually:  killall plasmashell && kstart plasmashell"
        return 1
    fi

    # Give the layout script time to finish rebuilding panels before we return.
    sleep 1
}

# ── Cursor theme ──────────────────────────────────────────────────
# Native XCursor artwork; modern white/black edge, multi-size through
# 96px. Preserve the user's chosen size and an existing installation.
# shellcheck source=scripts/cursor-assets.sh
source "$SRC_DIR/scripts/cursor-assets.sh"

cursor_theme_installed() {
    local d
    for d in "$ICONS_DIR" "$HOME/.local/share/icons" "$HOME/.icons" /usr/share/icons /usr/local/share/icons; do
        cursor_assets_valid "$d/$CURSOR_THEME" && return 0
    done
    return 1
}

install_cursor_theme() {
    cursor_theme_installed && return 0
    [ "$UID" -ne 0 ] || return 0
    local dst="$ICONS_DIR/$CURSOR_THEME"
    # Do not overwrite an unrelated or incomplete user-owned theme.
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        warn "Existing $CURSOR_THEME directory is incomplete; keeping it untouched."
        return 0
    fi
    step "Cursor theme: $CURSOR_THEME (GPL-3.0)"
    local tmp bundled="$SRC_DIR/bundled-cursors/$CURSOR_THEME"
    tmp="$(mktemp -d)"
    if { cursor_assets_valid "$bundled" && cp -a "$bundled" "$tmp/$CURSOR_THEME"; } ||
        fetch_cursor_assets "$tmp/$CURSOR_THEME"; then
        ensure_dir "$ICONS_DIR"
        if mv "$tmp/$CURSOR_THEME" "$dst"; then
            ensure_dir "$HOME/.local/share/windows-modern/backup"
            touch "$HOME/.local/share/windows-modern/backup/cursor-bibata.ours"
        fi
    else
        warn "Could not install $CURSOR_THEME; Plasma retains its native fallback."
    fi
    rm -rf "$tmp"
}

# ── Prebuilt C++ plugins ───────────────────────────────────────────
# Releases carry the System Tray and Icon Tasks plugins built per distro,
# Plasma and Qt version (scripts/package-plugins.sh, CI). A plugin only
# works with the exact versions it was built against, and only matches the
# source when this checkout *is* that release, so both are checked; in any
# other case the applets are built from source.
#
# Testing: WM_PREBUILT_URL=<URL of a folder with the assets, file:// works>
# uses those assets whatever the checkout is.
PREBUILT_REPO_URL="https://github.com/Jeysef/KDE-Windows-Modern/releases/download"

# e.g. fedora45-plasma6.8.2-qt6.11.2-x86_64; empty when unknown.
plugin_platform_key() {
    command -v rpm &>/dev/null || return 0
    local id ver plasma qt
    id="$(. /etc/os-release && echo "${ID:-}")"; ver="$(. /etc/os-release && echo "${VERSION_ID:-}")"
    plasma="$(rpm -q --qf '%{VERSION}' plasma-workspace-libs 2>/dev/null)" || return 0
    qt="$(rpm -q --qf '%{VERSION}' qt6-qtbase 2>/dev/null)" || return 0
    [ -n "$id" ] && [ -n "$ver" ] && echo "${id}${ver}-plasma${plasma}-qt${qt}-$(uname -m)"
}

# The release tag this checkout is exactly (vX.Y.Z), or empty.
release_tag() {
    # An untagged integration bundle must never download an older stable plugin.
    [ ! -f "$SRC_DIR/INTEGRATION-BUILD" ] || return 0
    if [ -d "$SRC_DIR/.git" ]; then
        git -C "$SRC_DIR" describe --exact-match --tags HEAD 2>/dev/null || true
    elif command -v python3 &>/dev/null; then
        # A release tarball (no git): its version is the applets' Version.
        python3 -c 'import json,sys; print("v" + json.load(open(sys.argv[1]))["KPlugin"]["Version"])' \
            "$SRC_DIR/plasma/applets/org.kde.windowsmodern.systemtray/metadata.json" 2>/dev/null || true
    fi
}

# Matching local integration plugins take precedence over release downloads.
prebuilt_base() {
    local tag
    if [ -n "${WM_PREBUILT_URL:-}" ]; then
        printf '%s\n' "$WM_PREBUILT_URL"
    elif [ -f "$SRC_DIR/INTEGRATION-BUILD" ] && [ -f "$SRC_DIR/prebuilt/SHA256SUMS" ]; then
        printf '%s\n' "$SRC_DIR/prebuilt"
    else
        tag="$(release_tag)"; [ -n "$tag" ] || return 1
        printf '%s\n' "$PREBUILT_REPO_URL/$tag"
    fi
}

# True when this checkout's exact build has plugins for this system.
prebuilt_available() {
    local key base
    key="$(plugin_platform_key)"; [ -n "$key" ] || return 1
    base="$(prebuilt_base)" || return 1
    if [ -d "${base#file://}" ]; then
        [ -f "${base#file://}/windows-modern-plugins-${key}.tar.gz" ]
    else
        curl -sfIL -o /dev/null "$base/windows-modern-plugins-${key}.tar.gz" 2>/dev/null
    fi
}

# fetch_prebuilt_plugin <applet-id> <dest.so>: download this platform's
# build, check it against the release's SHA256SUMS and extract <applet-id>.so.
# Returns non-zero (quietly) when there is no usable prebuilt plugin.
fetch_prebuilt_plugin() {
    local applet="$1" dest="$2" key base file tmp
    key="$(plugin_platform_key)"; [ -n "$key" ] || return 1
    base="$(prebuilt_base)" || return 1
    file="windows-modern-plugins-${key}.tar.gz"
    tmp="$(mktemp -d)"
    if [ -d "${base#file://}" ]; then
        if ! cp "${base#file://}/$file" "${base#file://}/SHA256SUMS" "$tmp/"; then
            rm -rf "$tmp"; return 1
        fi
    elif ! curl -sfL -o "$tmp/$file" "$base/$file" || ! curl -sfL -o "$tmp/SHA256SUMS" "$base/SHA256SUMS"; then
        rm -rf "$tmp"; return 1
    fi
    if ! (cd "$tmp" && grep -F " $file" SHA256SUMS | sha256sum -c --status); then
        warn "Prebuilt $file does not match its checksum — building from source instead."
        rm -rf "$tmp"; return 1
    fi
    if ! tar -xzf "$tmp/$file" -C "$tmp" "$applet.so" 2>/dev/null \
       && ! tar -xzf "$tmp/$file" -C "$tmp" "./$applet.so" 2>/dev/null; then
        rm -rf "$tmp"; return 1
    fi
    mkdir -p "$(dirname "$dest")"
    mv "$tmp/$applet.so" "$dest"
    rm -rf "$tmp"
    step "Using the prebuilt plugin for $key"
}

# Stop Plasma Shell (for config it rewrites on exit). restart_plasmashell
# starts it again.
stop_plasmashell() {
    if command -v systemctl &>/dev/null && systemctl --user cat plasma-plasmashell.service &>/dev/null; then
        systemctl --user stop plasma-plasmashell.service
    elif command -v kquitapp6 &>/dev/null; then
        kquitapp6 plasmashell 2>/dev/null || true
    fi
    _wait_plasmashell_exit || killall plasmashell 2>/dev/null || true
}

# Install distro packages that are missing, with one password prompt.
# Usage: install_packages <package>...   (same names on Fedora/Debian/Arch/openSUSE)
install_packages() {
    local missing=() p
    for p in "$@"; do
        if command -v rpm &>/dev/null && rpm -q "$p" &>/dev/null; then continue; fi
        if command -v dpkg-query &>/dev/null && grep -q "ok installed" <<< "$(dpkg-query -W -f='${Status}' "$p" 2>/dev/null)"; then continue; fi
        if command -v pacman &>/dev/null && pacman -Q "$p" &>/dev/null; then continue; fi
        missing+=("$p")
    done
    [ "${#missing[@]}" -eq 0 ] && { step "Already installed: $*"; return 0; }
    local cmd
    if command -v dnf &>/dev/null; then cmd="dnf install -y --skip-unavailable"
    elif command -v apt-get &>/dev/null; then cmd="apt-get install -y"
    elif command -v pacman &>/dev/null; then cmd="pacman -S --needed --noconfirm"
    elif command -v zypper &>/dev/null; then cmd="zypper --non-interactive install"
    else
        warn "No supported package manager; install yourself: ${missing[*]}"
        return 1
    fi
    step "Installing ${missing[*]} (password prompt)..."
    # shellcheck disable=SC2086  # $cmd is a command line on purpose
    pkexec $cmd "${missing[@]}"
}

# Apply a global theme. Usage: apply_lookandfeel <theme-id> [reset]
# 'reset' adds --resetLayout so the desktop layout is rebuilt from the theme.
apply_lookandfeel() {
    local id="$1"
    local reset_flag=""
    [ "${2:-}" = "reset" ] && reset_flag="--resetLayout"
    if [ "$UID" -eq 0 ]; then
        warn "Running as root — apply the theme manually from a user session."
        return 0
    fi
    if ! command -v plasma-apply-lookandfeel &>/dev/null; then
        warn "plasma-apply-lookandfeel not found — apply manually in System Settings."
        return 0
    fi
    info "Applying $id ${reset_flag:+with layout reset}..."
    plasma-apply-lookandfeel -a "$id" $reset_flag
    # Apply the wallpaper only after the caller has completed layout reset
    # and restarted Plasma. Otherwise the new desktop may overwrite it.
}

# Set the Application Style (widgetStyle) so Kvantum actually renders.
# Variant 'dark' uses kvantum-dark, 'light' uses kvantum.
apply_kvantum_engine() {
    local variant="${1:-dark}"
    if [ "$UID" -eq 0 ]; then return 0; fi
    command -v kwriteconfig6 &>/dev/null || return 0
    local style="kvantum"
    [ "$variant" = "dark" ] && style="kvantum-dark"
    step "Setting Application Style → $style"
    kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle "$style"
}

# Ask the running KWin to reload kwinrc. dbus-send defaults to sending a
# *signal*, which KWin ignores, so --type=method_call is required.
# Transparency effects (install-transparency.sh): this file exists while
# they are off, holding the blur setting to restore.
TRANSPARENCY_OFF_FILE="$HOME/.local/share/windows-modern/transparency-off"

# Long-lived application windows stay opaque in both modes. KWin supplies
# live blur/noise only to the existing translucent popup surfaces.
kvantum_transparency() {
    local value="$1" f
    for f in "$KVANTUM_DIR"/Windows-modern/*.kvconfig; do
        [ -f "$f" ] || continue
        sed -i -E \
            -e 's/^(translucent_windows|transparent_dolphin_view|transparent_pcmanfm_sidepane|transparent_pcmanfm_view)=.*/\1=false/' \
            -e "s/^(blurring|popup_blurring|blur_translucent)=.*/\1=${value}/" "$f"
    done
}

# Reuse the existing frame generator and installed wallpaper package. No
# extra effect, daemon or system-wide palette changes. Missing Pillow or
# wallpaper yields the stock solid backgrounds.
apply_window_materials() {
    [ "$UID" -ne 0 ] || return 0
    local args=(--apply-local --aurorae-dir "$AURORAE_DIR"
                --kvantum-dir "$KVANTUM_DIR/Windows-modern")
    if [ "$1" = true ]; then
        if [ "${2:-package}" = current ]; then
            args+=(--wallpaper-config "${XDG_CONFIG_HOME:-$HOME/.config}/plasma-org.kde.plasma.desktop-appletsrc")
        elif [ -d "$WALLPAPER_DIR/Windows-modern" ]; then
            args+=(--wallpaper-package "$WALLPAPER_DIR/Windows-modern")
        fi
    fi
    python3 -I "$SRC_DIR/scripts/theme/window-frames.py" "${args[@]}" \
        || warn "Window material update failed; reinstall themes to restore the stock artwork."
}

# A panel may explicitly select translucent artwork even when blur is
# disabled. Use the already shipped solid native frames in the installed
# normal/translucent selectors, and restore exact source art on enable.
# Preserve panel layout, opacity preferences and inner widget backgrounds.
apply_popup_materials() {
    [ "$UID" -ne 0 ] || return 0
    local mode variant role source target
    for mode in dark light; do
        source="$SRC_DIR/plasma/desktoptheme/Windows-modern-$mode"
        target="$PLASMA_DIR/Windows-modern-$mode"
        [ -d "$target" ] || continue
        for variant in "" translucent/; do
            for role in dialogs/background.svg widgets/panel-background.svg; do
                [ -f "$target/$variant$role" ] || continue
                if [ "$1" = false ]; then
                    cp "$source/solid/$role" "$target/$variant$role"
                else
                    cp "$source/$variant$role" "$target/$variant$role"
                fi
            done
        done
    done
}

kwin_reconfigure() {
    command -v dbus-send &>/dev/null || return 0
    dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure \
        2>/dev/null || warn "Could not reach KWin — changes apply at next login."
}

# Window animations: KDE's defaults already match Windows 11 (scale on
# open/close, squash into the taskbar on minimize, maximize, slide between
# desktops). Except Show Desktop: KDE slides every window to the screen
# corners (windowaperture); Windows just gets them out of the way. Turned
# off only if the user never set it.
post_kwin_effects() {
    command -v kreadconfig6 &>/dev/null || return 0
    if [ -z "$(kreadconfig6 --file kwinrc --group Plugins --key windowapertureEnabled)" ]; then
        kwriteconfig6 --file kwinrc --group Plugins --key windowapertureEnabled false
        kwin_reconfigure
    fi
}

# KWin tiny borders + reconfigure (the "post_install" borders step).
post_kwin_borders() {
    command -v kwriteconfig6 &>/dev/null || return 0
    step "KWin border size → Tiny"
    kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key "BorderSize" "Tiny"
    kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key "BorderSizeAuto" "false"
    kwin_reconfigure
}

# KWin per-monitor Alt+Tab: only list windows on the active monitor.
# [TabBox] MultiScreenMode: 0 = all monitors (default), 1 = current only,
# 2 = exclude current.
post_kwin_per_monitor_alt_tab() {
    command -v kwriteconfig6 &>/dev/null || return 0
    step "KWin Alt+Tab → per-monitor"
    kwriteconfig6 --file kwinrc --group "TabBox" --key "MultiScreenMode" "1"
    kwin_reconfigure
}

# KWin Alt+Tab: use the Windows Modern window switcher.
ALT_TAB_LAYOUT="org.kde.windowsmodern.alttab"
post_kwin_alt_tab_switcher() {
    command -v kwriteconfig6 &>/dev/null || return 0
    [ -d "$TABBOX_DIR/$ALT_TAB_LAYOUT" ] || return 0
    step "KWin Alt+Tab → Windows Modern switcher"
    kwriteconfig6 --file kwinrc --group "TabBox" --key "LayoutName" "$ALT_TAB_LAYOUT"
    kwin_reconfigure
}

# Prompt the user for a theme variant. Prints 'light' or 'dark'.
# Non-interactive sessions default to dark (no prompt).
# Prompt text goes to stderr so callers can safely use command substitution
# to capture only the answer (e.g. variant="$(ask_theme_variant)").
ask_theme_variant() {
    if ! is_interactive; then
        echo "dark"
        return
    fi
    echo "" >&2
    echo -e "${BOLD}┌──────────────────────────────────────────────────────┐${RESET}" >&2
    echo -e "${BOLD}│  Choose the Windows Modern theme variant             │${RESET}" >&2
    echo -e "${BOLD}└──────────────────────────────────────────────────────┘${RESET}" >&2
    echo "" >&2
    echo -e "  ${BOLD}1${RESET}) Light  (org.kde.windowsmodern.light)" >&2
    echo -e "  ${BOLD}2${RESET}) Dark   (org.kde.windowsmodern.dark)" >&2
    echo "" >&2
    echo -e "  Type ${BOLD}1${RESET} for Light, ${BOLD}2${RESET} for Dark, or press ${BOLD}Enter${RESET} for Dark." >&2
    echo "" >&2
    read -r -p "  Choice [2]: " choice
    choice="${choice:-2}"
    case "$choice" in
        1|light|Light) echo "light" ;;
        *) echo "dark" ;;
    esac
}

# Map a variant name to the look-and-feel package id.
lookfeel_id() {
    case "$1" in
        light) echo "org.kde.windowsmodern.light" ;;
        *)     echo "org.kde.windowsmodern.dark" ;;
    esac
}
