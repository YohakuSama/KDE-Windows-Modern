#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Shared by the installer and integration packager. Cursor artwork only;
# no upstream installer or executable is run.
# shellcheck disable=SC2034
CURSOR_THEME="Bibata-Modern-Ice"
CURSOR_URL="https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata.tar.xz"
# FreeBSD ports: x11-themes/bibata-cursor-theme/distinfo (2.0.7).
CURSOR_SHA256="172e33c4ae415278384dcecc7d1a9b7a024266bc944bc751fd86532be1cc6251"

cursor_assets_valid() {
    [ -f "$1/index.theme" ] && [ -f "$1/cursors/left_ptr" ] &&
        [ -f "$1/cursors/xterm" ] && [ -f "$1/cursors/watch" ]
}

# Download the pinned upstream archive, extract just the chosen theme,
# and publish it only after the complete download and checksum succeed.
fetch_cursor_assets() (
    local destination="$1" tmp
    [ ! -e "$destination" ] || return 1
    tmp="$(mktemp -d)" || return 1
    trap 'rm -rf "$tmp"' EXIT
    curl -fsSL --retry 2 --connect-timeout 10 --max-time 180 -o "$tmp/c.tar.xz" "$CURSOR_URL" || return 1
    echo "$CURSOR_SHA256  $tmp/c.tar.xz" | sha256sum -c --status || return 1
    tar -xJf "$tmp/c.tar.xz" -C "$tmp" --no-same-owner --no-same-permissions \
        --wildcards '*/Bibata-Modern-Ice/*' 2>/dev/null ||
        tar -xJf "$tmp/c.tar.xz" -C "$tmp" --no-same-owner --no-same-permissions \
            --wildcards 'Bibata-Modern-Ice/*' || return 1
    cursor_assets_valid "$tmp/$CURSOR_THEME" || return 1
    mkdir -p "$(dirname "$destination")" || return 1
    mv "$tmp/$CURSOR_THEME" "$destination"
)
