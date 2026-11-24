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

Update these categories after each substantive batch using the same rubric. Avoid claiming 1:1 visual parity until actual reference and runtime checks establish it.
