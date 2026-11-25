#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
data="${XDG_DATA_HOME:-$HOME/.local/share}/windows-modern"
output="${WM_NATIVE_ASSETS_DIR:-$data/native-assets}"
source="${WM_NATIVE_RESOURCE_SOURCE:-}"
[ "$EUID" -ne 0 ] || { echo "Import resources as the desktop user." >&2; exit 1; }
if [ -z "$source" ] && [ -f "$root/native-resources/resource-manifest.json" ]; then
    source="$root/native-resources"
fi
if [ -z "$source" ] && [ -f "$data/resource-input/resource-manifest.json" ]; then
    source="$data/resource-input"
fi
verify_output() {
    python3 "$root/scripts/check-native-icon-import.py" "$output" "$root/scripts/native-assets-map.json" &&
        python3 "$root/scripts/check-native-wallpaper.py" "$output" "$output/wallpapers/Windows-modern" Windows-modern &&
        python3 "$root/scripts/check-native-wallpaper.py" "$output" "$output/wallpapers/Windows-modern-lock" Windows-modern-lock
}
if [ -f "$output/manifest.json" ] && [ -z "${WM_NATIVE_RESOURCE_SOURCE:-}" ]; then
    if verify_output; then
        exit 0
    fi
    if [ -z "$source" ] && python3 "$root/scripts/import-windows-assets.py" --reuse --output "$output" && verify_output; then
        exit 0
    fi
fi
if [ -z "$source" ]; then
    bash "$root/scripts/stage-native-resources.sh" "$data/resource-input"
    source="$data/resource-input"
fi
python3 "$root/scripts/import-windows-assets.py" "$source" --output "$output"
verify_output
