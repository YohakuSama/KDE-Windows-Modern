#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Apply only verified owner images. Never crop or regenerate wallpaper bytes.
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
native="${WM_NATIVE_ASSETS_DIR:-$data/windows-modern/native-assets}"
wallpapers="$data/wallpapers"
[ "$EUID" -ne 0 ] || { echo "Apply wallpapers as the desktop user." >&2; exit 1; }
case "${1:-}" in ""|--lock-only|--allow-fallback) ;; *) echo "Unknown wallpaper option" >&2; exit 2;; esac

verify() {
    python3 "$script_dir/check-native-wallpaper.py" "$native" "$1" "$2"
}

ensure_native() {
    if python3 "$script_dir/check-native-icon-import.py" "$native" "$script_dir/native-assets-map.json" &&
       verify "$native/wallpapers/Windows-modern" Windows-modern &&
       verify "$native/wallpapers/Windows-modern-lock" Windows-modern-lock; then
        return 0
    fi
    bash "$script_dir/prepare-native-assets.sh" &&
        verify "$native/wallpapers/Windows-modern" Windows-modern &&
        verify "$native/wallpapers/Windows-modern-lock" Windows-modern-lock
}

install_package() {
    local name="$1" source="$native/wallpapers/$1" stage destination="$wallpapers/$1"
    verify "$source" "$name" || return 1
    mkdir -p "$wallpapers"
    stage="$(mktemp -d "$wallpapers/.windows-modern-wallpaper.XXXXXX")"
    if ! cp -a "$source" "$stage/new" || ! verify "$stage/new" "$name"; then
        rm -rf "$stage"; return 1
    fi
    if [ -e "$destination" ] || [ -L "$destination" ]; then
        mv "$destination" "$stage/previous" || { rm -rf "$stage"; return 1; }
    fi
    if ! mv "$stage/new" "$destination"; then
        [ ! -e "$stage/previous" ] || mv "$stage/previous" "$destination"
        rm -rf "$stage"; return 1
    fi
    rm -rf "$stage"
}

set_lock() {
    local directory="$1" key
    command -v kwriteconfig6 >/dev/null || { echo "kwriteconfig6 is required." >&2; return 1; }
    for key in Image PreviewImage; do
        kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper \
            --group org.kde.image --group General --key "$key" "file://$directory/"
    done
    kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper \
        --group org.kde.image --group General --key FillMode --type int 2
    kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin org.kde.image
}

if [ "${1:-}" = --lock-only ]; then
    ensure_native || exit 1
    install_package Windows-modern-lock && set_lock "$wallpapers/Windows-modern-lock"
    exit $?
fi

command -v plasma-apply-wallpaperimage >/dev/null || { echo "plasma-apply-wallpaperimage is required." >&2; exit 1; }
if ensure_native; then
    install_package Windows-modern
    install_package Windows-modern-lock
    desktop="$wallpapers/Windows-modern"
    lock="$wallpapers/Windows-modern-lock"
elif [ "${1:-}" = --allow-fallback ]; then
    # Explicit opt-in only, never replace an original installed package.
    desktop="$(cd "$script_dir/../wallpaper/Windows-modern" && pwd)"
    lock="$desktop"
    echo "Explicitly requested compatibility artwork; not an original Windows image." >&2
else
    echo "Owner's original wallpaper unavailable; leaving the current wallpaper untouched." >&2
    exit 1
fi

# Native Plasma API, aspect-preserving fit: the entire image remains visible.
# Do not silently fall back to the default crop mode on unsupported versions.
applied=false
for _ in 1 2 3 4 5; do
    if plasma-apply-wallpaperimage --fill-mode preserveAspectFit "$desktop"; then
        applied=true; break
    fi
    sleep 1
done
[ "$applied" = true ] || { echo "Plasma did not apply the verified wallpaper in fit mode." >&2; exit 1; }
set_lock "$lock"
echo "Desktop wallpaper fitted; lock wallpaper fills the screen without changing source bytes: $desktop"
