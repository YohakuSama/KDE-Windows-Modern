# Platform adapters / 平台适配

Canonical platform-bound source. Use existing native service interfaces
and version-specific adapters; do not replace the system backends.

| Directory | Ownership |
| --- | --- |
| plasma/systemtray/ | Native containment, D-Bus models, CMake and host |
| plasma/taskbar/ | Native tasks backend, launcher/tooltip and CMake |
| plasma/desktopmenu/ | Native containment action and CMake |
| plasma/appearance/ | Appearance generation, host accent control and mode switching |
| plasma/globaltheme/ | Global-theme metadata/defaults |
| plasma/login/ | Greeter host patch and private asset/color adapter |
| plasma/shortcuts/ | Native shortcut and context-menu integration |
| plasma/app-appearance.py | Host application configuration adapter |
| qt/kvantum/ | Style templates and ABI-matched reload patch |
| nixos/ | Native runtime derivations and transaction tools |

The [source map](../core/source-map.json) preserves native include,
package, Nix and Python paths during the migration. All mapped Plasma
native outputs, including C++ plugin sources and metadata, are generated
rather than tracked. The existing build and install entry points prepare
them before use. Edit global-theme metadata and Store dependency overrides
here, and review login-manager patches here. Run native tools from their
existing output paths; use --prepare before direct lower-level commands.
Nix expressions and other tracked script/renderer mirrors remain
transitional. Source ownership does not itself remove runtime coupling.
