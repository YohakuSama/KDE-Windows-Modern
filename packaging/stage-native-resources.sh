#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Resolve one verified pinned runtime cache, or copy it into a private ZIP.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
pin=7046c2bd3a21bbe77b33876f8390540b80a72b4f
remote=https://github.com/YohakuSama/KDE-Windows-Modern.git
ref=refs/heads/resources/theme-runtime
cache_base="${XDG_CACHE_HOME:-$HOME/.cache}/windows-modern/runtime-resources"
cache="$cache_base/$pin"
verify_runtime() {
    python3 "$root/scripts/native_assets_index.py" "$root/scripts/native-assets-map.json" "$1" "$pin" >&2
}
target="${1:?Usage: stage-native-resources.sh DESTINATION | --resolve | --verify DIRECTORY}"
if [ "$target" = --verify ]; then
    [ "$#" -eq 2 ] || exit 2
    verify_runtime "$2"
    exit
fi
[ "$#" -eq 1 ] || exit 2
if [ "$target" != --resolve ]; then
    [ ! -e "$target" ] && [ ! -L "$target" ] || { echo "Resource staging target already exists: $target" >&2; exit 1; }
fi
mkdir -p "$cache_base"
# Serialize repair of this exact pin. Keep the user-supplied library separate.
exec 9>"$cache_base/$pin.lock"
flock 9
if [ -L "$cache" ]; then
    echo "Refusing a symlink at the managed runtime cache: $cache" >&2
    exit 1
fi
if [ ! -d "$cache" ] || ! verify_runtime "$cache"; then
    if [ -e "$cache" ] && { [ ! -d "$cache" ] || [ ! -f "$cache/RESOURCE-COMMIT" ] ||
        [ "$(cat "$cache/RESOURCE-COMMIT")" != "$pin" ]; }; then
        echo "Refusing to replace an unrecognized cache path: $cache" >&2
        exit 1
    fi
    work="$(mktemp -d "$cache_base/.staging.XXXXXXXX")"
    # Restore the old cache if the final rename fails.
    cleanup() {
        if [ -d "$work/previous" ] && [ ! -e "$cache" ]; then
            mv -T "$work/previous" "$cache" || return
        fi
        rm -rf -- "$work"
    }
    trap cleanup EXIT
    if git -C "$root" cat-file -e "$pin^{commit}" 2>/dev/null; then
        gitdir="$root"
    else
        git init --bare -q "$work/repo"
        git -C "$work/repo" fetch --depth=1 --no-tags "$remote" "$ref" >&2
        [ "$(git -C "$work/repo" rev-parse FETCH_HEAD)" = "$pin" ] || {
            echo "Runtime resource branch changed; update the reviewed pin." >&2; exit 1;
        }
        gitdir="$work/repo"
    fi
    mkdir -p "$work/resources"
    git -C "$gitdir" archive "$pin" | tar -xf - -C "$work/resources"
    printf '%s\n' "$pin" > "$work/resources/RESOURCE-COMMIT"
    verify_runtime "$work/resources"
    if [ -d "$cache" ]; then mv -T "$cache" "$work/previous"; fi
    mv -T "$work/resources" "$cache"
fi
if [ "$target" = --resolve ]; then
    printf '%s\n' "$cache"
else
    mkdir -p "$(dirname "$target")"
    copy="$(mktemp -d "$(dirname "$target")/.runtime-copy.XXXXXXXX")"
    # The copy is only temporary staging for the ZIP, not another cache.
    if ! cp -a "$cache/." "$copy/" || ! verify_runtime "$copy" ||
        ! mv -T "$copy" "$target"; then
        rm -rf -- "$copy"
        exit 1
    fi
fi
