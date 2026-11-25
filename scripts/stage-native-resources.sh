#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Fetch the compact, reviewed runtime tree, never the full reference branch.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
target="${1:?Usage: stage-native-resources.sh DESTINATION}"
pin=7046c2bd3a21bbe77b33876f8390540b80a72b4f
remote=https://github.com/YohakuSama/KDE-Windows-Modern.git
ref=refs/heads/resources/theme-runtime
cache="${XDG_CACHE_HOME:-$HOME/.cache}/windows-modern/runtime-resources/$pin"
[ ! -e "$target" ] && [ ! -L "$target" ] || { echo "Resource staging target already exists: $target" >&2; exit 1; }
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
verify_runtime() {
    python3 "$root/scripts/native_assets_index.py" "$root/scripts/native-assets-map.json" "$1" "$pin"
}
mkdir -p "$work/resources"
if [ -d "$cache" ] && verify_runtime "$cache"; then
    cp -a "$cache/." "$work/resources/"
else
    if git -C "$root" cat-file -e "$pin^{commit}" 2>/dev/null; then
        gitdir="$root"
    else
        git init --bare -q "$work/repo"
        git -C "$work/repo" fetch --depth=1 --no-tags "$remote" "$ref"
        [ "$(git -C "$work/repo" rev-parse FETCH_HEAD)" = "$pin" ] || {
            echo "Runtime resource branch changed; update the reviewed pin." >&2; exit 1;
        }
        gitdir="$work/repo"
    fi
    git -C "$gitdir" archive "$pin" | tar -xf - -C "$work/resources"
    printf '%s\n' "$pin" > "$work/resources/RESOURCE-COMMIT"
fi
verify_runtime "$work/resources"
# Best-effort, user-local immutable cache. Publish only a verified snapshot;
# never overwrite a pre-existing or user-modified directory.
if [ ! -e "$cache" ] && [ ! -L "$cache" ]; then
    if mkdir -p "$(dirname "$cache")" &&
        cache_tmp="$(mktemp -d "$(dirname "$cache")/.staging.XXXXXXXX")"; then
        if cp -a "$work/resources/." "$cache_tmp/"; then
            mv -T -n "$cache_tmp" "$cache" || true
        fi
        rm -rf -- "$cache_tmp"
    fi
fi
mkdir -p "$(dirname "$target")"
mv -T "$work/resources" "$target"
