#!/bin/bash
# ───────────────────────────────────────────────────────────────────
#  Windows Modern — unified installer
#
#  Usage:  ./install.sh              Interactive menu (default = Everything)
#          ./install.sh all          Install everything (asks Light/Dark)
#          ./install.sh all --dark   ...non-interactive, Dark
#          ./install.sh all --light  ...non-interactive, Light
#          ./install.sh <component>  Install one component (applies immediately)
#          ./install.sh --help       Show usage
#
#  Components are installed by scripts/install-<name>.sh
# ───────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# NixOS uses a complete reversible test install, not the old preview.
if grep -Eq '^ID="?nixos"?$' /etc/os-release 2>/dev/null; then
    case "${1:-menu}" in
        --light|--dark) exec bash "$SCRIPT_DIR/install-nixos.sh" menu "$@" ;;
        *) exec bash "$SCRIPT_DIR/install-nixos.sh" "$@" ;;
    esac
fi
# shellcheck source=scripts/install-lib.sh
source "$SCRIPT_DIR/scripts/install-lib.sh"
# shellcheck source=scripts/config-backup.sh
source "$SCRIPT_DIR/scripts/config-backup.sh"

# ── Install component by name (non-fatal on failure) ────────────────
# Components that failed, reported at the end instead of a plain "Done.".
FAILED_COMPONENTS=()
WM_TRANSLATIONS_INSTALLED=0

is_nixos() {
    [ -r /etc/os-release ] && grep -Eq '^ID="?nixos"?$' /etc/os-release
}

# The mutable /usr plugin installer is incompatible with NixOS.
nixos_full_install_unavailable() {
    err "Full plugin/layout installation is not yet supported on NixOS."
    err "Use bash ./install.sh preview --dark (or --light) for user-space testing."
    err "Preview preserves the existing task manager and system tray."
}

install_component() {
    local name="$1"
    local script="$SCRIPT_DIR/scripts/install-${name}.sh"
    if is_nixos; then
        case "$name" in
            systray|icontasks|greeter)
                nixos_full_install_unavailable
                return 1
                ;;
            lookfeel)
                if ! is_batch; then
                    nixos_full_install_unavailable
                    return 1
                fi
                ;;
        esac
    fi
    if [ -x "$script" ]; then
        # Install the applet-domain catalogs before any applet reloads.
        if [ "$name" != deps ] && [ "$WM_TRANSLATIONS_INSTALLED" -eq 0 ]; then
            if ! python3 -I "$SRC_DIR/scripts/install-translations.py"; then
                err "Windows Modern translations could not be installed."
                FAILED_COMPONENTS+=(translations)
                return 1
            fi
            WM_TRANSLATIONS_INSTALLED=1
        fi
        bash "$script" || {
            FAILED_COMPONENTS+=("$name")
            err "Component '$name' failed — continuing with remaining components."
            err "If this is a C++ applet (systray/icontasks), install build deps and re-run:"
            err "  ./install.sh $name"
        }
    else
        err "Unknown component: $name (no script at $script)"
        return 1
    fi
}

