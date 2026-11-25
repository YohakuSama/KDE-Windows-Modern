#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Build selected native plugins out of tree and verify their runtime links.
#
# Usage:
#   scripts/ci-build.sh [build-root] [systemtray,icontasks,contextmenu]
# Omitting the component list builds every native plugin.

set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ROOT="${1:-$(mktemp -d)}"
COMPONENTS="${2:-systemtray,icontasks,contextmenu}"
IFS=',' read -r -a TARGETS <<< "$COMPONENTS"

build_applet() {
    local applet="$1"
    local src="$SRC_DIR/plasma/applets/org.kde.windowsmodern.$applet"
    local build="$BUILD_ROOT/$applet"
    local so

    echo "==> Building $applet in $build"
    local options=()
    if [[ "$applet" == systemtray ]]; then
        options+=(-DWINDOWSMODERN_TEST_TRAY=ON)
    fi
    cmake -S "$src" -B "$build" -DCMAKE_BUILD_TYPE=Release "${options[@]}"
    cmake --build "$build" --parallel "$(nproc)"

    if [[ "$applet" == systemtray ]]; then
        ctest --test-dir "$build" --output-on-failure --no-tests=error
        so="$(find "$build" -path '*plasma/applets/org.kde.windowsmodern.systemtray.so' -print -quit)"
    else
        so="$(find "$build" -path '*plasma/applets/org.kde.plasma.icontasks.so' -print -quit)"
    fi
    if [[ -z "$so" ]]; then
        echo "ERROR: $applet produced no plugin .so" >&2
        return 1
    fi
    local unresolved
    unresolved="$(ldd -r "$so" 2>&1 | grep -E 'not found|undefined symbol' || true)"
    if [[ -n "$unresolved" ]]; then
        echo "ERROR: $so does not link cleanly:" >&2
        echo "$unresolved" >&2
        return 1
    fi
    echo "==> $applet OK: $so"
}

build_contextmenu() {
    local src="$SRC_DIR/plasma/containmentactions/org.kde.windowsmodern.contextmenu"
    local build="$BUILD_ROOT/contextmenu"
    local so="$build/lib/plasma/containmentactions/org.kde.windowsmodern.contextmenu.so"
    echo "==> Building contextmenu in $build"
    cmake -S "$src" -B "$build" -DCMAKE_BUILD_TYPE=Release -DWINDOWSMODERN_TEST_CONTEXTMENU=ON
    cmake --build "$build" --parallel "$(nproc)"
    ctest --test-dir "$build" --output-on-failure --no-tests=error
    if [[ ! -s "$so" ]]; then
        echo "ERROR: native desktop menu plugin not built" >&2
        return 1
    fi
    local unresolved
    unresolved="$(ldd -r "$so" 2>&1 | grep -E 'not found|undefined symbol' || true)"
    if [[ -n "$unresolved" ]]; then
        echo "$unresolved" >&2
        return 1
    fi
    echo "==> contextmenu OK: $so"
}

if [[ "${#TARGETS[@]}" -eq 0 ]]; then
    echo "ERROR: no native components selected" >&2
    exit 2
fi

for component in "${TARGETS[@]}"; do
    case "$component" in
        systemtray|icontasks) build_applet "$component" ;;
        contextmenu) build_contextmenu ;;
        *)
            echo "ERROR: unknown native component '$component'" >&2
            exit 2
            ;;
    esac
done
