#!/bin/bash
# ───────────────────────────────────────────────────────────────────
#  install-themes.sh — Aurorae, color-schemes, Kvantum, Plasma, wallpapers
# ───────────────────────────────────────────────────────────────────
# shellcheck source=scripts/install-lib.sh
source "$(dirname "$0")/install-lib.sh"

info "Installing themes..."

# Prepare both renderer modes before replacing any installed files.
appearance_stage="$(mktemp -d)"
trap 'rm -rf -- "$appearance_stage"' EXIT
python3 "$SRC_DIR/scripts/theme/appearance-packages.py" "$appearance_stage" --component themes

step "Window decorations (Aurorae)"
ensure_dir "$AURORAE_DIR"
rm -rf "$AURORAE_DIR/Windows-modern"* "$AURORAE_DIR/__aurorae__svg__windows-modern"*
for mode in dark light; do
    package="windows-modern-$mode-aurorae"
    rm -rf "$AURORAE_DIR/$package"
    cp -r "$appearance_stage/aurorae/$package" "$AURORAE_DIR/"
done

# Scheme and Kvantum paints form one runtime palette. Serialize both
# replacements against the tray and the mode switch.
(
    lock_appearance_writes || exit 1
    step "Color schemes"
    ensure_dir "$SCHEMES_DIR"
    rm -f "$SCHEMES_DIR/WindowsModern"*.colors
    cp -- "$appearance_stage/color-schemes/"*.colors "$SCHEMES_DIR/"
    step "Kvantum themes"
    ensure_dir "$KVANTUM_DIR"
    rm -rf "$KVANTUM_DIR/Windows-modern"*
    cp -r "$appearance_stage/Kvantum/Windows-modern" "$KVANTUM_DIR/"
)
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
for mode in dark light; do
    rm -rf "$PLASMA_DIR/Windows-modern-$mode"
    cp -r "$appearance_stage/desktoptheme/Windows-modern-$mode" "$PLASMA_DIR/"
done
rm -rf "$appearance_stage"
trap - EXIT

# The global themes name this cursor theme.
install_cursor_theme

step "Wallpapers"
ensure_dir "$WALLPAPER_DIR"
if [ "$UID" -ne 0 ]; then
    bash "$SRC_DIR/scripts/prepare-native-assets.sh" || exit 1
fi
if [ "$UID" -ne 0 ] && [ -f "$NATIVE_ASSETS_DIR/manifest.json" ] && [ -d "$NATIVE_ASSETS_DIR/wallpapers/Windows-modern" ]; then
    step "Installing original Windows wallpaper packages"
    # Replace each owned package, not every similarly named wallpaper.
    for package in "$NATIVE_ASSETS_DIR/wallpapers/"*; do
        [[ -d "$package" && -f "$package/metadata.json" ]] || continue
        name="$(basename "$package")"
        case "$name" in Windows-modern*) ;; *) continue ;; esac
        python3 "$SRC_DIR/scripts/check-native-wallpaper.py" "$NATIVE_ASSETS_DIR" "$package" "$name" || exit 1
        stage="$(mktemp -d "$WALLPAPER_DIR/.windows-modern-wallpaper.XXXXXX")"
        if ! cp -a "$package" "$stage/new" ||
            ! python3 "$SRC_DIR/scripts/check-native-wallpaper.py" "$NATIVE_ASSETS_DIR" "$stage/new" "$name"; then
            rm -rf "$stage"; exit 1
        fi
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
else
    warn "Original wallpaper installation requires a desktop-user session. Keeping existing wallpapers."
fi

if [ "$UID" -ne 0 ]; then
    if [ -f "$TRANSPARENCY_OFF_FILE" ]; then
        apply_window_materials false || warn "Neutral window material update incomplete."
        apply_popup_materials false
    else
        apply_window_materials true || warn "Optional wallpaper tint update incomplete."
    fi
fi

info "Themes installed."

# ── Standalone: make the change visible ─────────────────────────────
# In batch mode the parent 'all' driver applies everything once at the
# end, so we only apply here when running standalone.
if ! is_batch && [ "$UID" -ne 0 ]; then
    step "Applying Kvantum engine & desktop theme"
    mode=dark
    if command -v kreadconfig6 &>/dev/null &&
       [ "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" = WindowsModernLight ]; then
        mode=light
    fi
    apply_kvantum_engine "$mode"
    if command -v plasma-apply-desktoptheme &>/dev/null; then plasma-apply-desktoptheme "Windows-modern-$mode" 2>/dev/null || true; fi
    if cursor_assets_valid "$ICONS_DIR/$NATIVE_CURSOR_THEME" && command -v kwriteconfig6 &>/dev/null; then
        current_cursor="$(kreadconfig6 --file kcminputrc --group Mouse --key cursorTheme 2>/dev/null || true)"
        if [ -z "$current_cursor" ] || [ "$current_cursor" = "$CURSOR_THEME" ] || [ "$current_cursor" = "$NATIVE_CURSOR_THEME" ]; then
            kwriteconfig6 --notify --file kcminputrc --group Mouse --key cursorTheme "$NATIVE_CURSOR_THEME"
        fi
    fi
    bash "$SRC_DIR/scripts/set-wallpaper.sh" || exit 1
    bash "$SRC_DIR/scripts/theme/switch-mode.sh" --sync-accent || warn "Kvantum accent synchronization incomplete."
fi
