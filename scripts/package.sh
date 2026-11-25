#!/bin/bash
# ───────────────────────────────────────────────────────────────────
#  package.sh — build per-component ZIPs for KDE Store / GitHub release
#
#  Usage:
#    ./scripts/package.sh            # build all components
#    ./scripts/package.sh <name>...   # build specific components
#    ./scripts/package.sh --list      # list available components
#    ./scripts/package.sh --integration # integration bundle with local CI plugins
#    ./scripts/package.sh --owner       # private test bundle, source builds + native resources
#
#  Output: dist/WindowsModern-<component>-<version>.zip  (KDE Store items)
#          dist/KDE-Windows-Modern-<version>.zip         (full GitHub bundle)
#          dist/.manifest  — exact list of artifacts built by this run;
#                            scripts/release.sh uploads only these.
# ───────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$SRC_DIR/dist"
MANIFEST="$DIST_DIR/.manifest"

BOLD="\033[1m"; GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; CYAN="\033[36m"; RESET="\033[0m"
info()  { echo -e "${GREEN}==>${RESET} ${BOLD}$*${RESET}"; }
step()  { echo -e "${CYAN}  >>${RESET} $*"; }
warn()  { echo -e "${YELLOW}==>${RESET} $*"; }
err()   { echo -e "${RED}==>${RESET} $*" >&2; }

# Extract version from a metadata file (json or desktop).
get_version() {
    local meta="$1"
    if [[ "$meta" == *.json ]]; then
        python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['KPlugin'].get('Version',''))" "$meta" 2>/dev/null \
            || echo ""
    else
        grep -E '^(X-KDE-PluginInfo-)?Version=' "$meta" 2>/dev/null | head -1 | cut -d= -f2 || echo ""
    fi
}

# ── Component registry ─────────────────────────────────────────────
# name|source-dir|metadata-file|kde-store-category
# (category blank = GitHub-only)
#
# The C++ applets (systemtray, icontasks) are deliberately absent: they are
# compiled .so plugins, and installing them as a KPackage from the store
# produces the broken "dark rectangle" applet. They ship only in the full
# GitHub bundle, built on the user's machine by install.sh.
COMPONENTS=(
    "color-schemes|$SRC_DIR/color-schemes|colorschemes|Color Schemes"
    "icons|$SRC_DIR/icons/windows-modern|index.theme|Icons"
    "aurorae-dark|$SRC_DIR/aurorae/windows-modern-dark-aurorae|metadata.desktop|Aurorae Themes"
    "aurorae-light|$SRC_DIR/aurorae/windows-modern-light-aurorae|metadata.desktop|Aurorae Themes"
    "desktoptheme-dark|$SRC_DIR/plasma/desktoptheme/Windows-modern-dark|metadata.desktop|Plasma 6 Themes"
    "desktoptheme-light|$SRC_DIR/plasma/desktoptheme/Windows-modern-light|metadata.desktop|Plasma 6 Themes"
    "wallpaper|$SRC_DIR/wallpaper/Windows-modern|metadata.json|Wallpapers"
    "applet-showdesktop|$SRC_DIR/plasma/applets/org.kde.windowsmodern.showdesktop|metadata.json|Plasma 6 Applets"
    "applet-startmenu|$SRC_DIR/plasma/applets/org.kde.windowsmodern.startmenu|metadata.json|Plasma 6 Applets"
    "applet-digitalclock|$SRC_DIR/plasma/applets/org.kde.windowsmodern.digitalclock|metadata.json|Plasma 6 Applets"
    "applet-search|$SRC_DIR/plasma/applets/org.kde.windowsmodern.search|metadata.json|Plasma 6 Applets"
    "applet-taskview|$SRC_DIR/plasma/applets/org.kde.windowsmodern.taskview|metadata.json|Plasma 6 Applets"
    "windowswitcher|$SRC_DIR/plasma/windowswitcher/org.kde.windowsmodern.alttab|metadata.json|KWin Switching Layouts"
    "layout-panel|$SRC_DIR/plasma/layout-templates/org.kde.windowsmodern.panel|metadata.json|Plasma 6 Layout Templates"
    "lookfeel-dark|$SRC_DIR/plasma/look-and-feel/org.kde.windowsmodern.dark|metadata.json|Global Themes (Plasma 6)"
    "lookfeel-light|$SRC_DIR/plasma/look-and-feel/org.kde.windowsmodern.light|metadata.json|Global Themes (Plasma 6)"
)

list_components() {
    echo -e "${BOLD}Available components:${RESET}"
    for c in "${COMPONENTS[@]}"; do
        IFS='|' read -r name dir meta cat <<< "$c"
        printf "  %-22s %s\n" "$name" "${cat:-(GitHub only)}"
    done
}

