#! /usr/bin/env bash
# Upstream KDE i18n extraction script: $XGETTEXT and $podir are provided by
# KDE's translation tooling (scripty), and the word splitting is intended.
# Prepare generated sources before the KDE translation extractor scans them.
script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$script_dir/../../../core/source-map.json" ]; then
    python3 -I "$script_dir/../../../scripts/materialize-modules.py" --prepare || exit 1
fi
# shellcheck disable=SC2046,SC2006,SC2154,SC2086
$XGETTEXT `find . -name \*.js -o -name \*.qml -o -name \*.cpp` -o $podir/plasma_applet_org.kde.plasma.taskmanager.pot
