#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Materialize only the runtime inputs, not the 500 MB reference archive.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
target="${1:?Usage: stage-native-resources.sh DESTINATION}"
pin=272e06c87be0f548cebb2558392019b941df20d4
remote=https://github.com/YohakuSama/KDE-Windows-Modern.git
ref=refs/heads/resources/windows11
[ ! -e "$target" ] || { echo "Resource staging target already exists: $target" >&2; exit 1; }
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
if git -C "$root" cat-file -e "$pin^{commit}" 2>/dev/null; then
    gitdir="$root"
else
    # Fetch the owner's explicitly published, pinned resource revision.
    # Never use an unverified moving ref as the resource source.
    git init --bare -q "$work/repo"
    git -C "$work/repo" fetch --depth=1 "$remote" "$ref"
    [ "$(git -C "$work/repo" rev-parse FETCH_HEAD)" = "$pin" ] || {
        echo "Resource branch changed; update the reviewed resource pin." >&2; exit 1;
    }
    gitdir="$work/repo"
fi
mkdir -p "$work/resources"
git -C "$gitdir" archive "$pin" resource-manifest.json png \
    original/Windows/Web original/Windows/Media \
    original/Windows/SystemResources original/Windows/Fonts/SegoeIcons.ttf |
    tar -xf - -C "$work/resources"
for path in resource-manifest.json original/Windows/Web/Wallpaper/Windows/img0.jpg \
    original/Windows/Web/Wallpaper/Windows/img19.jpg original/Windows/Web/Screen/img100.jpg; do
    [ -s "$work/resources/$path" ] || { echo "Missing resource: $path" >&2; exit 1; }
done
printf '%s\n' "$pin" > "$work/resources/RESOURCE-COMMIT"
mkdir -p "$(dirname "$target")"
mv "$work/resources" "$target"
