#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Use Qt's parser without editing any source or requiring a Plasma session.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Parse the self-contained native packages only after verifying their sources.
python3 -I "$ROOT/scripts/materialize-modules.py" --check
tool=""
for candidate in /usr/lib64/qt6/bin/qmlformat /usr/lib/qt6/bin/qmlformat qmlformat6 qmlformat; do
    if command -v "$candidate" >/dev/null 2>&1; then tool="$candidate"; break; fi
done
[ -n "$tool" ] || { echo "Qt 6 qmlformat is missing" >&2; exit 1; }
count=0
failed=0
while IFS= read -r -d '' file; do
    count=$((count+1))
    if ! "$tool" --ignore-settings "$file" >/dev/null; then
        echo "QML parser failed: $file" >&2
        failed=1
    fi
done < <(find "$ROOT/plasma" "$ROOT/tests" -type f -name '*.qml' -print0)
echo "Parsed $count QML files"
[ "$count" -gt 0 ] && [ "$failed" -eq 0 ]
