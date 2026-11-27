# Packaging and installation / 安装与打包

Canonical source for conventional component installers, configuration
backup, asset staging, bundle preparation and verification. Use the
[source map](../core/source-map.json) to locate generated script outputs.
The root install/uninstall entry points retain their existing locations
during migration; NixOS runtime-specific implementation lives in
[platform/nixos](../platform/README.md).

Edit mapped scripts here, refresh native mirrors using
`python3 -I scripts/materialize-modules.py --write`, and review the
complete diff. Execute scripts through their existing native paths, not
through this relocated source tree. Packaging keeps installed modules
self-contained and excludes the canonical development trees. Keep the
existing ABI, backup/rollback, permission and private-resource boundaries.
