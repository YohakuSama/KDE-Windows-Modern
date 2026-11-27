# Shared core / 公共核心

Canonical editable shared sources. [source-map.json](source-map.json)
declares the generated native outputs, not a second implementation.

| Directory | Ownership |
| --- | --- |
| design/ | Shared popup, panel and lock-screen geometry |
| palette/ | Color classification, fixed roles, ICC/automatic accent and scheme template |
| materials/ | Window material and popup frame generation |
| controls/ | Shared glyphs, buttons, sliders, scrollbars and flyout controls |
| resources/ | Shared portrait/license and original resource import/validation |
| animations/ | Shared sign-in progress |
| logic/ | Shared formatting, battery state and lock-screen text |

Common QML/JS files retain their native filenames and relative imports.
Python tools are edited here but executed from their existing native paths
until staging is migrated. Do not create separate light/dark functionality.
Equal numeric values alone do not establish equal semantic roles.

Run `python3 -I scripts/materialize-modules.py --prepare` to generate
the ignored native files. For the remaining tracked native mirrors, use
`--write` after editing their canonical sources; `--check` compares bytes
and executable modes without writing.
The taskbar layout uses one shared body. The mapped Aurorae and Kvantum
source templates, color-scheme template and selected frame tools now
have generated-only native paths. The renderer-specific appearance
materializer prepares these inputs and generates the actual packages.
Window-frame regeneration without an explicit staged directory writes
modules/windowmanager/decoration/decoration.svg, the editable owner.
The Plasma SVG atlas and large icon/wallpaper inputs retain their current
ownership until their generators and consumers are migrated.

See [modules](../modules/README.md), [platform](../platform/README.md),
[packaging](../packaging/README.md) and the
[quality ledger](../docs/PROJECT_QUALITY_LEDGER.md).
