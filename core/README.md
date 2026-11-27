# Shared core / 公共核心

This is the editable source for the common files mapped in
[source-map.json](source-map.json). Each shared file has one owner.
Native package copies under plasma/ are generated, not a second source.

| Directory | Responsibility |
| --- | --- |
| design/ | Popup geometry and lock-screen metrics |
| palette/ | Common color classification |
| controls/ | Shared glyphs, buttons, scrollbars and sign-in controls |
| resources/ | Shared default portrait fallback resources |
| animations/ | Shared sign-in progress presentation |
| logic/ | Date formatting, battery state and lock-screen text |

Edit here for a shared behavior. Keep genuinely different host behavior in
the feature or platform code. The name of a shared file need not match its
native filename; the map preserves the native name and relative imports.
No QML runtime imports from this directory are introduced.

After edits run `python3 -I scripts/materialize-modules.py --write` from
the checkout, review the diff and use `--check` for read-only verification.
The generated native mirrors are temporary source-control compatibility
outputs. Installation packages continue to include only native consumers.
See [module sources](../modules/README.md) and the
[quality ledger](../docs/PROJECT_QUALITY_LEDGER.md).
