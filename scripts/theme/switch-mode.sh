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
[ "$#" -ge 1 ] || fail "Specify an appearance operation."
usage="Usage: switch-mode.sh light|dark|--migrate|--sync-accent|--manual-accent RGB|--wallpaper-accent IMAGE...|--automatic-accent|--native-accent|--initialize-accent"
case "$1" in
    light|dark|--migrate|--sync-accent|--automatic-accent|--native-accent|--initialize-accent) [ "$#" -eq 1 ] || fail "$usage" ;;
    --manual-accent) [ "$#" -eq 2 ] || fail "$usage" ;;
    --wallpaper-accent) [ "$#" -ge 2 ] || fail "$usage" ;;
    *) fail "Unknown appearance mode: $1" ;;
esac
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
    # Exit 75 denotes a transient conflict; the tray retries it, not a
    # permanent configuration/decoder error.
    if flock -w 8 -E 75 9; then
        :
    else
        status=$?
        printf '%s\n' "Unable to acquire the appearance lock." >&2
        exit "$status"
    fi
elif [ "$1" != --migrate ]; then
    fail "No desktop runtime directory."
fi
# The active package may have changed while waiting for the lock.
active="$(read_key kdeglobals KDE LookAndFeelPackage)"
if [ "$active" = "$missing" ] && [ -f "$config/kdedefaults/package" ]; then
    active="$(cat "$config/kdedefaults/package")"
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

accent_python() {
    local python="${XDG_STATE_HOME:-$HOME/.local/state}/windows-modern-nixos-test/runtime/bin/python3"
    if [ ! -x "$python" ]; then
        python="$(command -v python3 || true)"
    fi
    [ -x "$python" ] || { echo "Python 3 is unavailable for accent synchronization." >&2; return 1; }
    printf '%s\n' "$python"
}

# In native mode, KDE's effective selection palette is authoritative.
# Do not change native accent settings or externally managed artwork.
sync_mode_accent() {
    local current_mode="$1" selection python result name
    local kvdir="$config/Kvantum/Windows-modern"
    case "$current_mode" in
        dark) name=Windows-modernDark ;;
        light) name=Windows-modern ;;
        *) return 1 ;;
    esac
    # A mode installed only in the system data directories is read-only.
    if [ ! -f "$kvdir/$name.kvconfig" ] && [ ! -f "$kvdir/$name.svg" ]; then
        printf 'skipped\n'
        return 0
    fi
    [ -f "$kvdir/accent-bindings.json" ] || {
        echo "Missing accent bindings; reinstall Windows Modern theme assets." >&2
        return 1
    }
    selection="$(read_key kdeglobals Colors:Selection BackgroundNormal)"
    [ "$selection" != "$missing" ] || { echo "Missing effective KDE selection color." >&2; return 1; }
    python="$(accent_python)" || return 1
    result="$("$python" -I "$(dirname -- "${BASH_SOURCE[0]}")/sync-accent.py" "$kvdir" "$current_mode" "$selection")" || return 1
    printf '%s\n' "$result"
}

sync_renderer_accent() {
    local current_mode="$1" action="$2" python result
    shift 2
    if { [ "$action" = sync ] || [ "$action" = reapply ]; } &&
       [ "$(read_key kdeglobals WindowsModernAccent Palette)" = "$missing" ]; then
        sync_mode_accent "$current_mode"
        return $?
    fi
    guard_config kdeglobals
    python="$(accent_python)" || return 1
    result="$("$python" -I "$(dirname -- "${BASH_SOURCE[0]}")/accent-control.py" "$current_mode" "$action" -- "$@")" || return $?
    case "$result" in
        native) sync_mode_accent "$current_mode" ;;
        changed|unchanged) printf '%s\n' "$result" ;;
        *) echo "Unexpected accent synchronization result." >&2; return 1 ;;
    esac
}

sync_accent() {
    local action="$1" current_scheme current_style current_theme current_mode result
    shift
    current_scheme="$(read_key kdeglobals General ColorScheme)"
    current_style="$(read_key kdeglobals KDE widgetStyle)"
    current_theme="$(read_key Kvantum/kvantum.kvconfig General theme)"
    if [ "$current_theme" != Windows-modern ]; then
        [ "$action" = sync ] && return 0
        fail "Select the Windows Modern Kvantum theme first."
    fi
    case "$current_scheme:$current_style" in
        WindowsModernDark:kvantum-dark) current_mode=dark ;;
        WindowsModernLight:kvantum) current_mode=light ;;
        *)
            [ "$action" = sync ] && return 0
            fail "Select a Windows Modern appearance mode first." ;;
    esac
    result="$(sync_renderer_accent "$current_mode" "$action" "$@")" || return $?
    if [ "$result" = changed ]; then
        # Stock plasma-integration skips same-name QStyle recreation.
        # The version-matched Kvantum build consumes the committed receipt.
        busctl --user emit /KGlobalSettings org.kde.KGlobalSettings notifyChange ii 2 0 || true
        printf '%s\n' "Accent assets updated."
    fi
}

