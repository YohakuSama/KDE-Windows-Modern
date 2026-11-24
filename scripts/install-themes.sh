#!/bin/bash
# ───────────────────────────────────────────────────────────────────
#  install-themes.sh — Aurorae, color-schemes, Kvantum, Plasma, wallpapers
# ───────────────────────────────────────────────────────────────────
# shellcheck source=scripts/install-lib.sh
source "$(dirname "$0")/install-lib.sh"

info "Installing themes..."

step "Window decorations (Aurorae)"
ensure_dir "$AURORAE_DIR"
rm -rf "$AURORAE_DIR/Windows-modern"* "$AURORAE_DIR/__aurorae__svg__windows-modern"*
cp -r "$SRC_DIR/aurorae/"* "$AURORAE_DIR/"

step "Color schemes"
ensure_dir "$SCHEMES_DIR"
rm -f "$SCHEMES_DIR/WindowsModern"*.colors
cp -r "$SRC_DIR/color-schemes/"*.colors "$SCHEMES_DIR/"

step "Kvantum themes"
ensure_dir "$KVANTUM_DIR"
rm -rf "$KVANTUM_DIR/Windows-modern"*
cp -r "$SRC_DIR/Kvantum/"* "$KVANTUM_DIR/"
# Keep "Transparency effects: off" (./install.sh transparency) across reinstalls.
if [ -f "$TRANSPARENCY_OFF_FILE" ]; then
    kvantum_transparency false
    step "Transparency effects stay off"
fi

step "Kvantum theme selection"
if [ "$UID" -ne 0 ]; then
    # Kvantum reads ~/.config/Kvantum/kvantum.kvconfig (capital K), not ~/.config/kvantum.kvconfig.
    if command -v kwriteconfig6 &>/dev/null; then
        kwriteconfig6 --file Kvantum/kvantum.kvconfig --group General --key theme Windows-modern
    else
        ensure_dir "$HOME/.config/Kvantum"
        KVANTUM_CONFIG="$HOME/.config/Kvantum/kvantum.kvconfig"
        if [ -f "$KVANTUM_CONFIG" ] && grep -q "^theme=" "$KVANTUM_CONFIG"; then
            sed -i 's/^theme=.*/theme=Windows-modern/' "$KVANTUM_CONFIG"
        else
            echo "[General]" > "$KVANTUM_CONFIG"
            echo "theme=Windows-modern" >> "$KVANTUM_CONFIG"
        fi
    fi
    # Remove stray config written by earlier versions of this installer.
    [ -f "$HOME/.config/kvantum.kvconfig" ] && rm -f "$HOME/.config/kvantum.kvconfig"
else
    warn "Installed system-wide: select Windows-modern in Kvantum Manager"
fi

step "Plasma desktop themes"
ensure_dir "$PLASMA_DIR"
rm -rf "$PLASMA_DIR/Windows-modern"*
cp -r "$SRC_DIR/plasma/desktoptheme/"* "$PLASMA_DIR/"

# The global themes name this cursor theme.
install_cursor_theme

step "Wallpapers"
ensure_dir "$WALLPAPER_DIR"
if [ "$UID" -ne 0 ] && [ -f "$SRC_DIR/native-resources/resource-manifest.json" ]; then
    bash "$SRC_DIR/scripts/prepare-native-assets.sh" || exit 1
fi
if [ "$UID" -ne 0 ] && [ -f "$NATIVE_ASSETS_DIR/manifest.json" ] && [ -d "$NATIVE_ASSETS_DIR/wallpapers/Windows-modern" ]; then
    step "Installing original Windows wallpaper packages"
    # Replace each owned package, not every similarly named wallpaper.
    for package in "$NATIVE_ASSETS_DIR/wallpapers/"*; do
        [[ -d "$package" && -f "$package/metadata.json" ]] || continue
        name="$(basename "$package")"
        case "$name" in Windows-modern*) ;; *) continue ;; esac
        stage="$(mktemp -d "$WALLPAPER_DIR/.windows-modern-wallpaper.XXXXXX")"
        cp -a "$package" "$stage/new" || { rm -rf "$stage"; exit 1; }
        if [ -e "$WALLPAPER_DIR/$name" ] || [ -L "$WALLPAPER_DIR/$name" ]; then
            mv "$WALLPAPER_DIR/$name" "$stage/previous" || { rm -rf "$stage"; exit 1; }
        fi
        if ! mv "$stage/new" "$WALLPAPER_DIR/$name"; then
            [ ! -e "$stage/previous" ] || mv "$stage/previous" "$WALLPAPER_DIR/$name"
            rm -rf "$stage"
            exit 1
        fi
        rm -rf "$stage"
    done
elif [ -f "$WALLPAPER_DIR/Windows-modern/metadata.json" ] &&
     grep -q '"Local Windows reference image"' "$WALLPAPER_DIR/Windows-modern/metadata.json"; then
    step "Preserving the previously imported original Bloom wallpaper"
else
    cp -r "$SRC_DIR/wallpaper/"* "$WALLPAPER_DIR/"
    warn "Bundled compatibility wallpaper installed; original Windows Bloom requires your local resources."
fi

if [ "$UID" -ne 0 ]; then
    if [ -f "$TRANSPARENCY_OFF_FILE" ]; then
        apply_window_materials false
        apply_popup_materials false
    else
        apply_window_materials true
    fi
fi

info "Themes installed."

# ── Standalone: make the change visible ─────────────────────────────
# In batch mode the parent 'all' driver applies everything once at the
# end, so we only apply here when running standalone.
if ! is_batch && [ "$UID" -ne 0 ]; then
    step "Applying Kvantum engine & desktop theme"
    apply_kvantum_engine dark
    if command -v plasma-apply-desktoptheme &>/dev/null; then plasma-apply-desktoptheme Windows-modern-dark 2>/dev/null || true; fi
    bash "$SRC_DIR/scripts/set-wallpaper.sh" || exit 1
fi
