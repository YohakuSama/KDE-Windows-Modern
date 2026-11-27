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
package, Nix and Python paths during the migration. Run native tools at
their existing output paths until staging is complete. This is a source
ownership boundary, not proof that all runtime dependencies are gone.
