#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Explicit, isolated NixOS trial of the optional Konsole titlebar plugin.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/windows-modern/konsole-chrome"

fail() { printf '%s\n' "$*" >&2; exit 1; }
usage() {
    printf '%s\n' 'Usage: scripts/konsole-chrome.sh build | run [Konsole arguments] | remove' \
        'Optional build override: WM_KONSOLE_NIXPKGS=/absolute/path/to/nixpkgs'
}

[ "$EUID" -ne 0 ] || fail 'Run as the desktop user, not root.'
action="${1:-}"
case "$action" in
    -h|--help) usage; exit 0 ;;
    build|run|remove) shift ;;
    *) usage >&2; exit 2 ;;
esac
if [ "$action" != run ] && [ "$#" -ne 0 ]; then
    usage >&2
    exit 2
fi

# Only manage this dedicated directory. Never delete an unrelated directory
# or write through an externally managed state symlink.
if [ ! -d "$STATE" ]; then
    [ "$action" = build ] || { [ "$action" = remove ] && exit 0; fail 'Build the optional package first.'; }
    [ ! -e "$STATE" ] && [ ! -L "$STATE" ] && [ ! -L "$(dirname "$STATE")" ] \
        || fail 'Refusing an externally managed state path.'
    mkdir -p -- "$(dirname "$STATE")"
    mkdir -m 700 -- "$STATE"
    touch "$STATE/owned-state"
fi
[ ! -L "$STATE" ] && [ ! -L "$(dirname "$STATE")" ] \
    && [ -f "$STATE/owned-state" ] && [ ! -L "$STATE/owned-state" ] \
    || fail 'Refusing an unrecognized state directory.'
[ ! -L "$STATE/lock" ] || fail 'Refusing an externally managed lock.'
exec 9>"$STATE/lock"
flock 9
for path in "$STATE/manifest"; do
    [ ! -L "$path" ] || fail 'Refusing an externally managed manifest.'
done
[ ! -e "$STATE/result" ] || [ -L "$STATE/result" ] \
    || fail 'Refusing to replace an unrelated result path.'

if [ "$action" = remove ]; then
    rm -f -- "$STATE/result" "$STATE/manifest"
    printf '%s\n' 'Optional build link removed. Stock Konsole and its settings are unchanged.'
    exit 0
fi

command -v konsole >/dev/null || fail 'Stock Konsole is not installed.'
version="$(LC_ALL=C konsole --version | sed -n 's/^konsole \([0-9][0-9.]*\)$/\1/p')"
[[ "$version" =~ ^26\.08\.[0-9]+$ ]] || fail "Unsupported Konsole version: ${version:-unknown}. This source targets 26.08.x."
source_identity() {
    (cd "$ROOT" && {
        find app-decorations/konsole -maxdepth 1 -type f -print0 | sort -z | xargs -0 -r sha256sum
        sha256sum nix/konsole-chrome.nix
    }) | sha256sum | cut -d' ' -f1
}
identity="$(source_identity)"

if [ "$action" = build ]; then
    command -v nix-build >/dev/null || fail 'Nix is not available.'
    nixpkgs="${WM_KONSOLE_NIXPKGS:-}"
    if [ -z "$nixpkgs" ]; then
        command -v nixos-version >/dev/null || fail 'Supply WM_KONSOLE_NIXPKGS for the matching package set.'
        revision="$(nixos-version --json | sed -n 's/.*"nixpkgsRevision"[[:space:]]*:[[:space:]]*"\([0-9a-f]\{40\}\)".*/\1/p')"
        [ -n "$revision" ] || fail 'Cannot identify the running nixpkgs revision. Set WM_KONSOLE_NIXPKGS explicitly.'
        nixpkgs="$(nix --extra-experimental-features 'nix-command flakes' eval --raw --impure \
            --expr "(builtins.getFlake \"github:NixOS/nixpkgs/$revision\").outPath")"
    fi
    [[ "$nixpkgs" = /* && -d "$nixpkgs" ]] || fail 'WM_KONSOLE_NIXPKGS must be an absolute nixpkgs directory.'
    nix-build "$ROOT/nix/konsole-chrome.nix" --argstr nixpkgsPath "$nixpkgs" \
        --argstr konsoleVersion "$version" --out-link "$STATE/result"
    [ "$identity" = "$(source_identity)" ] || fail 'Source changed during the build. Build again.'
    result="$(readlink -f -- "$STATE/result")"
    [ -x "$result/bin/konsole" ] || fail 'The build did not produce Konsole.'
    temporary="$(mktemp "$STATE/manifest.XXXXXXXX")"
    printf '%s\n%s\n%s\n' "$version" "$identity" "$result" > "$temporary"
    mv -T -- "$temporary" "$STATE/manifest"
    printf '%s\n' 'Build complete. Start with scripts/konsole-chrome.sh run.'
    exit 0
fi

[ -L "$STATE/result" ] && [ -f "$STATE/manifest" ] || fail 'Build the optional package first.'
mapfile -t recorded < "$STATE/manifest"
result="$(readlink -f -- "$STATE/result")"
[ "${#recorded[@]}" -eq 3 ] && [ "${recorded[0]}" = "$version" ] \
    && [ "${recorded[1]}" = "$identity" ] && [ "${recorded[2]}" = "$result" ] \
    && [[ "$result" = /nix/store/* ]] && [ -x "$result/bin/konsole" ] \
    || fail 'The optional build is stale or invalid. Run the build action again.'
# Do not hold the build lock for the duration of the terminal session.
flock -u 9
exec 9>&-
export WM_KONSOLE_CHROME=1
exec "$result/bin/konsole" --separate --hide-menubar --hide-toolbars --show-tabbar "$@"
