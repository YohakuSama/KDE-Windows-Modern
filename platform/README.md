# Platform adapters / 平台适配

Canonical platform-bound source. Use existing native service interfaces
and version-specific adapters; do not replace the system backends.

| Directory | Ownership |
| --- | --- |
| plasma/systemtray/ | Native containment, D-Bus models, CMake and host |
| plasma/taskbar/ | Native tasks backend, launcher/tooltip and CMake |
| plasma/desktopmenu/ | Native containment action and CMake |
| plasma/appearance/ | Appearance generation, shell-session wallpaper monitoring, host accent control and mode switching |
| plasma/appearance/atlas/ | Single editable Plasma desktop theme SVG atlas and metadata |
| plasma/globaltheme/ | Global-theme metadata/defaults |
| plasma/login/ | Greeter host patch and private asset/color adapter |
| plasma/shortcuts/ | Shell-session shortcut routing and native shortcut/context-menu integration |
| plasma/app-appearance.py | Host application configuration adapter |
| qt/kvantum/ | Style templates and ABI-matched reload patch |
| nixos/ | Native transaction tools; [unique Nix expression locations](nixos/README.md) |

The [source map](../core/source-map.json) preserves native include,
package, Nix and Python paths during the migration. All mapped Plasma
native outputs, including C++ plugin sources and metadata, are generated
rather than tracked. The existing build and install entry points prepare
them before use. Edit global-theme metadata and Store dependency overrides
here, and review login-manager patches here. Run native tools from their
existing output paths; use --prepare before direct lower-level commands.
The Plasma atlas is materialized to its historic native location; both
renderer modes continue to use that generated native input. Frame and
switch generators write the editable atlas by default.
Mapped Qt style/patch and application configuration outputs are now
generated-only. The documented isolated Dolphin Nix command reads canonical
patches when the source map exists. The only editable Nix expressions
remain in [nix/](../nix/) to preserve their original relative inputs and
recipe identity. Independent scripts retain native entry paths through
validated relative source aliases; installation archives carry real files.
Source ownership does not itself remove runtime coupling.

The system tray binary initializes the shell-session appearance monitor and
shortcut router as children of the existing Corona. The monitor owns one
wallpaper D-Bus bridge, one watch set and one debounced asynchronous helper;
the router owns the unchanged Win+R/V action identities and targets the
ready primary tray (or a ready secondary tray). Destroying a representation
does not destroy these shell-session objects. With no ready tray, the
router uses the native KRunner/Klipper actions. No new process remains
resident outside plasmashell. A fresh shell session that never loads the
tray binary still cannot initialize these capabilities. Popup coordination
and split blur are optional panel-local capabilities and remain supplied
by the tray. Full lifecycle acceptance is still open.
