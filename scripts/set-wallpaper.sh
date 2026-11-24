#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Apply the installed wallpaper packages via KDE's own wallpaper mechanisms.
set -euo pipefail

WALLPAPER_ID="Windows-modern"
APPLY_TOOL="plasma-apply-wallpaperimage"

find_wallpaper() {
    local id="$1" dir
    for dir in "$HOME/.local/share/wallpapers/$id" "/usr/share/wallpapers/$id"; do
        if [ -d "$dir" ]; then
            printf '%s\n' "$dir"
            return 0
        fi
    done
    return 1
}

set_lock_wallpaper() {
    local dir="$1" key
    if ! command -v kwriteconfig6 &>/dev/null; then
        echo "kwriteconfig6 not found; select the lock wallpaper in System Settings." >&2
        return 0
    fi
    for key in Image PreviewImage; do
        kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper \
            --group org.kde.image --group General --key "$key" "file://$dir/"
    done
    kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin org.kde.image
    echo "Lock screen wallpaper set to $(basename "$dir")."
}

# A standalone session-lock install must not change the desktop wallpaper.
# Keep the current lock wallpaper if no native lock package was installed.
if [ "${1:-}" = "--lock-only" ]; then
    if lock_dir="$(find_wallpaper Windows-modern-lock)"; then
        set_lock_wallpaper "$lock_dir"
    fi
    exit 0
fi

if ! command -v "$APPLY_TOOL" &>/dev/null; then
    echo "$APPLY_TOOL not found; set the desktop wallpaper in System Settings." >&2
    exit 0
fi

if ! wallpaper_dir="$(find_wallpaper "$WALLPAPER_ID")"; then
    echo "Wallpaper package '$WALLPAPER_ID' not found. Install it with ./install.sh themes." >&2
    exit 1
fi

"$APPLY_TOOL" "$wallpaper_dir"
echo "Desktop wallpaper set to $WALLPAPER_ID."

# Keep the lock package from the same installation as the desktop package.
lock_dir="$wallpaper_dir"
if [ -d "$(dirname "$wallpaper_dir")/Windows-modern-lock" ]; then
    lock_dir="$(dirname "$wallpaper_dir")/Windows-modern-lock"
fi
set_lock_wallpaper "$lock_dir"
