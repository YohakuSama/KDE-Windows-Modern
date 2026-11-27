#!/bin/bash
# ───────────────────────────────────────────────────────────────────
#  install-icons.sh — Windows Modern icon pack
# ───────────────────────────────────────────────────────────────────
# shellcheck source=scripts/install-lib.sh
source "$(dirname "$0")/install-lib.sh"

# The source checkout keeps one canonical SVG per alias group. The full
# installation archive already contains the materialized compatibility files.
if [ -f "$SRC_DIR/icons/windows-modern-aliases.json" ]; then
    python3 -I "$SRC_DIR/scripts/verify-svg-aliases.py" --check
fi

THEME_NAME="windows-modern"
PROJECT_DIR="$SRC_DIR"
SRC_DIR="$SRC_DIR/icons/$THEME_NAME"
THEME_DIR="$ICONS_DIR/$THEME_NAME"

if [ ! -d "$SRC_DIR" ]; then
    warn "Icon pack not found at $SRC_DIR"
    exit 1
fi

# Owner bundles include the original indexed resources, even on a clean machine.
if [ "$UID" -ne 0 ] && [ -f "$PROJECT_DIR/native-resources/resource-manifest.json" ]; then
    bash "$PROJECT_DIR/scripts/prepare-native-assets.sh" || exit 1
fi

# Never silently overlay an older import on a newer theme. Reuse the
# original local source if the mapping changed; leave the installed theme
# untouched if the source was removed or verification fails.
if [ "$UID" -ne 0 ] && [ -f "$NATIVE_ASSETS_DIR/manifest.json" ]; then
    if ! python3 "$PROJECT_DIR/scripts/check-native-icon-import.py" "$NATIVE_ASSETS_DIR" "$PROJECT_DIR/scripts/native-assets-map.json"; then
        info "Refreshing local Windows icon mappings from the remembered source..."
        if ! bash "$PROJECT_DIR/scripts/prepare-native-assets.sh" ||
            ! python3 "$PROJECT_DIR/scripts/check-native-icon-import.py" "$NATIVE_ASSETS_DIR" "$PROJECT_DIR/scripts/native-assets-map.json"; then
            err "Local Windows icon refresh failed. Existing installed icon theme was not removed."
            exit 1
        fi
    fi
else
    warn "No local native asset manifest: installing bundled compatibility artwork, not verified Windows originals."
fi

# Verify both original owner-selected SVGs before touching installed icons.
store_dir="${XDG_DATA_HOME:-$HOME/.local/share}/windows-modern/store-artwork"
python3 "$PROJECT_DIR/scripts/store-artwork.py" prepare "$store_dir" \
    --bundled "$PROJECT_DIR/bundled-store-artwork" || exit 1

info "Installing icon pack ($THEME_NAME)..."
step "Removing old installation"
rm -rf "$THEME_DIR"

step "Copying $THEME_NAME"
ensure_dir "$ICONS_DIR"
cp -a "$SRC_DIR" "$THEME_DIR"

# Same theme ID and filenames; no competing Windows icon theme.
if [ "$UID" -ne 0 ] && [ -f "$NATIVE_ASSETS_DIR/manifest.json" ]; then
    step "Applying local Windows icon mappings"
    while IFS= read -r -d '' asset; do
        relative="${asset#"$NATIVE_ASSETS_DIR/icons/"}"
        stem="${relative%.svg}"
        rm -f "$THEME_DIR/$stem.png" "$THEME_DIR/$stem.svgz" "$THEME_DIR/$stem.xpm"
    done < <(find "$NATIVE_ASSETS_DIR/icons" -type f -name '*.svg' -print0)
    cp -a --remove-destination "$NATIVE_ASSETS_DIR/icons/." "$THEME_DIR/"
fi

# The light overlay inherits every icon except the Store aliases.
rm -rf "$ICONS_DIR/windows-modern-light"
python3 "$PROJECT_DIR/scripts/store-artwork.py" apply "$store_dir" "$THEME_DIR" \
    "$ICONS_DIR/windows-modern-light" || exit 1
if command -v gtk-update-icon-cache &>/dev/null; then
    for dir in "$THEME_DIR" "$ICONS_DIR/windows-modern-light"; do
        gtk-update-icon-cache -f "$dir" &>/dev/null || true
    done
fi

info "Icons installed ($THEME_NAME)"

# ── Apply icon theme instantly (same as System Settings) ───────────
# Skipped in batch mode — the parent 'all' driver applies the whole
# look-and-feel (which sets the icon theme via defaults) at the end.
if is_batch; then
    exit 0
fi
if command -v kwriteconfig6 &>/dev/null; then
    if command -v kreadconfig6 >/dev/null &&
       [ "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" = WindowsModernLight ]; then
        THEME_NAME=windows-modern-light
    fi
    step "Applying icon theme ($THEME_NAME)"
    # Plasma 6 stores the theme in kcmicons; kdeglobals is the legacy fallback
    kwriteconfig6 --file kdeglobals --group Icons --key Theme "$THEME_NAME"
    kwriteconfig6 --file kcmicons --group Icons --key Theme "$THEME_NAME"

    if command -v kbuildsycoca6 &>/dev/null; then
        step "Refreshing KDE icon cache"
        kbuildsycoca6 --noincremental &>/dev/null || true
    fi
else
    warn "kwriteconfig6 not found — icon theme installed but not activated."
    warn "Set it manually in System Settings > Appearance > Icons."
fi
