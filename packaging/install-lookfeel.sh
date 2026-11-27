#!/bin/bash
# ───────────────────────────────────────────────────────────────────
#  install-lookfeel.sh — One global theme with light/dark modes
#
#  Standalone: asks Light/Dark, then applies the chosen theme with a
#  layout reset (so panels/widgets are rebuilt) + wallpaper + Kvantum.
#  In batch mode (WM_BATCH=1): installs files only — the parent 'all'
#  driver performs the single apply at the end.
# ───────────────────────────────────────────────────────────────────
# shellcheck source=scripts/install-lib.sh
source "$(dirname "$0")/install-lib.sh"

info "Installing the shared Windows Modern global theme..."

ensure_dir "$LOOKFEEL_DIR"
appearance_stage="$(mktemp -d)"
if ! python3 "$SRC_DIR/scripts/theme/appearance-packages.py" "$appearance_stage" --component lookfeel; then
    rm -rf "$appearance_stage"
    exit 1
fi
# The existing dark ID is retained for the boot greeter and old settings.
rm -rf "$LOOKFEEL_DIR/org.kde.windowsmodern.dark"
cp -r "$appearance_stage/org.kde.windowsmodern.dark" "$LOOKFEEL_DIR/"
rm -rf "$appearance_stage"
if [ "$UID" -ne 0 ]; then
    bash "$SRC_DIR/scripts/theme/switch-mode.sh" --migrate
fi
rm -rf "$LOOKFEEL_DIR/org.kde.windowsmodern.light"
# Keep the shipped sign-in portrait. The imageres account-control icon
# is not the current Windows sign-in screen's default account picture.

# The shared global theme names the modern multi-size cursor: make sure it exists, or
# applying a theme would leave the cursor on a fallback.
install_cursor_theme

info "Global themes installed."

# ── Batch: files only — parent applies at the end ──────────────────
if is_batch; then
    exit 0
fi

# ── Standalone: ask Light/Dark and apply ───────────────────────────
if [ "$UID" -eq 0 ]; then
    warn "Running as root — apply the theme manually from a user session."
    warn "  System Settings → Appearance → Global Theme."
    exit 0
fi

if ! command -v plasma-apply-lookandfeel &>/dev/null; then
    warn "plasma-apply-lookandfeel not found — apply manually in System Settings."
    exit 0
fi

if ! is_interactive; then
    info "Non-interactive install. Theme files are in place."
    info "To apply:  plasma-apply-lookandfeel -a org.kde.windowsmodern.dark --resetLayout"
    info "Switch mode afterwards: bash $SRC_DIR/scripts/theme/switch-mode.sh light (or dark)"
    info "Then set the wallpaper:  bash $SRC_DIR/scripts/set-wallpaper.sh"
    exit 0
fi

variant="$(ask_theme_variant)"
theme="$(lookfeel_id "$variant")"

apply_lookandfeel "$theme" reset native
apply_appearance_mode "$variant"
# Let the layout script finish writing panels before restarting Plasma.
sleep 1
restart_plasmashell
bash "$SRC_DIR/scripts/set-wallpaper.sh" || exit 1

echo ""
info "Done. If panels do not appear, run:"
info "  killall plasmashell && kstart6 plasmashell"
