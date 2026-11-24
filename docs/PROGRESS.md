# Windows 11 fidelity progress

Target: Windows 11 26H2 GA, with KDE/Qt-native implementations where Windows APIs are unavailable. Use the system text font and a single icon theme. Keep original user-supplied Windows resources local.

The historical estimate below combined implementation and reference/runtime acceptance. It is retained as a historical record, not a current development-only percentage. Owner clarification: development completion is code and design implementation; the owner performs live acceptance separately. Do not decrease development completion because of pending live acceptance, or label known unfinished code complete. Keep an explicit list of remaining implementation work and a separate acceptance status.

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

Historical combined estimate: **67.5% (rounded to 68%)** as of this batch. It is not a current code-only percentage or a pixel-match claim.

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

## Material role and native status follow-up

- Application window bases remain opaque in both transparency modes; existing KWin blur and noise are reserved for translucent popups. The switch no longer makes file-manager views translucent.
- Reuse the existing Aurorae frame generator and installed Windows-modern wallpaper package to sample an opaque active tint for Aurorae and Kvantum. Separate dark/light images, neutral inactive and disabled fills, and optional Pillow sampling provide a fallback without a new shader, daemon, global palette, or font change. This static Mica-style approximation is not position-dependent DWM Mica and does not track wallpaper changes outside the project.
- Add 22 local icon paths (429 total), including Switch User, limited Wi-Fi levels, wired limited/VPN, and unknown charging. Two no-route aliases now use Ethernet warning. Nine changed source glyphs exist in the supplied font and rendered nonempty at 48 px. The Wi-Fi toggle no longer assumes full signal when the primary connection is not wireless.
- Local checks: seven window-material tests passed, including separate wallpaper variants and stock-frame reset; exact tested generator/test Git hashes match, and stock generated Aurorae frames remain unchanged. Actual 3840 x 2400 light/dark Bloom images were sampled without committing artwork. Four mocked transparency transitions kept windows opaque. New CI, full importer CLI and live Plasma acceptance remain pending.
- KWin already has blur/noise/saturation controls and native client rounding where supported. Prefer compatible native decorations or an explicitly owner-selected existing effect; do not add or enable a second effect automatically. Dynamic Mica, compositor calibration, client-corner and multi-monitor acceptance remain open. Do not merge or claim exact parity yet.

## Native status and power controls follow-up

- The stock Plasma 6.7/6.8 PowerDevil inhibition API replaces the two custom sleep-inhibitor subprocess/polling paths. The quick tile and battery page use the existing native manual state, not a second inhibitor. An old custom inhibitor, if active, should be released before upgrading; this migration deliberately does not kill processes by name.
- Battery level boundaries, unknown state, charging/plugged-in distinction, accessible label, and lock-screen symbolic names have been aligned. Added 32 battery-state regression assertions (passed locally in Node; Qt/live verification remains pending).
- Five additional symbolic device paths (434 total) reuse source glyphs from the supplied font. All five glyphs were verified and rendered locally. Do not rebuild the legacy SVG sheets solely to duplicate current Kirigami icon-theme consumers; retain compatibility fallback assets until live validation identifies an actual missing role.
- The project remains at the recorded 67.5% development-stage estimate pending substantive acceptance. No 1:1 claim, new dependency, or merge.

## Owner-defined development gate

The owner requires minimal changes, use of existing KDE mechanisms and compatible upstream work, no new mandatory runtime dependencies, and maximum Windows 11 fidelity. Complete code/design work before the integration merge; live visual and desktop acceptance belongs to the subsequent owner test phase. Run only relevant source checks and the existing CI; do not make live acceptance a development-completion criterion.

Latest implementation: OSD work-area positioning and recursion guard, narrow-display Alt+Tab width limits and theme-duration highlight animation (commit c8e7af8), plus 115 additional icon target paths. This expands the single local Windows-resource overlay, not a second icon theme. The source archive is not mounted in the current session, so exact new glyph rendering was not repeated.

Known remaining implementation gaps: wallpaper-following Mica beyond the static package tint; final Acrylic role/alpha calibration; safe native client corner rounding with the current Aurorae design; toast and OSD details; Start/taskbar reference layout details; remaining icon names/FrameSVG states and typography across the shell. These are code/design gaps, not owner test tasks. No current claim of 100% development or pixel parity.

## Native shell finishing pass: transparency and OSD

The owner clarified the scope: polish a Windows 11-inspired KDE theme,
not a new desktop environment. Retain the existing custom Start, tray,
taskbar, clock, lock, login and window switcher, and use native Plasma,
KWin, Qt/Kvantum and icon-theme interfaces for the remaining surfaces.

- Use the shipped solid panel and dialog artwork when transparency is
  disabled, including explicitly translucent panel selectors. Re-enable
  restores the original artwork. Keep layout settings and inner widgets.
- Add 34 native icon aliases for the actual OSD and common shell icon names.
  Retain distinct high-volume, blocked and disabled fallback art where
  an equivalent is unconfirmed. No new OSD service or icon theme.
- The preceding CI #11 passed. The owner reattached the 273 MB resource
  archive, but the file execution environment could not open the archive
  in this session. New mappings were checked against the KDE 6.8 source
  and Microsoft's glyph reference; actual archive import is not verified.

## Wallpaper-following material refresh

The existing transparency command now supports a one-shot current-image refresh using KDE's saved image wallpaper configuration. Prefer an unambiguous primary-screen image, otherwise a unique saved local image; ambiguous or unsupported sources return to neutral. No new shader, background service or polling. The material remains an opaque, global Mica-style approximation rather than DWM. Added targeted tests for wallpaper selection and file sampling to the existing material suite. Aurorae V2 cannot set a theme-defined bottom client radius; preserve the current native-compatible decoration rather than require another effect or a new engine.