# ── Install everything (menu 1 + CLI 'all') ─────────────────────────
# Phase A: atomic pieces (themes, icons, applets, sessionlock)
# Phase B: compose (layout template, look-and-feel files)
# Phase C: apply once (KWin tweaks, theme+layout reset, Kvantum engine, restart)
install_everything() {
    local variant="${1:-}"
    if is_nixos; then
        nixos_full_install_unavailable
        return 1
    fi

    # Resolve variant: flag > interactive prompt > dark default
    if [ -z "$variant" ]; then
        variant="$(ask_theme_variant)"
    fi
    local theme; theme="$(lookfeel_id "$variant")"

    echo ""
    info "Installing everything (${variant})..."

    # Batch mode: children install files only — we apply once at the end.
    export WM_BATCH=1

    # ── Phase A: atomic pieces ──
    install_component deps
    info "[1/3] Installing themes, icons, and applets..."
    install_component themes
    install_component icons
    install_component showdesk
    install_component startmenu
    install_component systray
    install_component icontasks
    install_component digitalclock
    install_component taskbarbuttons   # Add Widgets only, not on the panel
    install_component sessionlock
    install_component alttab

    # ── Phase B: compose (layout references applets; lookfeel references everything) ──
    info "[2/3] Composing layout and global themes..."
    install_component layout
    install_component lookfeel

    unset WM_BATCH

    # Never reset a working panel to a layout with missing components.
    if [ "${#FAILED_COMPONENTS[@]}" -ne 0 ]; then
        err "Not applying the new layout: failed components: ${FAILED_COMPONENTS[*]}"
        warn "Files already staged remain installed; restore saved settings with bash ./uninstall.sh --restore."
        restart_plasmashell || true
        return 1
    fi

    # ── Phase C: apply once ──
    info "[3/3] Applying theme (${variant})..."
    post_kwin_borders
    post_kwin_effects
    post_kwin_per_monitor_alt_tab
    post_kwin_alt_tab_switcher
    apply_lookandfeel "$theme" reset
    apply_kvantum_engine "$variant"
    # Let the layout script finish writing panels before restarting Plasma.
    sleep 1
    restart_plasmashell
    if [ "$UID" -ne 0 ]; then
        bash "$SRC_DIR/scripts/set-wallpaper.sh" || FAILED_COMPONENTS+=(wallpaper)
    fi

    # ── Phase D: behaviour (needs the new panel and a running shell) ──
    info "Windows shortcuts and apps..."
    install_component shortcuts
    install_component apps
    # Keep the user's KDE fonts; the optional fonts component is explicit opt-in.
    if [ "$UID" -ne 0 ] && [ -f "$NATIVE_ASSETS_DIR/manifest.json" ]; then
        install_component sounds
    fi

    echo ""
    info "Done! For the authentic Win11 look, enable floating:"
    echo -e "  ${BOLD}Right-click the panel → Show Panel Configuration →${RESET}"
    echo -e "  ${BOLD}Floating → Applets Only${RESET}"
    echo -e "  (Plasma's scripting API can't set this automatically.)"
    echo ""
    info "Press ${BOLD}Meta+L${RESET} to test the lock screen."
}

# ── Install all applets as a batch (menu 6) ─────────────────────────
install_all_applets() {
    if is_nixos; then
        nixos_full_install_unavailable
        return 1
    fi
    export WM_BATCH=1
    info "Installing all applets..."
    install_component showdesk
    install_component startmenu
    install_component systray
    install_component icontasks
    install_component digitalclock
    install_component taskbarbuttons
    unset WM_BATCH
    restart_plasmashell
}

# ── Interactive menu (grouped + sequential) ───────────────────────
# User-space preview: no system plugin, package-manager, shell override,
# shortcut replacement, greeter or layout reset.
install_preview() {
    if [ "$UID" -eq 0 ]; then
        err "Run preview as your desktop user, without sudo."
        return 1
    fi
    local variant="${1:-}"
    [ -n "$variant" ] || variant="$(ask_theme_variant)"
    export WM_BATCH=1
    local name
    for name in themes icons showdesk startmenu digitalclock taskbarbuttons alttab lookfeel; do
        install_component "$name"
    done
    if [ -f "$NATIVE_ASSETS_DIR/manifest.json" ]; then
        install_component sounds
    fi
    unset WM_BATCH
    if [ "${#FAILED_COMPONENTS[@]}" -ne 0 ]; then
        err "Preview staging failed: ${FAILED_COMPONENTS[*]}; global theme not applied."
        return 1
    fi
    # Deliberately omit --resetLayout; keep the user's existing panel.
    apply_lookandfeel "$(lookfeel_id "$variant")"
    apply_kvantum_engine "$variant"
    restart_plasmashell
    bash "$SRC_DIR/scripts/set-wallpaper.sh" || FAILED_COMPONENTS+=(wallpaper)
    info "Preview installed. Add Windows Modern Start, Search, Task View and Digital Clock through Add Widgets."
    warn "Existing tray and task manager remain in place; custom C++ plugins and login/lock overlay are outside preview."
}

