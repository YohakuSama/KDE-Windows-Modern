#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck source=scripts/install-lib.sh
source "$(dirname "$0")/install-lib.sh"

if [ "$UID" -eq 0 ]; then
    err "Run the sound theme installer as your desktop user."
    exit 1
fi
SOURCE="$NATIVE_ASSETS_DIR/sounds/windows-modern"
if [ ! -f "$SOURCE/index.theme" ]; then
    err "Import your Windows resources first (scripts/import-windows-assets.py)."
    exit 1
fi
SOUND_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/sounds/windows-modern"
BACKUP="$HOME/.local/share/windows-modern/backup/sound-theme"
ensure_dir "$(dirname "$SOUND_DIR")"
rm -rf "$SOUND_DIR"
cp -a "$SOURCE" "$SOUND_DIR"
if command -v kwriteconfig6 >/dev/null && command -v kreadconfig6 >/dev/null; then
    ensure_dir "$(dirname "$BACKUP")"
    if [ ! -f "$BACKUP" ]; then
        kreadconfig6 --file kdeglobals --group Sounds --key Theme --default ocean > "$BACKUP"
    fi
    kwriteconfig6 --file kdeglobals --group Sounds --key Theme windows-modern
else
    warn "Select Windows Modern (local) in System Settings > System Sounds."
fi
info "Local Windows sound theme installed. Existing notification sound enable/disable preference preserved."
