#!/bin/bash
# ───────────────────────────────────────────────────────────────────
#  install-transparency.sh — Windows' "Transparency effects" switch
#
#    ./install.sh transparency off   neutral opaque windows and solid popups
#    ./install.sh transparency on    wallpaper-tinted windows and popup blur
#    ./install.sh transparency       show the current state
#
#  Application window bases are always opaque. Off restores neutral fills
#  and turns off KWin blur; on restores the saved blur setting and the
#  locally sampled Windows-modern wallpaper tint. The choice is retained
#  across reinstall. This is a Mica-style static tint, not a DWM renderer.
# ───────────────────────────────────────────────────────────────────
# shellcheck source=scripts/install-lib.sh
source "$(dirname "$0")/install-lib.sh"

if [ "$UID" -eq 0 ]; then
    warn "Transparency is set per user — run this as yourself, not root. Skipping."
    exit 0
fi

state="$TRANSPARENCY_OFF_FILE"
mode="${1:-status}"

case "$mode" in
    off)
        if [ -f "$state" ]; then
            info "Transparency effects are already off."
            exit 0
        fi
        ensure_dir "$(dirname "$state")"
        # Remember the blur setting as it was ("" = never set: KWin's default, on).
        echo "blurEnabled=$(kreadconfig6 --file kwinrc --group Plugins --key blurEnabled)" > "$state"
        kvantum_transparency false
        apply_window_materials false
        apply_popup_materials false
        kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled false
        kwin_reconfigure
        info "Transparency effects off."
        step "Restart open apps; if the panel retains cached artwork, log out and back in."
        ;;
    on)
        if [ ! -f "$state" ]; then
            info "Transparency effects are already on."
            exit 0
        fi
        previous="$(sed -n 's/^blurEnabled=//p' "$state")"
        if [ -n "$previous" ]; then
            kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled "$previous"
        else
            kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled --delete
        fi
        kvantum_transparency true
        apply_window_materials true
        apply_popup_materials true
        rm -f "$state"
        kwin_reconfigure
        info "Transparency effects on."
        step "Restart open apps; if the panel retains cached artwork, log out and back in."
        ;;
    status)
        if [ -f "$state" ]; then
            info "Transparency effects are off.  (./install.sh transparency on)"
        else
            info "Transparency effects are on.  (./install.sh transparency off)"
        fi
        ;;
    *)
        err "Usage: ./install.sh transparency [on|off]"
        exit 1
        ;;
esac
