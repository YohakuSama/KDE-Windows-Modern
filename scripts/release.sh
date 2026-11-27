#!/bin/bash
# ───────────────────────────────────────────────────────────────────
#  release.sh — tag, package, and publish a GitHub release
#
#  Usage:
#    ./scripts/release.sh             # version auto-detected from metadata
#    ./scripts/release.sh 1.0.0        # explicit version
#    ./scripts/release.sh --dry-run   # verify + package, no tag/push
#
#  Prerequisites:
#    - gh CLI installed and authenticated
#    - clean working tree on main
# ───────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_SLUG="YohakuSama/KDE-Windows-Modern"

BOLD="\033[1m"; GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; CYAN="\033[36m"; RESET="\033[0m"
info()  { echo -e "${GREEN}==>${RESET} ${BOLD}$*${RESET}"; }
step()  { echo -e "${CYAN}  >>${RESET} $*"; }
warn()  { echo -e "${YELLOW}==>${RESET} $*"; }
err()   { echo -e "${RED}==>${RESET} $*" >&2; }

cd "$SRC_DIR"

# ── Resolve version ────────────────────────────────────────────────
VERSION=""
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help)
            sed -n '3,12p' "$0"; exit 0 ;;
        *) VERSION="$arg" ;;
    esac
done

META_VERSION="$(python3 -c "import json;print(json.load(open('platform/plasma/globaltheme/metadata.json'))['KPlugin']['Version'])" 2>/dev/null || true)"
if [[ -z "$VERSION" ]]; then
    VERSION="$META_VERSION"
fi
[[ -z "$VERSION" ]] && { err "Could not determine version."; exit 1; }
# Artifact names come from the metadata, so a tag that disagrees would ship
# zips labelled with a different version than the release.
if [[ "$VERSION" != "$META_VERSION" ]]; then
    err "Requested version $VERSION does not match metadata version ${META_VERSION:-<none>}."
    err "Bump the Version fields in the metadata files first (see docs/RELEASE.md)."
    exit 1
fi
TAG="v${VERSION}"
info "Release version: ${TAG}"

# ── 1. Pre-flight checks ───────────────────────────────────────────
info "Pre-flight checks..."

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "main" ]]; then
    err "Not on main (currently on $BRANCH). Switch first."
    exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
    err "Working tree is dirty. Commit or stash first."
    git status --short
    exit 1
fi
step "working tree clean"

if ! command -v gh &>/dev/null; then
    err "gh CLI not found. Install: https://cli.github.com"
    exit 1
fi
step "gh CLI present"

if ! gh auth status >/dev/null 2>&1; then
    err "Not logged into GitHub. Run: gh auth login"
    exit 1
fi
step "gh authenticated"

info "Running project health check..."
if ! ./verify-all.sh >/dev/null 2>&1; then
    err "verify-all.sh failed. Fix issues before releasing."
    ./verify-all.sh
    exit 1
fi
step "verify-all.sh passed"

# ── 2. Package artifacts ───────────────────────────────────────────
info "Packaging artifacts..."
./scripts/package.sh >/dev/null
step "$(wc -l < dist/.manifest) artifacts built in dist/"

# ── 3. Dry-run stop ────────────────────────────────────────────────
if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "Dry run — stopping before tag/push."
    echo -e "  Artifacts ready: ${BOLD}dist/${RESET}"
    exit 0
fi

# ── 4. Verify the configured destination ───────────────────────────
# Never create another repository or rewrite the maintainer's Git remotes.
# Reject a checkout pointing at upstream or multiple push destinations.
origin_url="$(git remote get-url --push --all origin)" || { err "Configure origin for $REPO_SLUG."; exit 1; }
case "$origin_url" in
    "https://github.com/$REPO_SLUG"|"https://github.com/$REPO_SLUG.git"|"git@github.com:$REPO_SLUG"|"git@github.com:$REPO_SLUG.git"|"ssh://git@github.com/$REPO_SLUG"|"ssh://git@github.com/$REPO_SLUG.git") ;;
    *) err "origin push URL does not match $REPO_SLUG."; exit 1 ;;
esac
step "release destination verified"

# ── 5. Tag (reuse if already created locally) ──────────────────────
if git rev-parse "$TAG" >/dev/null 2>&1; then
    warn "Tag ${TAG} already exists locally — reusing."
else
    info "Creating tag ${TAG}..."
    git tag -a "$TAG" -m "Windows Modern for KDE Plasma 6 — release ${TAG}"
fi
step "tag ${TAG} ready"

# ── 6. Push tag ────────────────────────────────────────────────────
info "Pushing tag..."
git push origin "$TAG"
step "tag pushed"

# ── 7. Create GitHub release (idempotent) ─────────────────────────
info "Creating GitHub release..."
# This version's section of CHANGELOG.md, without its heading.
CHANGES="$(awk -v v="$VERSION" '
    index($0, "## [" v "]") == 1 { on = 1; next }
    on && index($0, "## [") == 1 { exit }
    on { print }' CHANGELOG.md)"

NOTES="$(cat <<EOF
Windows 11-style desktop theme and shell components for KDE Plasma 6:
Start, Search, taskbar, Quick Settings, notifications, window decorations,
icons, shortcuts and Snap Layouts.

### Install

Extract the public theme ZIP (or clone the \`${TAG}\` tag) and run
\`bash install.sh\` as the desktop user. On NixOS select 1 for first install,
2 for upgrade or 3 to restore. The installer builds native plugins for the
running Plasma ABI where matching binaries are unavailable.

This public archive does not contain the owner's original Windows resource
payload. See README.md and docs/NATIVE_ASSETS.md for local resource imports
and the distinct private owner package. No private resource ZIP is uploaded
by this release script.

### Changes

${CHANGES:-See CHANGELOG.md.}
EOF
)"

if gh release view "$TAG" --repo "$REPO_SLUG" >/dev/null 2>&1; then
    warn "Release ${TAG} already exists on GitHub — uploading artifacts only."
else
    gh release create "$TAG" \
        --repo "$REPO_SLUG" \
        --title "Windows Modern ${TAG}" \
        --notes "$NOTES"
fi

# Attach exactly the artifacts package.sh built in step 2 — never a glob,
# so stale zips left in dist/ cannot ship under a new tag.
if [[ ! -s dist/.manifest ]]; then
    err "dist/.manifest missing or empty — packaging did not run."
    exit 1
fi
mapfile -t ARTIFACTS < dist/.manifest
info "Uploading ${#ARTIFACTS[@]} artifact(s)..."
gh release upload "$TAG" \
    --repo "$REPO_SLUG" \
    --clobber \
    "${ARTIFACTS[@]}"

echo ""
info "Release ${TAG} published: https://github.com/${REPO_SLUG}/releases/tag/${TAG}"
echo -e "  ${BOLD}Next:${RESET} publish components to KDE Store — see docs/RELEASE.md"
