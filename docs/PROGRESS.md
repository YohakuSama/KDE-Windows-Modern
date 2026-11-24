# Windows 11 fidelity progress

Target: Windows 11 26H2 GA, with KDE/Qt-native implementations where Windows APIs are unavailable. Use the system text font and a single icon theme. Keep original user-supplied Windows resources local.

This is a development-stage estimate, not a pixel-match score or test-pass rate. Ten categories have equal weight. Each is scored 0 (not started), 25 (reviewed/scoped), 50 (partly implemented), 75 (substantial implementation, awaiting full reference/runtime acceptance), or 100 (reference comparison and live acceptance completed). Do not award 100 solely for a static check.

| Area | Stage | Remaining acceptance work |
|---|---:|---|
| Start menu | 75% | Category view, account actions, keyboard and layout checks |
| Taskbar / system tray | 75% | Status variants, multi-monitor and hover behavior |
| Quick Settings | 75% | Tile ordering, device-specific states and layout checks |
| Notification center / calendar | 75% | Grouping, replies, toast appearance and runtime behavior |
| Icon system | 75% | Remaining state coverage, KDE-specific SVGs and visual checks |
| Typography | 75% | Confirm system font inheritance, sizing and localization |
| Installer / maintainability | 75% | Clean install, upgrade, rollback and Plasma version checks |
| Materials | 50% | Compositor calibration, real Mica where feasible, fallback behavior |
| Wallpapers / lock / login | 50% | Greeter integration and actual lock/login display |
| Window chrome / Alt-Tab / OSD / motion | 50% | Reference-based appearance and compositor-safe rounding/animation |

Overall development estimate: **67.5% (rounded to 68%)** as of this batch. Live acceptance remains pending.

## Batch validation

- Generated all 12 dark/light dialog and tooltip frames and checked exact generated Git blob hashes; offline SVG rendering, radius, seam and alpha checks passed.
- Verified manual DND state transitions independently from app and mirror inhibition using JavaScript assertions.
- Ran the current resource importer and map against the supplied archive. Produced 389 valid SVG icon paths with 188 distinct content hashes, 22 unique wallpapers, and 20 sound events. Importer and map hashes matched the committed versions.
- Full Plasma/QML compilation, CI, installed desktop comparison and runtime checks were not available in this environment. Main integration is not a stable release.
- Acrylic tint opacity is an approximation; the generated frames do not implement Windows DWM Mica or its noise shader.

## Resource input follow-up (draft integration)

- Added ZIP/TAR/extracted-directory input validation and original resource SHA-256/size provenance in the local manifest. All 12 synthetic source-reader regression tests passed locally; CI now runs them independently of proprietary assets.
- The owner subsequently attached the actual 273,203,214-byte archive. Verified 467 files and 711 icon groups in three MUN libraries; the font identifies itself as Segoe Fluent Icons 1.56 with 2,036 cmap entries. The exact committed input reader successfully read all 45 selected source files; all selected JPEGs and WAVs passed format checks.
- Add 18 mapped paths (407 total) for the live microphone, keyboard, touchpad, night light, menu, lock and volume roles. The offline reproduction of the icon-generation functions produced valid SVG for all mapped sources (193 distinct contents); all ten touched glyphs rendered nonempty at 48 px. The map has no duplicate target paths. The battery saver tile uses its actual power-saving role. This check did not execute the entire importer CLI from a checkout.
- DNS prevented a local clone. Full repository health, C++/QML compilation, CI results and live desktop acceptance remain unverified.
- The 67.5% development estimate is unchanged: this batch improves reproducibility and input handling, not visual acceptance stages.

## Lock and login appearance follow-up (draft integration)

- Align the existing unlock and login fields at 36 logical pixels, with 4 px corners, subdued borders and a 2 px focus accent. Preserve all native authentication, keyboard and user selection paths. The styling is a Windows 11 approximation pending reference comparison.
- Standalone session-lock installation selects the installed native lock wallpaper without changing the desktop. If the native package is absent it leaves the lock wallpaper alone. The owner archive contains the verified 3840 x 2160 JPEG used by this package.
- The exact wallpaper script passed bash syntax and five mocked command scenarios (standalone with/without native package, full apply with/without lock package, missing desktop package). QML review was static only; no live lock, login, full CI or system greeter installation was exercised. The privileged boot greeter install remains unchanged. Keep the 67.5% estimate pending substantive acceptance.

Update these categories after each substantive batch using the same rubric. Avoid claiming 1:1 visual parity until actual reference and runtime checks establish it.
