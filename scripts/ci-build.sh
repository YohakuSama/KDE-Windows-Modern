#!/bin/bash
# ───────────────────────────────────────────────────────────────────
#  ci-build.sh — compile both C++ applets out of tree and check that the
#  resulting plugins resolve every symbol against the installed Plasma.
#
#  Catches the most common breakage: a Plasma/KF6 update that changes an
#  API or bumps a library soname. Installs nothing and needs no session.
#
#  Usage:  ./scripts/ci-build.sh [build-root]   (default: a temp dir)
# ───────────────────────────────────────────────────────────────────
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ROOT="${1:-$(mktemp -d)}"
FAILED=0

for applet in systemtray icontasks; do
    src="$SRC_DIR/plasma/applets/org.kde.windowsmodern.$applet"
    build="$BUILD_ROOT/$applet"
    echo "==> Building $applet in $build"
    options=()
    if [[ "$applet" == systemtray ]]; then
        options+=(-DWINDOWSMODERN_TEST_TRAY=ON)
    fi
    cmake -S "$src" -B "$build" -DCMAKE_BUILD_TYPE=Release "${options[@]}"
    cmake --build "$build" --parallel "$(nproc)"

    if [[ "$applet" == systemtray ]]; then
        ctest --test-dir "$build" --output-on-failure --no-tests=error
    fi
    so="$(find "$build" -path '*plasma/applets/*.so' -print -quit)"
    if [ -z "$so" ]; then
        echo "ERROR: $applet produced no plugin .so" >&2
        FAILED=1
        continue
    fi
    unresolved="$(ldd -r "$so" 2>&1 | grep -E 'not found|undefined symbol' || true)"
    if [ -n "$unresolved" ]; then
        echo "ERROR: $so does not link cleanly:" >&2
        echo "$unresolved" >&2
        FAILED=1
    else
        echo "==> $applet OK: $so"
    fi
done

menu_src="$SRC_DIR/plasma/containmentactions/org.kde.windowsmodern.contextmenu"
menu_build="$BUILD_ROOT/contextmenu"
cmake -S "$menu_src" -B "$menu_build" -DCMAKE_BUILD_TYPE=Release -DWINDOWSMODERN_TEST_CONTEXTMENU=ON
cmake --build "$menu_build" --parallel "$(nproc)"
ctest --test-dir "$menu_build" --output-on-failure --no-tests=error
menu_so="$menu_build/lib/plasma/containmentactions/org.kde.windowsmodern.contextmenu.so"
if [ ! -s "$menu_so" ]; then
    echo "ERROR: native desktop menu plugin not built" >&2
    FAILED=1
else
    unresolved="$(ldd -r "$menu_so" 2>&1 | grep -E 'not found|undefined symbol' || true)"
    if [ -n "$unresolved" ]; then
        echo "$unresolved" >&2
        FAILED=1
    fi
fi

exit "$FAILED"
