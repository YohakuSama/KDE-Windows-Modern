#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Apply the installed wallpaper packages via KDE's own wallpaper mechanisms.
set -euo pipefail

WALLPAPER_ID="Windows-modern"
APPLY_TOOL="plasma-apply-wallpaperimage"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
NATIVE_DIR="$DATA_HOME/windows-modern/native-assets"
USER_WALLPAPERS="$DATA_HOME/wallpapers"

find_wallpaper() {
    local id="$1" dir
    for dir in "$USER_WALLPAPERS/$id" "$HOME/.local/share/wallpapers/$id" "/usr/share/wallpapers/$id"; do
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

# Distinguish the owner's imported Bloom from the public compatibility
# artwork. Never silently pass the bundled wallpaper off as the original.
is_native_bloom() {
    local dir="$1"
    [ -f "$dir/metadata.json" ] &&
    grep -q '"Local Windows reference image"' "$dir/metadata.json" &&
    find "$dir/contents/images" -maxdepth 1 -type f -iname '*.jpg' -size +0c -print -quit 2>/dev/null | grep -q . &&
    find "$dir/contents/images_dark" -maxdepth 1 -type f -iname '*.jpg' -size +0c -print -quit 2>/dev/null | grep -q .
}

restore_native_bloom() {
    local original="$NATIVE_DIR/wallpapers/$WALLPAPER_ID" stage destination
    [ -f "$NATIVE_DIR/manifest.json" ] && is_native_bloom "$original" || return 1
    mkdir -p "$USER_WALLPAPERS"
    destination="$USER_WALLPAPERS/$WALLPAPER_ID"
    stage="$(mktemp -d "$USER_WALLPAPERS/.windows-modern-bloom.XXXXXX")"
    if ! cp -a "$original" "$stage/new"; then
        rm -rf "$stage"
        return 1
    fi
    if [ -e "$destination" ] || [ -L "$destination" ]; then
        if ! mv "$destination" "$stage/previous"; then
            rm -rf "$stage"
            return 1
        fi
    fi
    if ! mv "$stage/new" "$destination"; then
        [ ! -e "$stage/previous" ] || mv "$stage/previous" "$destination"
        rm -rf "$stage"
        return 1
    fi
    rm -rf "$stage"
}

if [ "$EUID" -eq 0 ]; then
    echo "Apply the desktop wallpaper as the desktop user, not root." >&2
    exit 1
fi
if ! command -v "$APPLY_TOOL" &>/dev/null; then
    echo "$APPLY_TOOL not found; the desktop wallpaper has not been applied." >&2
    exit 1
fi

if [ -f "$NATIVE_DIR/manifest.json" ] && is_native_bloom "$NATIVE_DIR/wallpapers/$WALLPAPER_ID"; then
    restore_native_bloom || { echo "Could not restore the imported Bloom package." >&2; exit 1; }
fi
wallpaper_dir="$(find_wallpaper "$WALLPAPER_ID" || true)"
if [ -z "$wallpaper_dir" ] || ! is_native_bloom "$wallpaper_dir"; then
    # Recover from the remembered owner archive if the generated package
    # is missing, without requiring another upload.
    if [ -f "$NATIVE_DIR/manifest.json" ] && [ "${1:-}" != "--allow-fallback" ]; then
        importer="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/import-windows-assets.py"
        if python3 "$importer" --reuse --output "$NATIVE_DIR" && restore_native_bloom; then
            wallpaper_dir="$USER_WALLPAPERS/$WALLPAPER_ID"
        fi
    fi
fi
if [ -z "$wallpaper_dir" ] || ! is_native_bloom "$wallpaper_dir"; then
    if [ "${1:-}" != "--allow-fallback" ] || [ -z "$wallpaper_dir" ]; then
        echo "Original Windows 11 Bloom (img0.jpg / img19.jpg) unavailable. The original wallpaper has NOT been restored." >&2
        echo "Import your local Windows resource archive, then run ./install.sh wallpaper. For the public substitute only, pass --allow-fallback." >&2
        exit 1
    fi
    echo "Applying the explicitly requested compatibility wallpaper, not original Bloom." >&2
fi

# The layout reset/restart may briefly leave Plasma's D-Bus service
# unavailable. Apply once it is ready, and surface a real failure.
applied=false
for attempt in 1 2 3 4 5; do
    if "$APPLY_TOOL" "$wallpaper_dir"; then
        applied=true
        break
    fi
    sleep 1
done
if [ "$applied" != true ]; then
    echo "Plasma did not accept the desktop wallpaper." >&2
    exit 1
fi
echo "Desktop wallpaper applied from $wallpaper_dir."

# Keep the lock package from the same installation as the desktop package.
lock_dir="$wallpaper_dir"
if [ -d "$(dirname "$wallpaper_dir")/Windows-modern-lock" ]; then
    lock_dir="$(dirname "$wallpaper_dir")/Windows-modern-lock"
fi
set_lock_wallpaper "$lock_dir"
