#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Switch appearance only. Never apply a global theme or reset a layout here.
set -euo pipefail
theme_id=org.kde.windowsmodern.dark
legacy_light=org.kde.windowsmodern.light
config="${XDG_CONFIG_HOME:-$HOME/.config}"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
missing="__windows_modern_missing_appearance_key__"
fail() { printf '%s\n' "$*" >&2; exit 1; }
[ "$EUID" -ne 0 ] || fail "Switch appearance as the desktop user, not root."
[ "$#" -eq 1 ] || fail "Usage: switch-mode.sh light|dark|--migrate|--sync-accent"
case "$1" in light|dark|--migrate|--sync-accent) ;; *) fail "Unknown appearance mode: $1" ;; esac
for cmd in kreadconfig6 kwriteconfig6; do
    command -v "$cmd" >/dev/null || fail "Missing command: $cmd"
done

read_key() {
    kreadconfig6 --file "$1" --group "$2" --key "$3" --default "$missing"
}
write_key() {
    local file="$1" group="$2" key="$3" value="$4"
    if [ "$value" = "$missing" ]; then
        kwriteconfig6 --notify --file "$file" --group "$group" --key "$key" --delete
    else
        kwriteconfig6 --notify --file "$file" --group "$group" --key "$key" "$value"
    fi
}
find_data() {
    local relative directory
    local -a dirs
    IFS=: read -r -a dirs <<< "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    for directory in "$data" "${dirs[@]}"; do
        [ -n "$directory" ] || continue
        for relative in "$@"; do
            [ -f "$directory/$relative" ] || continue 2
        done
        return 0
    done
    return 1
}
guard_config() {
    local path
    for path in "$@"; do
        if [ -L "$config/$path" ] || [ -L "$(dirname "$config/$path")" ]; then
            fail "Appearance config is externally managed: $path"
        fi
    done
}

active="$(read_key kdeglobals KDE LookAndFeelPackage)"
if [ "$active" = "$missing" ] && [ -f "$config/kdedefaults/package" ]; then
    active="$(cat "$config/kdedefaults/package")"
fi
# A no-op migration must also work during a non-interactive installation.
if [ "$1" = --migrate ] && [ "$active" != "$legacy_light" ]; then
    exit 0
fi
if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ]; then
    command -v flock >/dev/null || fail "Missing command: flock"
    exec 9>"$XDG_RUNTIME_DIR/windows-modern-appearance.lock"
    flock -w 8 9 || fail "An appearance change is already running."
elif [ "$1" != --migrate ]; then
    fail "No desktop runtime directory."
fi
if [ "$1" = --migrate ]; then
    # Move only an old Windows Modern Light identity to the shared package.
    # The actual palette, materials, wallpaper and panel layout stay put.
    [ "$active" = "$legacy_light" ] || exit 0
    find_data "plasma/look-and-feel/$theme_id/metadata.json" || fail "Shared theme is not installed."
    guard_config kdeglobals ksplashrc kdedefaults/package kdedefaults/ksplashrc
    if [ "$(read_key ksplashrc KSplash Theme)" = "$legacy_light" ]; then
        write_key ksplashrc KSplash Theme "$theme_id"
    fi
    if [ -f "$config/kdedefaults/ksplashrc" ] &&
       [ "$(read_key "$config/kdedefaults/ksplashrc" KSplash Theme)" = "$legacy_light" ]; then
        write_key "$config/kdedefaults/ksplashrc" KSplash Theme "$theme_id"
    fi
    if [ -f "$config/kdedefaults/package" ] &&
       [ "$(cat "$config/kdedefaults/package")" = "$legacy_light" ]; then
        tmp="$(mktemp "$config/kdedefaults/.wm-package.XXXXXX")"
        printf '%s' "$theme_id" > "$tmp"
        mv -f -- "$tmp" "$config/kdedefaults/package"
    fi
    write_key kdeglobals KDE LookAndFeelPackage "$theme_id"
    exit 0
fi

# KDE's effective selection palette is authoritative. Never change its
# wallpaper accent setting, other themes or system-managed Kvantum assets.
sync_accent() {
    local current_scheme current_style current_theme current_mode selection python result
    current_scheme="$(read_key kdeglobals General ColorScheme)"
    current_style="$(read_key kdeglobals KDE widgetStyle)"
    current_theme="$(read_key Kvantum/kvantum.kvconfig General theme)"
    [ "$current_theme" = Windows-modern ] || return 0
    case "$current_scheme:$current_style" in
        WindowsModernDark:kvantum-dark) current_mode=dark ;;
        WindowsModernLight:kvantum) current_mode=light ;;
        *) return 0 ;;
    esac
    local kvdir="$config/Kvantum/Windows-modern"
    [ -d "$kvdir" ] || return 0
    [ -f "$kvdir/accent-bindings.json" ] || {
        echo "Missing accent bindings; reinstall Windows Modern theme assets." >&2
        return 1
    }
    selection="$(read_key kdeglobals Colors:Selection BackgroundNormal)"
    [ "$selection" != "$missing" ] || return 0
    python="$(command -v python3 || true)"
    if [ -z "$python" ]; then
        python="${XDG_STATE_HOME:-$HOME/.local/state}/windows-modern-nixos-test/runtime/bin/python3"
    fi
    [ -x "$python" ] || { echo "Python 3 is unavailable for Kvantum accent synchronization." >&2; return 1; }
    result="$("$python" -I "$(dirname -- "${BASH_SOURCE[0]}")/sync-accent.py" "$kvdir" "$current_mode" "$selection")" || return 1
    if [ "$result" = changed ]; then
        # Existing applications may cache Kvantum SVGs until reopened.
        busctl --user emit /KGlobalSettings org.kde.KGlobalSettings notifyChange ii 2 0 || true
    fi
}