menu() {
    echo ""
    echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${BLUE}║    Windows Modern — Unified Installer    ║${RESET}"
    echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  ${BOLD}Appearance${RESET}"
    echo -e "    ${BOLD}1${RESET})  Everything (themes + icons + applets + layout + shortcuts + apps)"
    echo -e "    ${BOLD}2${RESET})  Themes (Aurorae, colors, Kvantum, Plasma, wallpapers)"
    echo -e "    ${BOLD}3${RESET})  Icon pack"
    echo -e "    ${BOLD}4${RESET})  Global themes (look-and-feel)"
    echo -e "    ${BOLD}5${RESET})  Panel layout template"
    echo ""
    echo -e "  ${BOLD}Applets${RESET}"
    echo -e "    ${BOLD}6${RESET})  All applets"
    echo -e "    ${BOLD}7${RESET})  Show Desktop"
    echo -e "    ${BOLD}8${RESET})  Start Menu"
    echo -e "    ${BOLD}9${RESET})  System Tray (C++ — requires compiler)"
    echo -e "    ${BOLD}10${RESET}) Icon Tasks taskbar (C++ — requires compiler)"
    echo -e "    ${BOLD}11${RESET}) Digital Clock (QML)"
    echo -e "    ${BOLD}12${RESET}) Search and Task View buttons (optional: added from Add Widgets)"
    echo ""
    echo -e "  ${BOLD}Session${RESET}"
    echo -e "    ${BOLD}13${RESET}) Session lock screen (Meta+L)"
    echo -e "    ${BOLD}14${RESET}) Boot greeter / login screen (PLM — C++ build + system install)"
    echo -e "    ${BOLD}15${RESET}) Alt+Tab window switcher (Windows 11 style)"
    echo ""
    echo -e "  ${BOLD}Behaviour & setup${RESET}"
    echo -e "    ${BOLD}16${RESET}) Windows keyboard shortcuts (Win+Up/Down, Win+Tab, Win+R, Win+A...)"
    echo -e "    ${BOLD}17${RESET}) Apps: Haruna, KWrite, Mission Center, Snipping Tool behaviour"
    echo -e "    ${BOLD}18${RESET}) Dependencies only (Kvantum, Flatpak, C++ build tools)"
    echo -e "    ${BOLD}19${RESET}) Fonts: Segoe UI or Selawik, Cascadia Mono"
    echo ""
    echo -e "    ${BOLD}0${RESET})  Quit"
    echo ""
    read -r -p "  Choice [1]: " choice
    choice="${choice:-1}"
    echo ""

    case "$choice" in
        1)  install_everything ;;
        2)  install_component themes ;;
        3)  install_component icons ;;
        4)  install_component lookfeel ;;
        5)  install_component layout ;;
        6)  install_all_applets ;;
        7)  install_component showdesk ;;
        8)  install_component startmenu ;;
        9)  install_component systray ;;
        10) install_component icontasks ;;
        11) install_component digitalclock ;;
        12) install_component taskbarbuttons ;;
        13) install_component sessionlock ;;
        14) echo "Boot greeter install requires root for the system-wide step."
            echo "Building patched PLM first (user)..."
            install_component greeter
            echo ""
            echo "Now installing system-wide (needs sudo)..."
            sudo bash "$SCRIPT_DIR/scripts/install-greeter-live.sh" || err "System greeter install failed or was cancelled." ;;
        15) install_component alttab ;;
        16) install_component shortcuts ;;
        17) install_component apps ;;
        18) install_component deps ;;
        19) install_component fonts ;;
        0)  echo "Nothing installed."; exit 0 ;;
        *)  err "Invalid choice."; exit 1 ;;
    esac
}

# ── Parse CLI args ───────────────────────────────────────────────
# Extract --light/--dark flags from anywhere in the args.
variant_from_flag=""
args=()
for arg in "$@"; do
    case "$arg" in
        --light) variant_from_flag="light" ;;
        --dark)  variant_from_flag="dark" ;;
        *)       args+=("$arg") ;;
    esac
