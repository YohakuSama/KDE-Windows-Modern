#!/bin/bash
# ───────────────────────────────────────────────────────────────────
#  install-transparency.sh — Windows' "Transparency effects" switch
#
#    ./install.sh transparency off   neutral opaque windows and solid popups
#    ./install.sh transparency on    wallpaper-tinted windows and popup blur
#    ./install.sh transparency refresh  resample the current saved wallpaper
#    ./install.sh transparency       show the current state
#
#  Application window bases are always opaque. Off restores neutral fills
#  and turns off KWin blur; on restores the saved blur setting and the
#  locally sampled saved image wallpaper tint. The choice is retained
#  across reinstall. This is a Mica-style static tint, not a DWM renderer.
# ───────────────────────────────────────────────────────────────────
# shellcheck source=scripts/install-lib.sh
source "$(dirname "$0")/install-lib.sh"

if [ "$UID" -eq 0 ]; then
    warn "Transparency is set per user — run this as yourself, not root. Skipping."
    exit 0
fi

mode="${1:-status}"
if [ "${WM_NIXOS_TRANSPARENCY:-0}" = 1 ]; then
    data="${XDG_DATA_HOME:-$HOME/.local/share}"
    config="${XDG_CONFIG_HOME:-$HOME/.config}"
    AURORAE_DIR="$data/aurorae/themes"
    PLASMA_DIR="$data/plasma/desktoptheme"
    KVANTUM_DIR="$config/Kvantum"
    TRANSPARENCY_OFF_FILE="$data/windows-modern/transparency-off"
fi
state="$TRANSPARENCY_OFF_FILE"

# Hold the shared lock across the full explicit operation, not just
# individual renderer writes. Read the saved state only after acquiring it.
case "$mode" in
    on|off|refresh)
        lock_appearance_writes || exit 1
        if [ -L "$state" ] || [ -L "$(dirname "$state")" ] ||
           [ -L "${XDG_CONFIG_HOME:-$HOME/.config}" ] || [ -L "${XDG_CONFIG_HOME:-$HOME/.config}/kwinrc" ]; then
            err "Transparency settings are externally managed."
            exit 1
        fi
        if [ -e "$state" ] && { [ ! -f "$state" ] || [ ! -O "$state" ]; }; then
            err "Invalid or externally owned transparency state."
            exit 1
        fi
        if [ -f "$state" ]; then
            saved="$(cat "$state")"
            case "$saved" in
                blurEnabled=|blurEnabled=true|blurEnabled=false) ;;
                *) err "Invalid saved blur preference."; exit 1 ;;
            esac
        fi
        ;;
esac

case "$mode" in
    off)
        ensure_dir "$(dirname "$state")"
        # Repeat off safely to repair a previously interrupted update.
        # The renderer transaction also saves/restores the blur preference.
        apply_window_materials false current all
        kwin_reconfigure
        info "Transparency effects off."
        step "Restart open apps; if the panel retains cached artwork, log out and back in."
        ;;
    on)
        if [ ! -f "$state" ]; then
            info "Transparency effects are already on."
            exit 0
        fi
        apply_window_materials true current all
        kwin_reconfigure
        info "Transparency effects on."
        step "Restart open apps; if the panel retains cached artwork, log out and back in."
        ;;
    refresh)
        if [ -f "$state" ]; then
            apply_window_materials false current all
        else
            apply_window_materials true current
        fi
        kwin_reconfigure
        info "Window material refreshed."
        step "Restart open apps to load the updated material."
        ;;
    status)
        if [ -f "$state" ]; then
            info "Transparency effects are off.  (./install.sh transparency on)"
        else
            info "Transparency effects are on.  (./install.sh transparency off)"
        fi
        ;;
    *)
        err "Usage: ./install.sh transparency [on|off|refresh]"
        exit 1
        ;;
esac
