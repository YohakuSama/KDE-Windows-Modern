#!/bin/bash
# ───────────────────────────────────────────────────────────────────
#  install-startmenu.sh — Start Menu and Run dialog applets (pure QML)
# ───────────────────────────────────────────────────────────────────
# shellcheck source=scripts/install-lib.sh
source "$(dirname "$0")/install-lib.sh"

start_src="$SRC_DIR/plasma/applets/org.kde.windowsmodern.startmenu"
run_src="$SRC_DIR/plasma/applets/org.kde.windowsmodern.run"
[ -d "$start_src" ] || { warn "Start Menu not found — skipping."; exit 0; }

install_applet() {
    local src="$1" id="$2"
    [ -d "$src" ] || { warn "$id not found — skipping."; return 0; }
    if command -v kpackagetool6 &>/dev/null; then
        if grep -q "$id" <<< "$(kpackagetool6 --list --type Plasma/Applet 2>/dev/null)"; then
            step "Upgrading $id"
            kpackagetool6 --upgrade "$src" --type Plasma/Applet
        else
            step "Installing $id"
            kpackagetool6 --install "$src" --type Plasma/Applet
        fi
    else
        warn "kpackagetool6 not found — falling back to manual copy for $id."
        ensure_dir "$APPLETS_DIR"
        rm -rf "${APPLETS_DIR:?}/$id"
        cp -r "$src" "$APPLETS_DIR/"
    fi
}

info "Installing Start Menu and Run dialog applets..."
install_applet "$start_src" "org.kde.windowsmodern.startmenu"
install_applet "$run_src" "org.kde.windowsmodern.run"
info "Start Menu and Run dialog installed."

# Plasma Shell must be restarted for the updated applet to be reloaded in
# the running session. In batch mode the parent 'all' driver restarts
# once at the end; standalone we restart now (no prompt).
if is_batch; then
    exit 0
fi

if ! pgrep -x plasmashell >/dev/null 2>&1; then
    warn "Plasma Shell not running — Start Menu will load on next session."
    exit 0
fi

if ! is_interactive; then
    info "Non-interactive install — restarting Plasma Shell to apply."
    restart_plasmashell
    exit 0
fi

restart_plasmashell