done
set -- "${args[@]}"

# Save the settings we may change before anything happens (issue #7):
# ./uninstall.sh --list-backups / --restore puts them back.
case "${1:-menu}" in
    --help|-h|deps) ;;
    *)
        if backup_id="$(snapshot_configs "install.sh ${*:-menu}")" && [ -n "$backup_id" ]; then
            info "Your current Plasma settings are saved as backup $backup_id (./uninstall.sh --list-backups)."
        fi
        ;;
esac

case "${1:-menu}" in
    --help|-h)
        echo "Usage: ./install.sh [component|all] [--light|--dark]"
        echo ""
        echo "  (no args)        Interactive menu (default = Everything)"
        echo "  all              Install everything (asks Light/Dark if interactive)"
        echo "  all --dark       Install everything non-interactively (Dark)"
        echo "  all --light      Install everything non-interactively (Light)"
        echo "  preview          User-space visual preview; preserve the existing panel"
        echo ""
        echo "  Components (install + apply immediately):"
        echo "    themes         Aurorae, colors, Kvantum, Plasma themes, wallpapers"
        echo "    wallpaper      Restore the imported original Windows 11 Bloom to all desktops"
        echo "    wallpaper --allow-fallback   Explicitly select the public substitute"
        echo "    translations   Install the Simplified Chinese applet catalogs"
        echo "    icons          Windows Modern icon pack"
        echo "    lookfeel       Global themes (asks Light/Dark)"
        echo "    layout         Panel layout template"
        echo "    showdesk       Show Desktop applet"
        echo "    startmenu      Start Menu applet"
        echo "    systray        System Tray (C++ — needs compiler)"
        echo "    icontasks      Icon Tasks taskbar (C++ — needs compiler)"
        echo "    digitalclock   Digital Clock (QML)"
        echo "    taskbarbuttons Search and Task View buttons (optional; add them from Add Widgets)"
        echo "    applets        All applets (the taskbar buttons are installed, not placed)"
        echo "    sessionlock    Session lock screen (Meta+L)"
        echo "    alttab         Windows 11-style Alt+Tab window switcher"
        echo "    shortcuts      Windows keyboard shortcuts (backs up and replaces some KDE keys)"
        echo "    apps           Haruna, KWrite, Mission Center; video default; Snipping Tool behaviour"
        echo "    deps           Kvantum, Flatpak and the C++ applets' build dependencies"
        echo "    fonts          Segoe UI (or open Selawik if missing) and Cascadia Mono"
        echo "    sounds         Local Windows sound theme (requires resource import)"
        echo "    transparency   on|off|refresh — Windows' Transparency effects switch (off: solid windows and popups)"
        echo "    greeter        Boot greeter / login screen (PLM build, user test)"
        echo ""
        echo "  Note: 'all' includes the session lock screen, Alt+Tab switcher, shortcuts and apps. The boot greeter is"
        echo "  opt-in (it replaces the system login manager) — use 'greeter'."
        echo ""
        exit 0
        ;;
    menu|"")
        menu
        ;;
    preview)
        install_preview "$variant_from_flag"
        ;;
    applets)
        install_all_applets
        ;;
    all)
        install_everything "$variant_from_flag"
        ;;
    greeter)
        install_component greeter
        ;;
    transparency)
        bash "$SCRIPT_DIR/scripts/install-transparency.sh" "${2:-}" || FAILED_COMPONENTS+=("transparency")
        ;;
    wallpaper)
        bash "$SCRIPT_DIR/scripts/set-wallpaper.sh" "${2:-}" || FAILED_COMPONENTS+=(wallpaper)
        ;;
    translations)
        python3 -I "$SRC_DIR/scripts/install-translations.py" || FAILED_COMPONENTS+=(translations)
        ;;
    *)
        install_component "$1"
        ;;
esac

echo ""
if [ "${#FAILED_COMPONENTS[@]}" -gt 0 ]; then
    err "Done, but these components failed: ${FAILED_COMPONENTS[*]} (see the messages above)."
    exit 1
fi
info "Done."
