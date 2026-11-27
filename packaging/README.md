# Packaging and installation / 安装与打包

Canonical source for conventional component installers, configuration
backup, asset staging, bundle preparation and verification. Use the
[source map](../core/source-map.json) to locate generated script outputs.
The root install/uninstall entry points retain their existing locations
during migration; NixOS runtime-specific implementation lives in
[platform/nixos](../platform/README.md).

Edit mapped scripts here, refresh tracked native mirrors using
`python3 -I scripts/materialize-modules.py --write`, and review the
complete diff. Execute scripts through their existing native paths, not
through this relocated source tree. Source installations prepare ignored
deployment outputs before consumption. Full install archives append
generated native files from the same Git commit as the base archive,
never from an untracked working-tree copy. Packaging excludes the
canonical development trees and keeps modules self-contained. Preserve
existing ABI, backup/rollback, permission and private-resource boundaries.