if [ "$1" = --sync-accent ]; then
    [ "$active" = "$theme_id" ] || exit 0
    sync_accent
    exit $?
fi

[ "$active" = "$theme_id" ] || fail "Apply the shared Windows Modern global theme first."
mode="$1"
case "$mode" in
    light) scheme=WindowsModernLight; style=kvantum; icons=windows-modern-light; kvconfig=Windows-modern.kvconfig ;;
    dark) scheme=WindowsModernDark; style=kvantum-dark; icons=windows-modern; kvconfig=Windows-modernDark.kvconfig ;;
esac
plasma="Windows-modern-$mode"
decoration="__aurorae__svg__windows-modern-$mode-aurorae"
for cmd in plasma-apply-colorscheme plasma-apply-desktoptheme busctl; do
    command -v "$cmd" >/dev/null || fail "Missing command: $cmd"
done
busctl --user status org.kde.KWin >/dev/null || fail "KWin is not running in this session."
guard_config kdeglobals plasmarc kwinrc kcmicons Kvantum/kvantum.kvconfig
for asset in "color-schemes/$scheme.colors" "plasma/desktoptheme/$plasma/metadata.desktop" \
    "icons/$icons/index.theme" "aurorae/themes/windows-modern-$mode-aurorae/metadata.desktop"; do
    find_data "$asset" || fail "Missing installed appearance component: $asset"
done
kvdir="$config/Kvantum/Windows-modern"
kvsvg="${kvconfig%.kvconfig}.svg"
if [ -f "$kvdir/$kvconfig" ] || [ -f "$kvdir/$kvsvg" ]; then
    [ -f "$kvdir/$kvconfig" ] && [ -f "$kvdir/$kvsvg" ] || fail "Incomplete user Kvantum mode artwork."
else
    find_data "Kvantum/Windows-modern/$kvconfig" "Kvantum/Windows-modern/$kvsvg" || fail "Missing Kvantum mode artwork."
fi

# Record only the settings owned by this switch, never copy or replace the
# whole live kdeglobals/kwinrc. Reapply the previous scheme on failure.
old_scheme="$(read_key kdeglobals General ColorScheme)"
old_plasma="$(read_key plasmarc Theme name)"
files=(kdeglobals kdeglobals kcmicons Kvantum/kvantum.kvconfig kwinrc kwinrc)
groups=(KDE Icons Icons General org.kde.kdecoration2 org.kde.kdecoration2)
keys=(widgetStyle Theme Theme theme library theme)
values=("$style" "$icons" "$icons" Windows-modern org.kde.kwin.aurorae "$decoration")
old_values=()
for i in "${!keys[@]}"; do
    old_values+=("$(read_key "${files[i]}" "${groups[i]}" "${keys[i]}")")
done

notify_appearance() {
    # Match KDE's KLookAndFeelManager notifications for style and icons.
    busctl --user emit /KGlobalSettings org.kde.KGlobalSettings notifyChange ii 2 0 || return 1
    local group
    for group in 0 1 2 3 4 5; do
        busctl --user emit /KIconLoader org.kde.KIconLoader iconChanged i "$group" || return 1
    done
    busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null
}
apply_mode() {
    plasma-apply-colorscheme "$scheme" || return 1
    plasma-apply-desktoptheme "$plasma" || return 1
    local i
    for i in "${!keys[@]}"; do
        write_key "${files[i]}" "${groups[i]}" "${keys[i]}" "${values[i]}" || return 1
    done
    notify_appearance
}
if ! apply_mode; then
    echo "Appearance switch failed; attempting to restore previous appearance settings." >&2
    restored=true
    if [ "$old_scheme" != "$missing" ]; then
        plasma-apply-colorscheme "$old_scheme" || restored=false
    else
        write_key kdeglobals General ColorScheme "$missing" || true
        restored=false
    fi
    if [ "$old_plasma" != "$missing" ]; then
        plasma-apply-desktoptheme "$old_plasma" || restored=false
    else
        write_key plasmarc Theme name "$missing" || true
        restored=false
    fi
    for i in "${!keys[@]}"; do
        write_key "${files[i]}" "${groups[i]}" "${keys[i]}" "${old_values[i]}" || restored=false
    done
    notify_appearance || restored=false
    [ "$restored" = true ] || echo "Some appearance settings could not be restored; reselect the desired mode." >&2
    exit 1
fi
sync_accent || echo "Appearance switched; Kvantum accent synchronization remains incomplete." >&2
printf 'Windows Modern appearance: %s\n' "$mode"