# Build a single component into dist/
build_one() {
    local entry="$1"
    IFS='|' read -r name dir meta cat <<< "$entry"

    if [[ ! -d "$dir" ]]; then
        err "Source dir missing: $dir"
        return 1
    fi

    local version
    if [[ "$meta" == "index.theme" ]]; then
        version="$(get_version "$SRC_DIR/plasma/look-and-feel/org.kde.windowsmodern.dark/metadata.json")"
    elif [[ "$meta" == "colorschemes" ]]; then
        version="$(get_version "$SRC_DIR/plasma/look-and-feel/org.kde.windowsmodern.dark/metadata.json")"
    elif [[ -f "$dir/$meta" ]]; then
        version="$(get_version "$dir/$meta")"
    else
        version=""
    fi
    [[ -z "$version" ]] && version="1.0.0"

    local outname="WindowsModern-${name}-${version}.zip"
    local outpath="$DIST_DIR/$outname"

    rm -f "$outpath"
    if [[ "$name" == icons ]]; then
        # Build both icon modes from verified, unchanged source artwork.
        local icon_stage
        icon_stage="$(mktemp -d)"
        if ! (set -e
            cp -a "$dir" "$icon_stage/windows-modern"
            python3 "$SCRIPT_DIR/store-artwork.py" prepare "$DIST_DIR/.store-artwork" --bundled "$SRC_DIR/bundled-store-artwork"
            python3 "$SCRIPT_DIR/store-artwork.py" apply "$DIST_DIR/.store-artwork" "$icon_stage/windows-modern" "$icon_stage/windows-modern-light"
            cd "$icon_stage"
            zip -qr "$outpath" windows-modern windows-modern-light
        ); then
            rm -rf "$icon_stage" "$outpath"
            return 1
        fi
        rm -rf "$icon_stage"
    elif [[ "$meta" == "colorschemes" ]]; then
        # Discover unpacks color schemes straight into color-schemes/, so the
        # .colors files must sit at the top of the zip, not in a folder.
        (cd "$dir" && zip -q "$outpath" ./*.colors)
    else
        (cd "$(dirname "$dir")" && zip -qr "$outpath" "$(basename "$dir")" \
            -x '*/build/*' '*/build-*/*' '*/CMakeFiles/*' '*/dev.sh' '*/BUILD.md' '*.orig' '*.rej')
    fi
    step "built $outname  <-  $(basename "$dir")"
    echo "$outpath" >> "$MANIFEST"
}

# ── Main ────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--list" ]]; then
    list_components
    exit 0
fi

mkdir -p "$DIST_DIR"
OWNER=0
if [[ "${1:-}" == "--owner" ]]; then
    [[ $# -eq 1 ]] || { err "--owner cannot be combined with component names"; exit 1; }
    OWNER=1
    # Private test archives must never enter release.sh's public manifest.
    MANIFEST="$DIST_DIR/.owner-manifest"
fi
: > "$MANIFEST"

FULL_BUILD=1
INTEGRATION=0
if [[ "$OWNER" -eq 1 ]]; then
    FULL_BUILD=0
    info "Building private owner test bundle with original Windows resources..."
elif [[ "${1:-}" == "--integration" ]]; then
    [[ $# -eq 1 ]] || { err "--integration cannot be combined with component names"; exit 1; }
    INTEGRATION=1
    FULL_BUILD=0
    info "Building one integration bundle..."
elif [[ $# -gt 0 ]]; then
    FULL_BUILD=0
    info "Building selected components..."
    for want in "$@"; do
        found=""
        for c in "${COMPONENTS[@]}"; do
            IFS='|' read -r name _ _ _ <<< "$c"
            if [[ "$name" == "$want" ]]; then found="$c"; break; fi
        done
        if [[ -z "$found" ]]; then
            err "Unknown component: $want  (run with --list to see options)"
            exit 1
        fi
        build_one "$found"
    done
else
    info "Building all KDE Store components..."
    for c in "${COMPONENTS[@]}"; do
        build_one "$c"
    done
fi

# ── GitHub release bundle ──────────────────────────────────────────
# Built with `git archive` so the bundle contains exactly the committed
# tree — never untracked local files or build directories. Paths marked
# export-ignore in .gitattributes (screenshots, plans) are left out.
info "Building full GitHub release bundle..."
FULL_VER="$(get_version "$SRC_DIR/plasma/look-and-feel/org.kde.windowsmodern.dark/metadata.json")"
[[ -z "$FULL_VER" ]] && FULL_VER="1.0.0"
build_revision="$(git -C "$SRC_DIR" rev-parse HEAD)"
build_short="$(git -C "$SRC_DIR" rev-parse --short "$build_revision")"
FULL_OUT="$DIST_DIR/KDE-Windows-Modern-${FULL_VER}.zip"
if [[ "$INTEGRATION" -eq 1 ]]; then
    FULL_OUT="$DIST_DIR/KDE-Windows-Modern-${FULL_VER}-integration-$build_short.zip"
elif [[ "$OWNER" -eq 1 ]]; then
    FULL_OUT="$DIST_DIR/KDE-Windows-Modern-${FULL_VER}-owner-$build_short.zip"
fi
if [[ -n "$(git -C "$SRC_DIR" status --porcelain --untracked-files=no)" ]]; then
    if [[ "$OWNER" -eq 1 ]]; then
        err "Owner bundle requires a clean committed checkout."
        exit 1
    fi
    warn "Working tree has uncommitted changes — the full bundle is built from HEAD and will not include them."
fi
if [[ "$OWNER" -eq 1 ]]; then
    # Construct and verify on the same filesystem, then publish by rename.
    # A resource fetch, submodule or validation failure must never leave
    # a partial ZIP under a final owner filename.
    owner_out="$FULL_OUT"
    owner_work="$(mktemp -d "$DIST_DIR/.owner-build.XXXXXXXX")"
    trap 'rm -rf -- "$owner_work"' EXIT
    FULL_OUT="$owner_work/$(basename "$owner_out")"
fi
rm -f "$FULL_OUT"
archive_paths=(.)
if [[ "$OWNER" -eq 1 ]]; then
    # Keep the parallel theme-only package policy. The tests stay in Git.
    exclusions="$(python3 "$SCRIPT_DIR/verify-owner-bundle.py" --archive-excludes)"
    mapfile -t owner_excludes <<< "$exclusions"
    archive_paths+=("${owner_excludes[@]}")
fi
git -C "$SRC_DIR" archive --format=zip --prefix="KDE-Windows-Modern-${FULL_VER}/" \
    -o "$FULL_OUT" "$build_revision" -- "${archive_paths[@]}"
# `git archive` leaves submodules out, so the greeter could not be built
# from the bundle (#15). Add the login manager source at the commit HEAD pins.
PLM_REL="third_party/plasma-login-manager"
PLM_PIN="$(git -C "$SRC_DIR" ls-tree "$build_revision" "$PLM_REL" | awk '{print $3}')"
if [[ -n "$PLM_PIN" ]] && git -C "$SRC_DIR/$PLM_REL" cat-file -e "${PLM_PIN}^{commit}" 2>/dev/null; then
    if [[ "$OWNER" -eq 1 ]]; then
        PLM_ZIP="$owner_work/login-manager.zip"
    else
        PLM_ZIP="$(mktemp --suffix=.zip)"
    fi
    git -C "$SRC_DIR/$PLM_REL" archive --format=zip \
        --prefix="KDE-Windows-Modern-${FULL_VER}/${PLM_REL}/" -o "$PLM_ZIP" "$PLM_PIN"
    python3 -I - "$FULL_OUT" "$PLM_ZIP" <<'PYEOF'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "a", zipfile.ZIP_DEFLATED) as out, zipfile.ZipFile(sys.argv[2]) as plm:
    have = set(out.namelist())
    for info in plm.infolist():
        if info.filename not in have:
            out.writestr(info, plm.read(info))
PYEOF
    rm -f "$PLM_ZIP"
else
    if [[ "$INTEGRATION" -eq 1 || "$OWNER" -eq 1 ]]; then
        err "Test bundle requires the pinned login manager source."
        exit 1
    fi
    warn "Login manager source not available at the pinned commit — the bundle cannot build the greeter."
fi

if [[ "$INTEGRATION" -eq 1 ]]; then
    # Include the exact CI-built plugins and verified cursor artwork, not
    # an older release's binaries or the owner's private Windows archive.
    # shellcheck source=scripts/cursor-assets.sh
    source "$SCRIPT_DIR/cursor-assets.sh"
    plugins="${WM_BUNDLE_PLUGINS_DIR:?Set WM_BUNDLE_PLUGINS_DIR to the CI plugin directory}"
    [[ -f "$plugins/SHA256SUMS" ]] || { err "Missing CI plugin checksums"; exit 1; }
    (cd "$plugins" && sha256sum -c SHA256SUMS)
    stage="$(mktemp -d)"
    trap 'rm -rf "$stage"' EXIT
    prefix="KDE-Windows-Modern-${FULL_VER}"
    mkdir -p "$stage/$prefix/prebuilt" "$stage/$prefix/bundled-cursors"
    cp -a "$plugins/." "$stage/$prefix/prebuilt/"
    fetch_cursor_assets "$stage/$prefix/bundled-cursors/$CURSOR_THEME" || { err "Could not verify and stage cursor artwork"; exit 1; }
    git -C "$SRC_DIR" rev-parse HEAD > "$stage/$prefix/INTEGRATION-BUILD"
    # Preserve upstream cursor symlinks and zip the extra payload only.
    (cd "$stage" && zip -qry "$FULL_OUT" "$prefix/prebuilt" "$prefix/bundled-cursors" "$prefix/INTEGRATION-BUILD")
    rm -rf "$stage"
    trap - EXIT
fi
if [[ "$OWNER" -eq 1 ]]; then
    stage="$owner_work/stage"
    prefix="KDE-Windows-Modern-${FULL_VER}"
    mkdir -p "$stage/$prefix"
    bash "$SCRIPT_DIR/stage-native-resources.sh" "$stage/$prefix/native-resources"
    # A source-build test archive never tries to download stale release binaries.
    printf '%s\n' "$build_revision" > "$stage/$prefix/INTEGRATION-BUILD"
    (cd "$stage" && zip -qry "$FULL_OUT" "$prefix/native-resources" "$prefix/INTEGRATION-BUILD")
    rm -rf "$stage"
fi
# The full archive is self-contained for offline Store icon installation.
python3 "$SCRIPT_DIR/store-artwork.py" prepare "$DIST_DIR/.store-artwork" --bundled "$SRC_DIR/bundled-store-artwork"
if [[ "$OWNER" -eq 1 ]]; then
    store_stage="$owner_work/store"
else
    store_stage="$(mktemp -d)"
fi
mkdir -p "$store_stage/KDE-Windows-Modern-${FULL_VER}"
cp -a "$DIST_DIR/.store-artwork" "$store_stage/KDE-Windows-Modern-${FULL_VER}/bundled-store-artwork"
(cd "$store_stage" && zip -qry "$FULL_OUT" "KDE-Windows-Modern-${FULL_VER}/bundled-store-artwork")
rm -rf "$store_stage"
if [[ "$OWNER" -eq 1 ]]; then
    # Never report a stripped integration archive as a full owner package.
    if ! python3 "$SCRIPT_DIR/verify-owner-bundle.py" "$build_revision" "$FULL_OUT"; then
        rm -f "$FULL_OUT"
        err "Owner bundle failed completeness or 90 MB minimum-size verification."
        exit 1
    fi
fi
if [[ "$OWNER" -eq 0 ]]; then
    echo "$FULL_OUT" >> "$MANIFEST"
    step "built $(basename "$FULL_OUT")  (full bundle from ${build_revision:0:7})"
fi

# ── Prune stale artifacts ──────────────────────────────────────────
# Anything in dist/ a full run did not build (renamed/removed components,
# older versions) must not be published under a new tag. Partial runs
# leave other artifacts alone.
if [[ "$FULL_BUILD" -eq 1 ]]; then
    for stale in "$DIST_DIR"/*.zip; do
        [[ -e "$stale" ]] || continue
        [[ "$(basename "$stale")" != *-owner-*.zip ]] || continue
        if ! grep -qxF "$stale" "$MANIFEST"; then
            warn "Removing stale artifact: $(basename "$stale")"
            rm -f "$stale"
        fi
    done
fi

# ── Version consistency ────────────────────────────────────────────
# The release tag comes from the dark look-and-feel metadata; every
# component shipped under that tag must carry the same version.
VERSION_MISMATCH=0
for c in "${COMPONENTS[@]}"; do
    IFS='|' read -r name dir meta _ <<< "$c"
    [[ "$meta" == "index.theme" || "$meta" == "colorschemes" ]] && continue
    [[ -f "$dir/$meta" ]] || continue
    v="$(get_version "$dir/$meta")"
    if [[ "$v" != "$FULL_VER" ]]; then
        err "Version mismatch: $name is ${v:-<none>}, release is $FULL_VER ($dir/$meta)"
        VERSION_MISMATCH=1
    fi
done
if [[ "$VERSION_MISMATCH" -ne 0 ]]; then
    err "Bump the component metadata (or the look-and-feel Version) so they agree, then re-run."
    exit 1
fi

if [[ "$OWNER" -eq 1 ]]; then
    if [[ "$(git -C "$SRC_DIR" rev-parse HEAD)" != "$build_revision" ||
          -n "$(git -C "$SRC_DIR" status --porcelain --untracked-files=no)" ]]; then
        err "Checkout changed during owner package build; no ZIP published."
        exit 1
    fi
    mv -f -- "$FULL_OUT" "$owner_out"
    echo "$owner_out" >> "$MANIFEST"
    step "built $(basename "$owner_out")  (full bundle from ${build_revision:0:7})"
fi

echo ""
info "Done. Artifacts in ${DIST_DIR}:"
sed "s|^$DIST_DIR/|    |" "$MANIFEST"
