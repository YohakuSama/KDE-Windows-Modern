# Windows 11 fidelity progress

Target: Windows 11 26H2 GA, with KDE/Qt-native implementations where Windows APIs are unavailable. Use the system text font and a single icon theme. Keep original user-supplied Windows resources local.

This is a development-stage estimate, not a pixel-match score or test-pass rate. Ten categories have equal weight. Each is scored 0 (not started), 25 (reviewed/scoped), 50 (partly implemented), 75 (substantial implementation, awaiting full reference/runtime acceptance), or 100 (reference comparison and live acceptance completed). Do not award 100 solely for a static check.

| Area | Stage | Remaining acceptance work |
|---|---:|---|
| Start menu | 75% | Category view, account/power popup and keyboard live acceptance, layout checks |
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

## Start footer and keyboard follow-up (draft integration)

- Reuse the in-dialog popup for the account menu (settings, lock, switch user and sign out) and the power menu (sleep, shut down and restart). Keep KDE SessionManagement capability checks and existing native actions. No additional backend or account service.
- Restore focus to the opening button on dismissal; skip unavailable actions during keyboard navigation and prevent popup keys from entering Start search. Fix the search filter's stale reference to the old search field and return focus through an explicit signal. Empty pinned sections fall back to the All list, and Tab/Enter work through the existing views.
- The exact footer-navigation JavaScript helper passed ten targeted Node assertions and exhaustive enabled-row invariant checks for up to eight options. Added the same ten cases to the existing Qt test suite. The Qt tests, repository health checks, QML build and live Start interaction/visual acceptance could not be run here (Qt tools absent and GitHub DNS unavailable in the local environment).
- The 67.5% development-stage estimate remains unchanged until the existing categories pass their acceptance gates; no new feature scope or release claim.

## Pre-release scope freeze and phase completion branch

Owner decision: finish the three development phases (core desktop interactions,
visual fidelity, shared details) before merging the next integration into main.
Then do live acceptance and narrowly scoped fixes before tagging a stable
release. Do not add unrelated features or dependencies.

This batch starts that combined integration branch from the merged PR #6.

- Core: optional All/Categories navigation uses KDE's existing AppsModel
  (API checked against Plasma 6.7 and 6.8.2); no app classification database.
  Notification history uses native flat application grouping with one initial
  child, expand/collapse, and persistent model indexes for clear-all.
  Quick Settings distinguishes absent Wi-Fi and Bluetooth adapters, leaves
  the detail route available, and exposes keyboard/accessibility actions.
  Grouped taskbar previews are bounded by the panel's own monitor geometry.
- Visual: generated Aurorae frames with 12 px native shadow padding,
  rounded 8 px titlebar corners, different active/inactive shadows, and
  separate unpadded maximized frames in both variants. Bottom client corners
  remain square rather than clipping arbitrary apps. Native PLM's Login
  Screen settings can copy the local lock JPEG using its authorized helper;
  the existing privileged installation and wallpaper settings are unchanged.
- Details: selected tile icon contrast follows the actual accent; lock and
  greeter clocks use the locale short time format, and the user label is
  translatable. No Windows fonts are installed.
- Offline: exact window-frame generator and both generated SVG blob hashes
  match the local files; generator --check, XML and four alpha sample checks
  per SVG passed. Six contrast cases passed on the exact existing color
  helper. Added matching Qt tests and a generator check to verify-all.sh.
  The new applet QML, actual KSVG window rendering, full repository checks
  and CI results remain unverified locally (no Qt tools or GitHub DNS).
- Remaining before the three-phase merge: review the reference layout and
  category treatment, true wallpaper-tinted Mica and Acrylic calibration,
  safe client-corner behavior, remaining native icon states/FrameSVG parity,
  and any unfinished integration identified by CI. No stable release yet;
  the 67.5% development-stage rubric remains unchanged.

Update these categories after each substantive batch using the same rubric. Avoid claiming 1:1 visual parity until actual reference and runtime checks establish it.
