# Packaging and installation / 安装与打包

Canonical source for conventional component installers, configuration
backup, asset staging, bundle preparation and verification. Use the
[source map](../core/source-map.json) to locate generated script outputs.
The root install/uninstall entry points retain their existing locations
during migration; NixOS runtime-specific implementation lives in
[platform/nixos](../platform/README.md).

Edit mapped scripts here and review the complete diff. Refresh generated
component installers with `python3 -I scripts/materialize-modules.py --prepare`;
use `--write` only for remaining tracked mirrors. A fresh checkout should
invoke the root install.sh component driver, which prepares native outputs
before invoking component scripts. Dependency installation, bootstrap and
recovery entry points remain available before generation. For direct
low-level invocation prepare first; execute scripts at their native paths,
not from this relocated source tree. Full install archives append
generated native files from the same Git commit as the base archive,
never from an untracked working-tree copy. Packaging excludes the
canonical development trees and keeps modules self-contained. Preserve
existing ABI, backup/rollback, permission and private-resource boundaries.