sync_material() {
    local current_mode python result
    case "$(read_key kdeglobals General ColorScheme):$(read_key kdeglobals KDE widgetStyle)" in
        WindowsModernDark:kvantum-dark) current_mode=dark ;;
        WindowsModernLight:kvantum) current_mode=light ;;
        *) return 0 ;;
    esac
    # Off is independent of the accent mode; avoid launching the decoder.
    [ ! -e "$data/windows-modern/transparency-off" ] &&
        [ ! -L "$data/windows-modern/transparency-off" ] &&
        [ ! -e "$HOME/.local/share/windows-modern/transparency-off" ] &&
        [ ! -L "$HOME/.local/share/windows-modern/transparency-off" ] || return 0
    python="$(accent_python)" || return 1
    result="$("$python" -I "$(dirname -- "${BASH_SOURCE[0]}")/window-frames.py" --sync-live "$current_mode")" || return $?
    case "$result" in
        changed)
            # Do not restart KWin or applications. Same-mode reload is best effort.
            busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null || true
            busctl --user emit /KGlobalSettings org.kde.KGlobalSettings notifyChange ii 2 0 || true
            printf '%s\n' "Window material assets updated; open applications may need reopening." ;;
        unchanged|retained|skipped) ;;
        *) echo "Unexpected window material synchronization result." >&2; return 1 ;;
    esac
}

publish_kvantum_reload() {
    local python
    [ -f "$config/Kvantum/Windows-modern/accent-bindings.json" ] || return 0
    python="$(accent_python)" || return 1
    "$python" -I "$(dirname -- "${BASH_SOURCE[0]}")/sync-accent.py" \
        --publish-kvantum-reload "$config/Kvantum/Windows-modern" >/dev/null
}

sync_appearance() {
    local accent_status=0 material_status=0
    # They share the appearance lock and Kvantum atlas. Finish both paths
    # even if one fails, then preserve the existing bounded stale retry.
    sync_accent sync || accent_status=$?
    sync_material || material_status=$?
    if [ "$accent_status" -eq 75 ] || [ "$material_status" -eq 75 ]; then return 75; fi
    [ "$accent_status" -eq 0 ] || return "$accent_status"
    [ "$material_status" -eq 0 ] || return "$material_status"
    publish_kvantum_reload || echo "Appearance saved; live Kvantum reload receipt could not be published." >&2
    return 0
}

case "$1" in
    --sync-accent)
        [ "$active" = "$theme_id" ] || exit 0
        sync_appearance
        exit $? ;;
    --manual-accent|--wallpaper-accent|--automatic-accent|--native-accent|--initialize-accent)
        [ "$active" = "$theme_id" ] || fail "Apply the shared Windows Modern global theme first."
        action="${1#--}"
        action="${action%-accent}"
        shift
        sync_accent "$action" "$@" || exit $?
        publish_kvantum_reload || echo "Accent saved; live Kvantum reload receipt could not be published." >&2
        exit 0 ;;
esac

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
    # Stage the saved destination accent before publishing widgetStyle.
    # Automatic mode must wait for the native wallpaper's new image to
    # load instead of sampling the previous mode's image during the switch.
    sync_renderer_accent "$mode" reapply >/dev/null || return 1
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
    # Restore the previous renderer's accent before restoring widgetStyle,
    # for the same reason that the normal switch stages its destination.
    case "$old_scheme:${old_values[0]}:${old_values[3]}" in
        WindowsModernDark:kvantum-dark:Windows-modern)
            sync_renderer_accent dark reapply >/dev/null || restored=false ;;
        WindowsModernLight:kvantum:Windows-modern)
            sync_renderer_accent light reapply >/dev/null || restored=false ;;
    esac
    for i in "${!keys[@]}"; do
        write_key "${files[i]}" "${groups[i]}" "${keys[i]}" "${old_values[i]}" || restored=false
    done
    notify_appearance || restored=false
    [ "$restored" = true ] || echo "Some appearance settings could not be restored; reselect the desired mode." >&2
    exit 1
fi
# The tray also observes subsequent native image-load notifications.
# Request a refresh once now in case the image stayed the same.
sync_appearance || echo "Appearance switched; accent or material refresh incomplete." >&2
printf 'Windows Modern appearance: %s\n' "$mode"
