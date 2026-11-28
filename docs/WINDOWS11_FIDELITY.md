# Native Windows 11 visual fidelity

This fork replaces the upstream Windows 10/11 hybrid target. KDE and KWin remain the platform; do not fork backends or introduce a second renderer just to change appearance. Pixel-level parity is an acceptance target, not a claim about current code.
Use the [project quality ledger](PROJECT_QUALITY_LEDGER.md) for current
source and desktop acceptance status. This document preserves technical
requirements and historical observations; older research notes do not
override later implementation evidence in the ledger.

## Reference

Use Windows 11 26H2 Build 26300.9974 as the reference. Record locale, resolution, display scale, accent, transparency, theme mode and Start settings for each comparison. Compare Windows logical dimensions to Qt logical dimensions at matching scale, including the visible artwork and the input region. Track source coverage and desktop acceptance separately.

## Material roles

Use Microsoft's [material guidance](https://learn.microsoft.com/windows/apps/design/signature-experiences/materials) and [Mica guidance](https://learn.microsoft.com/windows/apps/design/style/mica), then check the actual reference shell. Acrylic is live background blur/tint on temporary flyouts, menus and transient panels. Mica is an opaque wallpaper-tinted base for long-lived window surfaces, with active/inactive states. Smoke dims underlying UI for modal interaction. Do not call a transparent SVG Mica; do not apply Mica to all flyouts. Taskbar material and sub-surfaces must match the chosen shell build, with solid fallback when transparency is off. Use KWin/Plasma mechanisms first; implement real wallpaper sampling only where Mica needs it.

## Typography and layout

Follow the current KDE system UI font and Qt language fallback; never change font settings during a normal installation. Use regular body text and semibold section headers, scale relative to the system UI metrics and the chosen Windows 11 reference. Honor accessibility text sizing and fractional DPI. Preserve symbol glyphs independently of the text font. Pre-login UI follows the greeter session's font.

Keep theme frames in the Plasma style; share geometry, colors, typography roles and icons where components have the same visual semantics. Keep Start, clock, tray and window behavior modular. Use existing model/activation/keyboard/accessibility paths. Keep both color variants synchronized. Avoid duplicate generated files without a generator or parity check.

## Single icon library

`icons/windows-modern/` is the single installed Freedesktop icon theme. Do not
install multiple Windows-look icon packs or add per-widget hard-coded asset
paths. Keep a canonical SVG per visual role and use compatible aliases for
Desktop Entry names and state names. Identical alias content may share the
same Git blob. Preserve distinct color vs. symbolic roles, genuine application
logos, signal levels, muted/charging states and theme-aware recoloring.
Plasma FrameSVG icon sheets remain where its SVG APIs require them; use the
same icon design there rather than creating a separate user-visible theme.
Do not explicitly inherit Breeze. Keep hicolor for genuine third-party application identities. Project-owned system controls must resolve matching original Windows artwork directly; unresolved artwork must not be replaced by unrelated KDE glyphs. Qt/Plasma implicit fallbacks and unverified legacy theme assets remain coverage gaps.

Reference projects: [ELEVEN](https://github.com/innerpulsenet/ELEVEN) for
preserving panel/font settings and leveraging native KWin/Plasma geometry,
[Fluent KDE](https://github.com/vinceliuice/Fluent-kde) for theme integration,
and [Fluent System Icons](https://github.com/microsoft/fluentui-system-icons)
for consistent symbolic drawing. Review before importing; do not stack themes
or copy redundant renderers.

For original Windows reference assets, record the image build, file and
resource ID, then map by function/state, not by numeric extraction order.
Do not publish proprietary Windows resources; optional local imports can
remain outside Git. The chosen target is Windows 11 26H2 General Availability (OS build 26300), not an experimental preview. The supplied resource file versions alone do not prove the installed OS build.

## Acceptance matrix (pending unless verified on a live desktop)

| Surface | Compare |
| --- | --- |
| Start | Position, search, pinned grid, All/Recent, footer, keyboard, drag, menu; no Win10 default layout |
| Taskbar | Group alignment, size, glyphs, hover/press/indicator, overflow, multi-monitor |
| Quick Settings | Grouped entry, toggles, spacing, sliders, detail pages, material |
| Notifications/calendar | Native placement, date/time layout, cards, clear actions, material |
| Context menus/OSD | Surface role, edge, shadow, icon size, action state |
| Windows | Rounded corners where appropriate, shadow, title bar buttons, actual Mica where used |
| Lock/login | Wallpaper crop, type, account and input controls, session switching |
| Icons | Freedesktop name and alias resolution, symbolic/color states, DPI, dark/light |
| Installer | Upgrade without layout reset, reversible changes, system fonts unchanged |

Development and live acceptance are separate gates. Finish the scoped code/design changes, perform relevant static checks and submit the batch to testing. The owner tests at 100%, 125%, 150%, 200%; light/dark, zh-CN and en-US, different wallpaper and system fonts, transparency on/off, and multiple monitors. CI, pull requests and merging into main require explicit maintainer approval after manual acceptance. Pending owner tests alone do not reduce code completion. Keep changes reversible, and do not label the integration a verified stable release or pixel-identical before live acceptance.

The [native resource importer](NATIVE_ASSETS.md) takes an explicit owner-provided archive. It generates the local canonical assets and a SHA-256 source manifest; the installer overlays only the mapped roles on the existing theme. Do not commit generated files or substitute unrelated Windows glyphs for KDE-only actions.

Shell popup frames are generated from one geometry template (see `scripts/theme/popup-frames.py`). Normal and explicit solid variants use opaque fallback colors; the translucent selector uses a consistent Acrylic-style tint with the same 8 px mask and edges. Tooltips use a distinct 4 px solid frame. Native KWin blur remains responsible for background sampling. The clock's two detached cards reuse the tray's optional native rounded-region blur helper on the same panel; without that helper, when the panel prefers opaque surfaces, or when KWin blur is disabled, both cards remain solid. No additional shader or required applet dependency is installed. Exact DWM noise, tint calibration, true wallpaper-tinted Mica and live compositor validation remain outstanding.

### Native material implementation boundary

KWin 6.8's existing blur effect provides blur strength, noise and saturation settings. Do not implement a second shader or overwrite the user's compositor preferences. Both Kvantum variants now use opaque window bases. Theme installation and transparency switching reuse the frame generator to sample the installed Windows-modern wallpaper package when optional Pillow is available. Active Aurorae and Kvantum surfaces use a bounded static tint, while inactive and disabled surfaces return to neutral. This is an approximation, not spatially adaptive Mica. The existing tray wallpaper events now refresh the static material independently of the accent selection, including manual/native accent. The shared appearance helper serializes the two renderers with explicit transparency operations; a disabled transparency marker or a different selected renderer skips the material path. The source selection and file identities are validated again before and after writing. A revisioned primary-image sample in kdeglobals avoids re-decoding an unchanged image, while both installed SVGs are re-planned to handle an upgrade or accent update. The native bridge exposes a primary-only snapshot for materials, so an unsettled or unsupported secondary display does not block screen-0 tinting; automatic accent still requires every active display. A fresh snapshot is rechecked even when a sample fails or its cache and assets already match. The accent analyzer fingerprints all input files before decoding any of them, including repeated paths, and distinguishes concurrent replacement from a stable unsupported format. The explicit transparency refresh prefers the native tray's settled screen-0 image when its bridge is available; otherwise it uses the saved local image/package. Both renderers sample that loaded image once, using the same bounded ICC-aware decoder as automatic accent. Saved wallpaper packages still retain per-mode image selection. The static tint uses an alpha-weighted RGB mean of the prepared bitmap, not the Windows accent formula or measured DWM material. File identity and the live selection are checked before and after the staged writes; a changed source rolls back the written files. A known live bridge that reports a preview, transition or unsupported selection refuses the update rather than falling back to stale settings. Ambiguous saved sources and unsupported image decoding use neutral window bases. The loaded image may differ when the other theme mode becomes active; mode and native wallpaper events request another settled snapshot. The material path retains the previous tint when live discovery or decoding is unsupported. Existing open Kvantum applications and KWin's same-mode SVG cache still require live acceptance; the patched Qt 6 Kvantum 1.1.9 plugin also watches the published renderer hashes. The native panel and dialog solid selectors are also applied when transparency is disabled.

Window material writes now reuse the same checked atomic replacement and conditional rollback as accent synchronization. Both modes are staged together, with user-owned non-symlink paths and exact generated Aurorae frame recognition; Kvantum edits are limited to the existing window/toolbar roles. The explicit transparency/refresh command no longer hides a failed window-material write; it updates the window assets before changing popup selectors, blur preferences or the saved off marker. Installation may retain the neutral theme when optional tint preparation fails. Explicit on/off now stages the popup selectors, Kvantum transparency keys and window assets in one checked file transaction. Changed or externally managed popup frames are rejected. The saved marker and KWin preference now participate in the same checked update and conditional rollback as the renderer files. Repeated off preserves the original blur choice, and refresh while off repairs all selectors. Unrelated external changes are not overwritten during rollback. Process termination mid-transaction and live compositor acceptance remain outside this guarantee. The NixOS entry uses its existing runtime and records the marker in the original exact-path backup before writing. The transparency command also sends the existing KConfig blur preference notification. The explicit on/off/refresh now hold the shared appearance lock across all renderer and preference changes; nested helpers reuse that lock, including popup generation. This prevents an accent event from interleaving with a half-applied transparency operation. The split Acrylic helper now bounds both rounded regions to the actual popup window and rejects invalid or empty card geometry; preference changes restore opaque paint before re-evaluating compositor blur, and `PopupEffects` watches `windows-modern/transparency-off` directly so Quick Settings, Media Card, Calendar and Notification cards revert immediately to opaque surfaces even if global KWin blur remains enabled for third-party windows. Across all shell popups and menus (`Start`, `Search`, `Quick Settings`, `Notification/Calendar`, `Run`, `Alt+Tab`, `DesktopMenu` and `Start` submenus), transient flyouts follow WinUI's `DialogShowingWithoutSmokeLayer` (no screen-wide Smoke scrim), while `colorType.js` and `Win11Palette.qml` expose `SmokeFillColorDefault` (`#4D000000`, `21h1_themeresources.xbf` `@326424`/`@361545`) for modal dialog overlays and `active_mode` leaves user-selected High Contrast color schemes untouched. No change to the estimated Mica tint formula or Acrylic composition is claimed.

For client corners, prefer KWin's supported KDecoration3 mechanism (Breeze since Plasma 6.5), including native CSD rounding where Plasma 6.8 supports it. An owner-selected compatible upstream [KDE-Rounded-Corners](https://github.com/matinlotfali/KDE-Rounded-Corners) effect can be evaluated separately; do not install or enable it automatically. Avoid duplicate outlines and shadows. Aurorae client clipping, tiling, maximized and high-DPI behavior require live acceptance.

### Window lifecycle, shell animation and reduced-motion inventory

| Surface / Transition | 26H2 Reference Evidence | KDE / KWin / QML Implementation | Reduced-Motion (`shortDuration <= 0`) |
| --- | --- | --- | --- |
| WinUI Theme Animation Baseline | `21h1_themeresources.xbf`: `FastAnimationDuration = 167ms`, `NormalAnimationDuration = 333ms`, `SlowAnimationDuration = 500ms`; `ControlFastOutSlowInKeySpline = 0,0,0,1`, `DecelerateKeySpline = 0.1,0.9,0.2,1` | Shell popups, KWin effects and Kirigami controls scale off KDE's global animation speed factor (`Kirigami.Units.shortDuration` / `longDuration` / `veryLongDuration`) | Global KDE animation speed `Instant` sets Kirigami durations to `0`, collapsing all bound transitions |
| Top-level window open / close / minimize / maximize / overview | DWM scale+fade open/close, taskbar icon minimize/restore trajectory, `Win+Tab` Task View overview | Delegated to native KWin 6.8 compositor effects (`Scale`/`Fade`, `Magic Lamp`/`Minimize`, `Overview` via `org.kde.kglobalaccel`); no duplicate QML window-clone animations | Controlled directly by KWin's global animation speed multiplier |
| Shell panel popups (`Start`, `Search`, `Quick Settings`, `Notification/Calendar`) | Edge-anchored slide + Acrylic surface (`PopupEffects`) | `PanelPopupHost` / `PopupEffects` registers KWin sliding-popups + bounded rounded blur regions per panel containment | KWin `slidingpopups` honors compositor animation speed; QML layout geometry is immediate |
| Start / Search / Snap / Switcher micro-interactions | Hover/press/selection subtle transitions (`90ms` project micro-interaction target; `LockApp` `FeedbackHoverDuration = 100ms`) | `ControlMetrics.microInteractionDuration` (`90ms`) in Start/Search, `SnapBar`/`CaptionSnapPicker`/`SnapAssistPicker` (`90ms`), `SwitcherView` (`shortDuration`) | Explicitly gated on `Kirigami.Units.shortDuration > 0 ? 90 : 0` |
| System Tray chevron & Quick Settings collapsible sections | `SystemTrayResources.xbf`: `SystemTray_IconRotateDuration = 300ms`; WinUI Expander chevron/height | `TrayMetrics.expanderChevronRotateDuration` (`300ms` on `ExpanderArrow`), `TrayMetrics.collapsibleArrowDuration` (`shortDuration`) | Gated on `Kirigami.Units.shortDuration > 0` |
| Calendar month / year / decade navigation | Cross-fade and zoom transitions | `CalendarGrid` / `CalendarZoomGrid` opacity cross-fade and scale zoom | Early-return guard when `Kirigami.Units.shortDuration <= 0` prevents zero-duration opacity flicker |
| Lock Screen & Login Greeter (`Win+L` / PLM) | `LockApp/CreativeOverlay.LockMDL2Font.xbf`: `FadeDuration = 400ms`, `CreativeChangeFadeDuration = 750ms`, `InstantCreativeChangeDuration = 0ms` | Dimming/clock/stack fade (`veryLongDuration * 2`, `InOutQuad`), PLM stack zoom (`veryLongDuration`, `OutCubic`), `MainBlock` `errorPulse` (`100ms` gated on `shortDuration > 0`); idle clock `1Hz` timer paused while hidden | `veryLongDuration` becomes `0` and `errorPulse` collapses to `0ms` |
| Session Splash / Welcome / Plymouth | Indeterminate 5-dot ring (`SignInProgress.qml` `1600ms` loop; Plymouth `boot-frames.py` sprite loop) | Runs only while splash/welcome view is visible; never blocks or artificially delays KSplash/PAM readiness | Indeterminate progress indicator remains functional while visible without delaying session startup |

### 26H2 wallpaper and system sound role inventory

- **Wallpapers (`22` verified packages from `26H2/Windows/Web/`)**: `Windows-modern` pairs Light Bloom (`Wallpaper/Windows/img0.jpg`) and Dark Bloom (`Wallpaper/Windows/img19.jpg`) inside a single KDE wallpaper package (`contents/images/` and `contents/images_dark/`) with calibrated `X-KDE-PlasmaImageWallpaper-AccentColor` (`#0067C0` Light / `#4CC2FF` Dark), so Plasma's `org.kde.image` automatically switches Bloom artwork on `switch-mode.sh light|dark` without re-running `set-wallpaper.sh`. Desktop application uses `preserveAspectFit` (no byte modification or silent crop); `kscreenlockerrc` uses `Windows-modern-lock` (`Screen/img100.jpg`, `FillMode=2`). Optional theme packs cover Glow (`img20`–`img23`), Captured Motion (`img24`–`img27`), Sunrise (`img28`–`img31`), Flow (`img32`–`img35`) and Lock Screens 2–5 (`img101`–`img104`).
- **System Sounds (`18` verified `26H2/Windows/Media/*.wav` sources -> `20` Freedesktop stereo events)**: Covers generic/system notifications (`message-new-instant`, `notification-new`, `bell-window-system`), email (`message-new-email`), calendar/alarm (`alarm-clock-elapsed`), messaging (`message-new-instant-messaging`), USB/hardware hotplug (`device-added`, `device-removed`, `device-error`), battery alerts (`power-low`, `battery-low`, `battery-caution`), dialogs (`dialog-error`, `dialog-warning`, `dialog-information`, `dialog-question`), login/logout (`desktop-login`, `desktop-logout`), trash (`trash-empty`) and system bell (`bell`), inheriting `freedesktop` only for unmapped roles while preserving user notification mute preferences and third-party application audio. The remaining 52 WAV files in `26H2/Windows/Media/` (`Alarm01`–`10`, `Ring01`–`10`, `Speech *`, legacy `chimes`/`chord`/`ding`/`notify`/`recycle`/`ringout`/`tada`, and silent-by-default window/menu sounds `Minimize`/`Restore`/`Menu Command`/`Navigation Start`) are intentionally excluded so KDE does not emit legacy or telephony sounds on ordinary desktop actions; `Windows Background.wav` and `Windows Unlock.wav` remain optional future candidates if the pinned private runtime manifest is refreshed.

### Static performance, memory, cache and timer baseline (`V06`)

- **Bounded bitmap & SVG rasterization**: All `10/10` `Image` items across `core/` and all 19 `modules/` (`AccountAvatar`, `DefaultAccountPortrait` imported + fallback, `TaskbarButton`, `TaskbarGlyph`, `ClipboardPage` image preview, `MediaControls`, `MediaCard`, `MenuRepresentation` user avatar, `ToolTipInstance` album art) bind explicit non-zero integer `sourceSize` scaled by `devicePixelRatio` (`>= 1`), preventing full-resolution wallpaper/avatar/clipboard bitmap decode in compact shell surfaces while avoiding fractional-DPI blur at `150%`.
- **Bounded C++ caches & event-driven watchers**: Native `QIcon` caches in `modules/desktopmenu/menulayout.cpp` and `platform/plasma/taskbar/backend.cpp` cap at `128` entries (`if (cache.size() >= 128) cache.clear()`) keyed by file `lastModified` timestamp and active theme/accent hex; `systemtray.cpp` caches bounded local SVG optical alpha bounds per canonical path; `ShellAppearanceMonitor` coalesces palette/wallpaper signals through a single `350ms` single-shot `QTimer` + `QFileSystemWatcher` without background processes or polling loops.
- **Zero unconditional polling timers**: All `10` repeating QML `Timer` instances across `core/` and `modules/` run exclusively while transient UI states are active (`clockContainer.visible` on idle lock screen, `WinClock.clockActive` on login screen, active `FocusSession` countdown, active Quick Settings tile drag, visible `DndToggle` minute tick, visible `NetworkPage` Wi-Fi scan, bounded `geometryProbe` attempts on tray open, visible `CaptionSnapPicker` / `SnapAssistPicker` guard, and unlocked PAM retry while `loginUiActive`).
- **GPU / software-renderer offscreen layer discipline**: Every `layer.enabled` binding in shell QML is gated either on `visible` (`AccountAvatar`, `DefaultAccountPortrait`, `MediaCard`, `MenuRepresentation`) or on `GraphicsInfo.api !== GraphicsInfo.Software` (`ToolTipInstance` album blur, `SwitcherView` thumbnail & mask, `SnapAssistPicker` thumbnail & mask), avoiding persistent hidden FBO allocations and software-renderer shader failures. `QML_DISABLE_DISK_CACHE=1` is confined strictly to isolated test sessions (`verify-nixos-runtime.py`), leaving Qt's compiled QML disk cache active in normal desktop use.

References: [Microsoft Mica](https://learn.microsoft.com/windows/apps/design/style/mica), [KWin native blur](https://github.com/KDE/kwin/tree/v6.8.2/src/plugins/blur), [KDE native corner rounding](https://blogs.kde.org/2025/07/19/this-week-in-plasma-rounded-bottom-corners/).

The owner clarified that the project should polish its current theme surfaces and existing applets, not rebuild the desktop. Aurorae V2 does not expose a theme-defined bottom client corner radius. Keep its existing titlebar, top rounding and shadows, and preserve KWin's native rounding for decorations that opt into it. Do not add a mandatory compositor effect or clip arbitrary application contents. See [KDE's Aurorae design notes](https://planet.kde.org/vlad-zahorodnii-2025-11-13-whats-next-for-aurorae/).

### Quick Settings acceptance detail

Use the Windows 11 scrollable Quick Settings baseline: three full-width columns, up to two visible rows, wheel/touch/keyboard navigation for later rows with the conditional dots and directional arrow from the existing 26H2 reference implementation, no permanent scrollbar rail, fixed brightness/volume/footer, direct rearrangement without a separate edit mode. Preserve existing KDE hardware availability and optional tile settings rather than adding nonfunctional Windows-only controls. Compare at the same scale in both variants; test drag into the last row, cancellation, click versus drag, persistence after logout, keyboard focus reveal, details back navigation, and wheel/touchpad scrolling. Touch reorder and exact Windows motion remain live-reference work. Reference: [Microsoft taskbar Quick Settings](https://support.microsoft.com/en-gb/windows/experience/personalization/customize-the-taskbar-in-windows) and [Microsoft keyboard/accessibility guidance](https://support.microsoft.com/en-us/accessibility/windows/navigate-and-explore-the-windows-taskbar).

### Tray geometry and current Plasma compatibility

For a standard 48 logical-pixel panel, the current project uses a 30 px task/Start canvas, a 16 px tray glyph box, 32 px normal tray cells and 24 px grouped network/volume/battery cells. The notification bell uses a 16 px glyph box in a 24 px cell. The 32 px native compact representation host is only a fallback, scaled into the smaller tray box. Preserve the source aspect ratio, state-dependent battery and network artwork, input-language text, user-selectable spacing and mirrored layouts. Qt applies the display scale. At 150%, the task canvas is 45 physical pixels and the tray box is 24 physical pixels; painted bounds depend on the artwork. These are current implementation targets, not measured Windows shell specifications. Imported artwork and native fallback delegates still require matched live comparison. Default order: overflow, application items, language, network, volume, battery, clock and notification bell, then the 6 px Show Desktop sliver. See [Windows taskbar styling measurements](https://github.com/ramensoftware/windows-11-taskbar-styling-guide#tray-icons-size) and [Microsoft Quick Settings](https://support.microsoft.com/en-us/windows/experience/personalization/customize-the-taskbar-in-windows).

### Desktop acceptance

The panel measurements in this branch are in logical pixels. The 30 px task icon canvas and 16 px tray glyph box are provisional project settings. There is no measured 26H2 screenshot in this checkout that establishes it as the Windows default. Leave output scaling to Qt and KWin. Record the Windows build, native resolution, scale, language, theme and input method with each comparison.

| Surface | Runtime and regression coverage | Outstanding desktop evidence |
| --- | --- | --- |
| Taskbar and tray | Native applet status and user pin/hide preferences decide visibility. Application artwork retains its aspect ratio. The tray reports effective-status changes to its proxy models. | Measure active glyph bounds, badge placement, drag ordering and context menus on matched displays. |
| Win+A and devices | Bluetooth uses BluezQt and the Bluedevil device page. Removable storage uses KDE's Disks & Devices applet. Per-display sliders use PowerDevil model roles. Cast launches an installed GNOME Network Displays service. Accessibility opens the installed KDE module. | Exercise pairing, failure, disconnection, USB busy/eject, external display hotplug, wireless projection and audio route changes. |
| Start, notification history, calendar, clock and OSD | Qt interaction tests cover the Start view, calendar and scrolling. The live tests in the source checkout drive the shell through real input. | Compare Chinese and English in each theme at 150%. Check focus, touchpad movement, text clipping and notification delivery in a running session. |
| Alt+Tab, Task View, snap, lock screen and window frames | The switcher suite loads the KWin layout. Window material tests exercise light and dark frame generation. | Compare window lifecycle, snap placement, gestures, lock-screen focus, shadows, animations and GPU blur in KWin. |
| NixOS lifecycle | Source builds target the installed Plasma version. The owner ZIP includes the runtime resources; desktop test suites stay in the checkout. The uninstall dispatcher has an isolated routing test. | Install, upgrade and restore on the target generation. Verify the running plugin identity after each change. |

No matched native screenshot set or target hardware session was supplied for this review. The live rows remain open. The desktop tests remain in the repository checkout under `tests/`. The lock-screen test uses a separate testing greeter.

Implementation references: [KDE Bluedevil](https://github.com/KDE/bluedevil/tree/Plasma/6.8/src/applet), [KDE Disks & Devices](https://github.com/KDE/plasma-workspace/tree/Plasma/6.8/applets/devicenotifier), [PowerDevil display controls](https://github.com/KDE/powerdevil/tree/Plasma/6.8/applets/brightness), [GNOME Network Displays](https://gitlab.gnome.org/GNOME/gnome-network-displays).

### Modern battery and grouped hover follow-up

The QML battery uses imported Windows battery-state glyphs. The owner audit subsequently recorded the original 26H2 SysBatt outputs and the current renderer prefers the privately imported artwork. The legacy family remains only a compatibility path; verify the installed original and actual role/state coverage. Compare the actual states and optional percentage against the matching Windows reference. Verify charging, charge limits, unplugged power saver, critical and unavailable battery states. The shared highlight must have no seams between adjacent network, audio and battery cells, including when percentage is enabled. Test AM/PM across midnight/noon, with the numeric date unchanged. The legacy glyphs come from Windows but are not evidence of the newer 26H2 state artwork. See NATIVE_COVERAGE.md for the later owner audit and import boundary.

### Search home, clock and media source (owner reference, 2026-11-25)

The Search home reuses local Kicker usage models, existing Milou results and native applet actions. Compare both entrypoints, empty-query state, cleared filters, IME/keyboard input, actual recent/popular app launches and settings queries in the running desktop. The reference's promotional items and rewards controls are intentionally omitted. The later owner audit records all four original Search state outputs. The current source selects the private state PNGs when available; the mapped legacy mask is still a compatibility presentation. Installed role/state and optical parity remain open. Check the region-default clock with 12- and 24-hour locales and real timezone changes; the migration of legacy forced formats is one-time. Check Firefox Nightly and Edge live MPRIS sources, controls and icon availability. No pixel similarity score or live acceptance is asserted without a same-scale screenshot comparison.

## Opt-in nested Wayland capture

The original nested desktop capture from PR #27 is retained in `tests/panel/nested-wayland.sh`. Build with `scripts/ci-build.sh BUILD_ROOT` first. Run the capture only as a separate disposable test user with a fresh Xvfb display and private session bus, for example:

```sh
WM_DISPOSABLE_DESKTOP=1 xvfb-run -a -s '-screen 0 1920x1080x24' dbus-run-session -- bash tests/panel/nested-wayland.sh BUILD_ROOT CAPTURE_DIR
```

Requires Weston, KWin, Plasma, KScreen, ImageMagick and a compatible rendering backend. The script checks the actual compiled tray and task-manager plugin mappings and records light/dark captures at 100%, 125%, 150% and 200%. It refuses an existing Plasma session and fails if rendering, scaling or plugin loading fails. This remains an opt-in integration test: the previous hosted runner could not supply a compatible nested rendering device. The normal compile and headless interaction CI does not certify physical desktop capture. Use the target NixOS live tests for the owner's hardware acceptance.

### Owner reference: boot, login and desktop background menu

The owner supplied a five-dot loading reference, centered account and password
form, account switcher with selected row, and compact desktop background menu.
The independent KSplash packages and greeter share the same five-dot source;
the Plymouth generator uses the same angular spacing. Shutdown mode hides
the boot logo and presents actual system status text. Plymouth does not expose
a separate reboot identifier through GetMode. No delay, authentication bypass
or power-state simulation is introduced.

The desktop background plugin applies a scoped light/dark row and surface
style to menus containing its own actions and associated submenus. Native
actions, availability, keyboard navigation and submenu activation remain
in Qt/KDE. Check first-open geometry, reopening, disabled paste, undo,
shortcut alignment, icons, arrows, shadow, DPI, RTL, dark/light and unrelated
application menus. Exact reference scaling was not supplied; these logical
measurements are provisional. DWM material and glyph parity remain unverified.

### Owner taskbar reference, measured at proportional scale

The supplied current screenshot is 568 x 199 pixels and its taskbar is
approximately 72 px high; the enlarged Windows crop is 1327 x 460 and its
taskbar approximately 150 px high. Comparing raw pixels is invalid.
Bright-pixel centers of the current Wi-Fi/volume/notification glyphs are
near y=164; reference Ethernet/volume near y=336. The charging battery
ink extends above its body in both screenshots. Keep its body and the
percentage on the common centerline, without offsetting all icons upward.
At a nominal 48 logical px taskbar, keep 16 px status canvases, 24 px
group cell pitch, and 32 px standalone cells. A battery is 20 px wide.
The reference implies a 40 px high hover surface and approximately
6 additional logical px before the first grouped glyph. Apply that inset
to the actual hit cell and preserve the spacing between adjacent glyphs.
Qt applies 100/150/200 percent scaling once. Simplify grouped status
tooltips to a single live status line; KDE actions remain native.
These are proportional screenshot measurements and implementation targets,
not independent certification of the reference's display scale or exact
glyph artwork. Confirm first/last cells, RTL, vertical panels, and actual
screen-space centering and tooltips in the running shell.

### Cross-platform optical size calibration

Do not equate a Windows icon resource size with a Qt source canvas. The
owner screenshots have different crop magnifications: current taskbar
approximately 71 pixels high; reference approximately 151. At a nominal
48px panel, a bright-pixel threshold of RGB channels >145 gives battery
widths 20.3/20.0, bell heights 14.9/15.3 and Chinese label heights
14.9/14.9 logical pixels (current/reference). These are measurements from
the supplied crops, not native DPI certification. Do not shrink these
already comparable surfaces.

Older bundled volume SVGs have a 22px viewport and around 16px full ink
width, while imported glyphs fill roughly 23/24 of their canvas. The
direct tray renderer now reads local SVG alpha bounds once per source,
caches a bounded result, and compensates excess padding only when the
largest ink dimension is less than 90% of the canvas. It preserves
aspect ratio, uses a shared full-volume reference for non-muted levels,
includes faint state waves and centers optical bounds. The bounded
compensation targets the imported 23/24 coverage, not a second DPI
multiplier. Unknown or unreadable assets retain normal sizing.
No changes to battery, clock, application icon sizes or the tray hit
targets are made by this correction. Confirm actual Qt rasterization
and same-scale Windows comparison in the live target session; synthetic
geometry and alpha-bound tests do not constitute visual acceptance.

### Follow-up: stable signal-state geometry and owner bundle acceptance

Measure the actual fallback SVGs using Qt's image decoder in the native
test target, including five output scale factors. Resolve standard KDE
theme names when no direct local status/action/device path is available.
Use one Wi-Fi family reference for all signal levels and a separate full
limited-network reference; do not resize weaker states independently.
The volume family retains its full-level calibration. No change to
battery or application-icon dimensions is made by this follow-up.

The private owner bundle is distinct from the public integration artifact.
Its package mode verifies exact mapped resource membership and hashes, source
SHA, pinned native resource revision, essential theme, installation,
local-build and artwork entries, and ZIP CRC integrity before adding the
package to its private manifest. Compressed byte count is not a completeness
criterion; never retain unused Windows files merely to reach a size target. Reject development tests, CI,
internal reports, historical screenshots and repository-only tools in the
owner ZIP. Keep those in the source checkout. Do not add filler or publish
the private resource bundle to the public Actions artifacts.

### Start and Search use distinct widths at the same height

The owner clarified that Search is wider than Start and must have the same
height. Keep the existing Start size preference (560 x 640 small, 768 x 720
large). Use a wider Search content size (680 x 640 small, 928 x 720 large),
subject to the same screen/work-area clamp. Preserve the common frame and
vertical placement; recompute the horizontal anchor using the actual width.
Search home and search results share one size regardless of query changes.
The width ratio of approximately 1.21 is derived from the owner's two
reference screenshots after normalizing their screen widths. Absolute
logical dimensions and compositor placement still require live calibration.

The existing live panel scenario `tests/panel/new_features.py OUT_DIR search`
measures the photographed rectangle and search-field geometry for Start,
input click, typed results, query clearing, direct taskbar Search, and Meta
typing. It checks equal height and vertical position, greater Search width
when space permits, and stable geometry within each mode. Run on a single
active display with a static contrasting desktop at each required DPI/theme.
Headless geometry tests are not live acceptance. No new CI workflow is introduced.

### Owner task preview and launcher tooltip reference

The taskbar screenshots show a short name-only label for a closed pinned
application, a live thumbnail for an open window, and a red close-hover
target. The previous task activation condition excluded launchers entirely.
Reuse the existing native non-activating tooltip window and its theme frame;
no separate popup service. Select the name-only delegate for zero windows,
keep existing grouped/text/thumbnail behavior for actual windows, and scope
shared-dialog visibility notifications to its current owner.

Use a 32 logical px close hit target, fixed header geometry, 4px radius,
red hover/darker press, and a 14px normalized icon canvas (about 12.25px
painted X, from the existing 84/96 optical normalization). The supplied
crops show a roughly 24px current X and 17px reference X; their exact DPI
is not established. Do not draw replacement artwork. Keep the original
close action and group-specific window index. A 12px native popup margin
and smaller card padding address the overly tight taskbar gap and doubled
edge inset. These are screenshot-derived targets, not Microsoft-published
metrics. Extend the existing real-session tests for launcher name, focus,
red hover surface and targeted window close, at 100% on one output first;
verify dark/light and fractional scaling visually on the target session.

### Integration audit: shared tooltip lifecycle and private package integrity

Only the current native tooltip owner may dismiss the shared window. Clear
click/hover ownership only for that task, and detach an obsolete content
delegate when a pinned app gains or loses its window. Bind the actual task
roles together before constructing the next card. Construct the lightweight
frame synchronously; keep the actual PipeWire thumbnail asynchronous. The
existing focus/preview/launcher scenarios are the live acceptance route.

Private owner archives are assembled under a temporary directory inside
`dist`, checked before publication, then renamed to the final filename.
A failed resource fetch, dirty or changing checkout, missing submodule,
incomplete archive, missing indexed resource or hash mismatch must not
publish a partially built final ZIP. Public packaging leaves prior verified
owner packages alone. The resource checker uses the existing index schema
consumed by the native asset importer. Its synthetic fixture checks do not
prove that a full pinned resource checkout was downloaded and packaged.

### Quick Settings grid and slider alignment, owner reference

In the marked reference, the usable slider groove is centered between the
outer edges of the three-column tile grid: both insets are approximately
36 logical px when normalized to the existing 312px content width. In the
owner's current capture the insets are about 30px and 43px. Equal lengths
alone are not sufficient. Use the actual grid margins for both slider rows,
with equal 27px end slots and an 18px thumb at the normal UI scale. Scale
these metrics with the existing optional panel UI scale, not display DPI.
Keep the brightness details slot inert and accessible only when present.
Remove the extra divider above the sliders and move the row separation into
the slider block, matching the owner's pictured reference proportions. The
right-hand output button uses the existing Speakers (E7F5) resource mapping
rather than MixVolumes (F4C3); the existing output routing is unchanged.
The screenshot proportions are design targets, not published Microsoft
control metrics or live Plasma acceptance. The existing actual-QML pointer
and wheel test also checks symmetric slot and groove bounds.

### Retired development branches

Keep the current main tree as the implementation baseline. The earlier
Fluent shell integration (1b511ca) and full local MUN exporter
(81db564) are retained in Git ancestry for future inspection,
not installed as parallel components. Their old popup, slider, sign-in,
style, packaging and CI implementations must not replace newer main code.
The resource reference branch already preserves the complete indexed
library; the current mapped runtime branch and existing shell inspector
remain the resource workflows. Do not add a second PE parser or duplicate
full-export tooling to the installable theme.

Restore the native microphone and desktop-portal capture indicator
classification from the earlier Fluent branch using the current visibility
policy. Reuse the existing SNI owner PID and native status updates, including
NixOS executable wrapper names. Only active or attention-state capture items
are shown; unrelated applications with matching artwork are not promoted.
No new monitor, polling, service, workflow or runtime dependency. The existing
tray status test covers the classification and active/idle visibility rules;
real microphone and screen-sharing acceptance remains a desktop test.

The history merge is an explicit retirement of older alternative source
trees, not a claim that all of their individual changes were replayed or
that all visuals were validated. Preserve the two resource branches.

## Dynamic accent acceptance (Windows 11 26H2)

Microsoft documents automatic wallpaper accent selection, and the public
[UISettings.GetColorValue API](https://learn.microsoft.com/uwp/api/windows.ui.viewmanagement.uisettings.getcolorvalue)
exposes the actual base accent and six shades. The PRI/XBF archive records
static brush references but does not disclose the shell's wallpaper
extraction and palette generation formulas. Full installations initialize the Windows automatic path when no accent preference exists. Explicit native KDE accent selections continue to use KDE's provider.

### Captured Windows 11 26H2 baseline

The maintainer supplied seven UISettings captures from build 26300.9974,
preserved in [the runtime accent reference](windows11-26h2-accent-captures.json).
The original blue samples were produced with the v1 script argument
Automatic, but the Settings screenshot and the owner's correction
confirm the visible setting was Manual. The archive preserves the
original argument and the verified UI mode separately. The orange sample
was captured with Manual selected.

The blue ramp is the same in dark and light modes. The manual orange
sample adds a second base color:

| UISettings role | Blue | Orange |
| --- | --- | --- |
| Accent | #0078D4 | #FF8C00 |
| AccentDark1 | #0067C0 | #E37700 |
| AccentDark2 | #003E92 | #A14600 |
| AccentDark3 | #001A68 | #651900 |
| AccentLight1 | #0091F8 | #FF9910 |
| AccentLight2 | #4CC2FF | #FFB634 |
| AccentLight3 | #99EBFF | #FFD155 |

The Windows foreground/background roles invert between modes. The accent
ramp itself remained unchanged between the two blue captures. The orange
sample is currently light mode only.

### WinUI accent role mapping

The [upstream WinUI resource dictionary](https://github.com/microsoft/microsoft-ui-xaml/blob/main/controls/dev/CommonStyles/Common_themeresources_any.xaml)
defines the accent brushes separately for its Default (dark) and Light
theme dictionaries:

| WinUI role | Dark | Light |
| --- | --- | --- |
| Primary accent fill | AccentLight2 | AccentDark1 |
| Secondary fill | AccentLight2 at 90% | AccentDark1 at 90% |
| Tertiary fill | AccentLight2 at 80% | AccentDark1 at 80% |
| Primary accent text | AccentLight3 | AccentDark2 |
| Secondary accent text | AccentLight3 | AccentDark3 |
| Tertiary accent text | AccentLight2 | AccentDark1 |
| Selected-text background | Accent | Accent |
| Primary text on accent fill | #000000 | #FFFFFF |

The existing blue defaults in palette.json already match the primary
fill roles: dark uses #4CC2FF and light uses #0067C0. The orange sample
confirms that a manual Accent of #FF8C00 must use #FFB634 for a dark-mode
primary fill and #E37700 for a light-mode primary fill. The current
accentForSurface() helpers consume one Kirigami highlight color and
adjust it to a contrast threshold. They do not select the WinUI shade
roles or distinguish the base Accent used for selected-text backgrounds.
This is a confirmed implementation gap for non-default accents.

Microsoft documents that the Windows shell generates the six shades, but
does not publish the generation formula in the reviewed API documentation.
Two base colors are useful reference points, not enough to claim an exact
reconstruction. Do not fit a fixed HSL transform or hard-code the orange
sample as a general solution.

The registered wallpaper hashes for the blue dark and light captures differ.
The light blue and orange captures share a registered wallpaper hash, but
the original image hash was not supplied. The v1 script's AutoColorization
field was null, and its mode field merely echoed the command argument.
Those fields do not establish the registry mode or wallpaper algorithm.
The v2 capture script now records both known AutoColor registry locations,
the raw Explorer AccentPalette binary value, and the manual base color
observed through UISettings.

### Registry palette observation (manual orange)

The v2 orange capture reports Themes\\History\\AutoColor = 0, a Manual
registry mode with no detected conflict, and the same seven API colors as
its v1 predecessor. The 32-byte Explorer AccentPalette has eight four-byte
slots. In this capture each slot is RGB followed by 00. The first seven
slots exactly match UISettings in this order: AccentLight3, AccentLight2,
AccentLight1, Accent, AccentDark1, AccentDark2, AccentDark3. The last slot
is #0063B1; its meaning and the fourth byte's semantics are not established.
DWM AccentColor and Explorer AccentColorMenu both encode the base orange
as AABBGGRR (0xFF008CFF); StartColorMenu encodes AccentDark1 as 0xFF0077E3.
DWM ColorizationColor is recorded separately as the raw value 0xC4FF8C00.
These are observations, not a cross-version registry contract.

The format stores already-generated colors. It does not expose the
wallpaper extraction or seven-color generation formula. Do not infer the
formula from registry byte order or substitute the eighth slot for a WinUI
accent role. The existing shared-palette regression check compares the
raw bytes with the independent API capture. Keep the remaining extraction,
role propagation and live renderer refresh work open.

### Registry palette observation (automatic blue)

The v2 automatic sample reports 1 at both AutoColor locations, with no
conflict. The registered wallpaper hash, placement and reported display
size match the preceding manual orange sample. Its API Accent is #2475CE.
The first seven RGB slots again match the API; the eighth slot is #881798
and remains unassigned. Explorer AccentColorMenu encodes #2475CE
(0xFFCE7524), and StartColorMenu encodes #1C5CB2 (0xFFB25C1C).
DWM AccentColor and ColorizationColor retain the previous orange values.
Consequently, those DWM registry values alone are not a reliable source
for the current shell accent. Do not treat their persistence as a failure
of the automatic palette capture.

The matching registered wallpaper hash establishes a controlled
manual-to-automatic comparison. The archived resources/windows11 branch,
commit 272e06c87be0f548cebb2558392019b941df20d4, lists in verification.json
two byte-identical original wallpapers with this exact SHA-256:
Windows/img0.jpg and Spotlight/img14.jpg under original/Windows/Web/Wallpaper.
The fixture now records that reference separately from the v2 script's
null source_wallpaper_sha256. The archived index identifies the reference
image bytes without establishing which path the operator selected.
Do not copy the proprietary wallpaper into this development branch.
The automatic generation and extraction algorithms are still unverified.

### Manual palette generation research

The third-party [Windows Accent Colors analysis](https://gist.github.com/cnbluefire/7ffa04c493c57b8a67f6a8baa2c726f7)
describes a preset palette lookup and separate custom-color generation
paths. Its listed blue and orange presets match the measured seven-color
ramps exactly, but this does not validate its custom-color algorithm on
26H2. It explicitly excludes wallpaper automatic colorization.
Treat it as a research lead, not a Microsoft implementation or a
dependency.

### Manual preset lookup

The 48 preset base RGB values and their six Windows shades in
`core/palette/accent-algorithms.py` (336 RGB values total) have now been
independently verified byte-for-byte (0 mismatches) against the 1,536-byte
`48 × 8` `COLORREF` tables in `Windows/System32/uxtheme.dll` (offset
`0x73E80`) and `Windows/System32/windowsudk.shellcommon.dll` (offset
`0x5DE680`) from the local 26300.9974 extraction; the eighth slot stores a
companion preset RGB rather than a WinUI shade role, and transposing the
8×6 column-major table yields the exact 6×8 Settings "Windows colors"
swatch grid (`PRESET_SWATCH_GRID`) used by `ConfigColors.qml`. No
third-party executable code or Microsoft binary is imported. The existing
accent collector retains its read-only guided manual batch mode for custom
boundary controls:

```powershell
.\capture-windows-accent.ps1 -AccentMode Manual -ManualPaletteBatch
```

The report is saved after each selection on the Desktop as
`windows-accent-batch-*.json`. Enter records a selection, S skips an
unavailable input, and Q saves and stops. `-BatchColors` accepts an
explicit subset (including custom controls); skipped inputs remain
unverified. No batch capture has been executed yet.

Compare one or more complete or partial reports without changing the
current palette:

```sh
python3 scripts/theme/sync-accent.py --compare-manual-palette windows-accent-batch-*.json
```

The comparison verifies target build, operator input provenance, manual
registry mode, all seven UISettings/registry RGB slots, and batch
coverage. Identical repeat observations merge; contradictory observations
are rejected. The report lists per-role mismatches and remaining
requested inputs, so interrupted collections need only request the
remaining colors through `-BatchColors`. Presets absent from these reports
remain listed separately; this does not invalidate the two earlier
independent measurements. No captured values are installed automatically.

The older Windows 10 published swatch list used #0078D7; the current
reference and our measured default use #0078D4. Do not add the older
color as an alias or generate preset shades using the custom formula.

The staged derive_manual_palette() entry point accepts an original
manual RGB input, checks exact preset identity first, and otherwise
uses the existing CIELAB/HSL dispatcher. It returns a new seven-role
mapping; the fixed reference rows are not mutated. Regression assertions
cover table shape, exact matching, the two measured preset colors and
the custom paths. The table stays in the existing installed module,
so no new packaging dependency or runtime file lookup is required.

The capture script v3 preserves the entered custom RGB value and the
observed base Accent separately, even when they differ. The previous
v2 cross-check rejected mismatches, preventing normalization analysis.
The owner supplied a v2 custom purple capture following the instruction
to enter #9F5A8C. Its observed base is #A25D8F; the v2 command omitted
ManualColor, so the exact entered value remains operator-context evidence,
not a field recorded by the capture. With that requested RGB, the
independently written CIELAB calculation reproduces all seven observed
colors (21 RGB channels), including the normalized base:

| UISettings role | Observed RGB |
| --- | --- |
| Accent | #A25D8F |
| AccentDark1 | #884976 |
| AccentDark2 | #662F56 |
| AccentDark3 | #401132 |
| AccentLight1 | #B173A1 |
| AccentLight2 | #D8ADD0 |
| AccentLight3 | #EECEEB |

The raw registry slots also match the seven API roles; the eighth is
#881798, unchanged from the preceding automatic capture. A read-only
calculation based on the requested input produces the complete ramp.
Reusing the normalized #A25D8F as input does not produce identical
Dark1 and Dark3, so input and output must remain distinct.

The existing sync-accent.py module now exposes a pure
derive_custom_lab_palette() function for the central CIELAB branch.
It uses standard-library color conversion and rounds intermediate RGB
values before saturation correction. It rejects extreme-lightness and
near-gray inputs, which belong to the separate legacy HSL branch.
Callers must not use either custom branch for Windows preset colors or
wallpaper extraction. The existing window-material regression suite
contains the conditional purple vector and branch rejection checks.

### Near-gray custom color (legacy HSL candidate)

The v2 capture following the request to enter #808482 reports that same
base color. The seven API colors are:

| UISettings role | Observed RGB |
| --- | --- |
| Accent | #808482 |
| AccentDark1 | #7F8381 |
| AccentDark2 | #7E8381 |
| AccentDark3 | #7E8280 |
| AccentLight1 | #808482 |
| AccentLight2 | #818483 |
| AccentLight3 | #818583 |

The input's HSL saturation is 0.016 and lightness is 130/255. The
research lead describes a low-saturation or extreme-lightness HSL branch.
Direct calculation with float32 offsets and truncation can differ by
one unit at integer boundaries for this sample. Using
the nominal decimal offsets in exact rational arithmetic matches all
seven measured RGB colors. The staged derive_custom_palette() function
dispatches the two custom branches using exact HSL boundaries and keeps
HSL truncation separate from CIELAB rounding. The exact rational
precision choice is a candidate based on this observation, not evidence
of Windows's actual arithmetic or universal equivalence. Further
boundary and independently recorded inputs remain unverified.

The raw palette has FF in the fourth byte of all seven API slots,
unlike the 00 seen in the saturated custom, preset orange and automatic
captures. The eighth slot stays #881798 followed by 00. Preserve these
observations without interpreting the fourth byte as alpha or the eighth
slot as a color role. The regression fixture records the original
requested input provenance and the separate byte pattern. No
third-party executable code or additional dependency is imported.

This is a staged calculation core, not a change to the installed
accent propagation: KDE's effective selection color remains authoritative
for Plasma and Kvantum. Applying the new ramp only to Kvantum or custom
QML while leaving KColorScheme unchanged would break color consistency.
Both custom calculation branches and the manual preset dispatcher are
now staged. Independent boundary validation, the remaining preset
measurements and automatic palette generation are open. The original automatic wallpaper is identified in the resource
index, so do not ask the maintainer to export the same image again.
No repeat of the existing color captures is needed.

### Automatic shade generation and extraction

An independent calculation using the existing CIELAB formula and the
observed Bloom automatic base #2475CE produces all seven captured RGB
roles exactly. The existing regression suite now includes that vector.
This is evidence that the custom shade calculation can reproduce one
automatic ramp once its base is known. It is not proof of the original
extraction input, a general automatic formula, or preset-table behavior
in automatic mode. Keep the manual input and observed output distinction.

Microsoft's [US8897552B2](https://patents.google.com/patent/US8897552B2/en)
and [US8847973B2](https://patents.google.com/patent/US8847973B2/en) describe
historical, differing image-color selection techniques. Neither establishes
which implementation, parameters or image preprocessing Windows 11 26H2
uses. Do not substitute a historical algorithm, KDE's clustering or an
image-hash lookup and label it as the native Windows extractor.

Plasma 6.8.3's
[wallpaper metadata reader](https://github.com/KDE/plasma-workspace/blob/v6.8.3/wallpapers/image/plugin/utils/mediaproxy.cpp)
supports mode-specific wallpaper accent colors but falls back to the
light metadata value when the dark value is absent. Its
[color applicator](https://github.com/KDE/plasma-workspace/blob/v6.8.3/kcms/colors/colorsapplicator.h)
also blends the supplied accent at 70% opacity over the view or button
background for those selection roles. Thus even a measured WinUI fill
placed in the metadata is not necessarily the effective KDE selection
RGB. Do not set partial Bloom metadata, overwrite the native palette
from a tray applet, or compensate with guessed inverse RGB values.
A later integration must distinguish raw input, the seven WinUI roles,
and the effective KDE renderer palette.

### Controlled wallpaper probes

The optional [wallpaper probe collector](../scripts/capture-windows-wallpaper-probes.ps1)
reuses the existing read-only accent capture script (schema 2 or newer)
to obtain several observations in one maintainer session. Run it only
in the reference Windows VM, with a single display, a static Picture
background and Automatic accent mode. It creates six uncompressed
24-bit BMP fixtures at the reported display size: solid purple, orange,
gray and blue, plus a pair of identical-color-area purple rectangles
on orange backgrounds, one centered and one in a corner. The pair
separates area-based selection from spatial weighting; the solid probes
separate color normalization from image selection. The intervening
gray image reduces ambiguity from successive equal palettes.

The opt-in script temporarily changes the wallpaper using the documented
IDesktopWallpaper API. It does not write accent settings, change display
mode, restart the shell, or import any external wallpaper. It refuses
non-automatic or changing appearance context and requires matching
UISettings/Explorer slots, two stable observations and the requested
wallpaper path. Samples with unchanged registered image or palette
evidence remain inconclusive, even if stable. The original image is
restored in a finally block when the current path is still owned by the
collection. The report distinguishes image restoration from palette
reproduction. Windows may update its recent wallpaper/theme history;
the script cannot restore that history and must not be used on a desktop
whose personalization history must remain unchanged.

In the folder containing both scripts, execute:

```powershell
.\capture-windows-wallpaper-probes.ps1 -ApplyTemporarily
```

Submit only the generated wallpaper-probes.json. Keep the local
restore-original-path.txt private; it is a recovery path if the
collection or restoration is interrupted. The report contains the
original capture, each exact synthetic image specification and SHA-256,
and the restoration observation, not the original absolute file path.
The tool is a reference collection utility, not an automated KDE
acceptance test, and is not installed into the Linux runtime theme.

### Measured controlled automatic palette results

The maintainer successfully ran the six-probe collection on 26H2 build
26300.9974 at 1280x800, with both light mode flags set. The complete
[probe report](windows11-26h2-wallpaper-probes.json) preserves the
observed colors, exact image recipes, SHA-256 values, raw registry
values, stable-capture flags and restoration result. All six samples
changed both the palette and the registered image relative to the
preceding sample. Source and registered hashes match for every image.
Restoration reproduced the baseline image and palette.

For these settled observations only, the low 24 bits of DWM
ColorizationColor provide a useful intermediate RGB to the existing
CIELAB calculation:

| Image | Intermediate RGB | UISettings Accent |
| --- | --- | --- |
| Bloom | #2475CE | #2475CE |
| Solid #9F5A8C | #B25098 | #B25098 |
| Solid #FF8C00 | #B75B00 | #B75B00 |
| Orange + centered purple (25%) | #BB5900 | #BB5900 |
| Solid #808482 | #6E7373 | #0078D4 |
| Orange + corner purple (25%) | #BB5900 | #BB5900 |
| Solid #2475CE | #0876CF | #0976CF |

The CIELAB calculation reproduces all seven roles for each of the six
chromatic observations (126 RGB channels, including the baseline and
both rectangle positions). The solid-blue intermediate differs from
the final Accent by one red unit. Feeding the final Accent back into
the calculation changes the generated shades; keep the intermediate
and final values distinct. Earlier transition captures had unchanged
DWM registry values, so do not use DWM as the sole source for current
shell color or assert that its value always equals a palette input.

The near-gray probe returns the full default blue UISettings ramp even
though its pre-shade candidate is #7E6E79. A second near-gray candidate
#8C6783 is accepted and normalizes to #8E6985. Their HSL saturations are
0.0678 and 0.1523 respectively. A provisional 0.15 fallback boundary
matches both observations and the existing custom CIELAB eligibility
rule, but the exact Windows cutoff is not established.

The Basic center/corner rectangle observations are identical despite
their different positions. The Refinement set also shows orange selected
when it occupies 25% against purple, 50% against purple, and 6.25%
against gray. These results exclude a pure largest-area-color lookup,
but do not identify the full selection or saliency algorithm. Solid
colored images also demonstrate hue/chroma changes before shade
generation: the image pixel RGB is not the intermediate RGB. No
historical patent supplies confirmed 26H2 extraction parameters.

The accent module's derive_automatic_palette() now applies the
provisional HSL saturation gate before the CIELAB shade calculation.
None and candidates below 0.15 return the default blue palette. A
candidate with adequate saturation but outside the reviewed HSL
lightness range raises an error rather than silently falling back.
The threshold is a measured candidate, not a confirmed native constant.

The refinement report is preserved in
[windows11-26h2-wallpaper-probes-refinement.json](windows11-26h2-wallpaper-probes-refinement.json).
Across its baseline and eight probes, the low 24 bits of the raw
HKCU\\Control Panel\\Desktop\\ImageColor DWORD match the low 24 bits
of DWM ColorizationColor. ColorizationAfterglow also matches
ColorizationColor in every capture. The upper ImageColor byte varies from 0x8A to 0xAF. A schema-5 native
COM diagnostic on the Bloom baseline returned 0xAF2475CE, exactly
matching ImageColor before and after the call. Its alpha is 175, and
its RGB matches DWM ColorizationColor. This confirms the native
ARGB/ImageColor relationship for this wallpaper on build 26300.9974.
The other eight probes were not individually checked through COM, so
do not generalize this result to every probe or Windows build. Together,
the matching RGB values link the native result, ImageColor and DWM
candidate used by the seven-color calculation. The runtime still does
not interpret the alpha byte.

For eight chromatic captures, passing the ImageColor low 24-bit RGB
through derive_automatic_palette() reproduces all seven UISettings
roles exactly (56 role colors, 168 RGB channel values). The low
saturation purple-muted-05 candidate is the single fallback. The
#8C6783 sample is the closest accepted sample above the provisional
threshold. The AccentPalette's first seven slots match the same API
colors in their established order. All probes had two stable captures,
and the original wallpaper path and palette were restored.

LiteStep's [reverse-engineered private wallpaper interface](https://github.com/lsdev/LiteStep/blob/master/litestep/DesktopWallpaper.cpp)
reads ImageColor in its GetWallpaperColor method, but the source itself
labels the interface private and contains a TODO about computing the DWM
colorization value. This corroborates the registry read path only. It
does not document how Windows selects ImageColor from wallpaper pixels.
Microsoft's [TS_ACCENTCOLOR protocol structure](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-rdperp/bc6975ee-c630-4414-ba10-04eecbb6fccc)
documents the DWM ColorizationColor, Afterglow and AccentPalette fields,
not the ImageColor extraction formula.

The automatic shade stage is now validated against nine settled
observations including the baseline. The wallpaper pixel-to-ImageColor
selection algorithm, exact saturation cutoff, and spatial/color
weighting remain unresolved. Keep derive_automatic_palette()
disconnected from runtime until the image extractor and global palette
ownership are resolved. An extraction error must never be converted
into a default-blue no-candidate result.

### Extraction refinement

The Basic captures constrain the image-to-intermediate stage but do not
identify its function. For example, normalizing the pure purple and
orange pixel colors through the existing custom CIELAB function yields
#A25D8F and #C15A00, not the measured automatic intermediates #B25098
and #B75B00. The pure blue pixel #2475CE is unchanged by that custom
normalization but gives #0876CF in automatic DWM colorization.
The five distinct chromatic intermediate colors (including Bloom)
have CIELAB L* values near 49, although the source pixels differ in
lightness and chroma. This constrains a candidate normalization stage,
not its precise formula. The raw area-weighted mean RGB of the
orange/quarter-purple images is about #E78023, unlike the observed
#BB5900; a subsequent nonlinear transform or clustering stage remains
possible.

A [third-party shell implementation](https://github.com/lsdev/LiteStep/blob/master/litestep/DesktopWallpaper.cpp)
uses the registry value HKCU\\Control Panel\\Desktop\\ImageColor
as its wallpaper-color readout. This is a research lead, not a
documented Windows 26H2 contract. The accent capture script schema 5 records ImageColor and DWM
ColorizationAfterglow in addition to the existing fields, preserving
missing values as null and raw DWORDs. Its opt-in native COM diagnostic
records the returned ARGB/alpha and compares them with ImageColor before
and after the call and DWM RGB. The bulk wallpaper-probe collector
invokes the private method only when explicitly requested.

The existing collector accepts -ProbeSet Refinement, which requires
schema 4 and produces eight new controlled images without repeating
the Basic set. The maintainer supplied the complete report, which is
preserved in the curated fixture linked above:

| Probe | Purpose |
| --- | --- |
| #512E48 and #D1AEC7 | Change lightness at approximately the original purple's hue and saturation |
| #83767F and #8B6E83 | Low HSL saturation near 0.05 and 0.12 at the original purple's lightness |
| #C1389B | Higher saturation near 0.55 at the original lightness |
| Quarter orange on purple | Reverse the 25/75 area ratio of the Basic pair |
| Half purple on orange | Equal area competition |
| Small orange on gray | Test a colored region near 6.25% against a near-gray background |

The image recipes use exact 8-bit RGB and integer rectangle bounds.
The stated HSL coordinates and area fractions are approximate after
rounding. No threshold is inferred before the results are observed.
The Basic mode remains available for old captures; new reports use
schema 2 with a probe_set field. The refinement uses the same original
wallpaper restoration, integrity and stable-observation logic.

Run both updated scripts from the same VM folder, with Automatic accent
and a static Picture background:

```powershell
.\capture-windows-wallpaper-probes.ps1 -ApplyTemporarily -ProbeSet Refinement
```

Submit only the new wallpaper-probes.json. Do not replace or recapture
the completed Basic report. If ImageColor is absent, the report still
provides the remaining observations. Do not make a runtime extractor
or calibrate an image-specific lookup until the candidate transform
has been checked against independent samples.

### Extraction probe set

The collector now accepts `-ProbeSet Extraction`. This set separates
color selection from the already measured shade-generation stage. Its
solid red, green and blue inputs have approximately equal CIELAB L* 50
and HSL saturation 0.75. The muted-red input keeps the red hue and
approximately the same CIELAB lightness, with HSL saturation 0.15.

A 2010 Microsoft patent, [US8847973B2](https://patents.google.com/patent/US8847973B2/en),
describes a historical candidate for automatic wallpaper color selection:
filter near-black, near-white and near-gray pixels, group similar RGB
pixels into buckets, discard buckets below about 1% of the remaining
colored pixels, then select the bucket with the greatest average RGB
channel span. Its example also derives colorization alpha from average
per-pixel channel span. The patent's example alpha constants differ
from the values reported by later shell32 reverse engineering. It is a
research lead, not proof that Windows 11 26H2 uses the same algorithm.

The mixed images test orange area ratios of approximately 0.5%, 1%, 2%
and 4% against purple to examine the patent's proposed bucket cutoff.
The other images test vivid-red area ratios of 6.25%, 25%, 50% and 75%
against muted red. Two images compare 25% red with 75% green, then
reverse the ratio. A final corner-position sample repeats the 25% red
and 75% green composition away from the center. The report also
preserves ImageColor alpha for comparison with the average channel-span
model. These observations distinguish bucket eligibility, color-span
ranking, saturation/chroma preference, hue bias, area weighting and
spatial weighting without assuming any of those mechanisms is used by
Windows.

The Extraction set requires capture-windows-accent.ps1 schema 4 or newer
so the report includes ImageColor. It does not call the private native
COM diagnostic. Run it in the same disposable Windows VM with Automatic
accent and a static Picture background:

```powershell
.\capture-windows-wallpaper-probes.ps1 -ApplyTemporarily -ProbeSet Extraction
```

Submit only the new report. Preserve the Basic and Refinement fixtures.
The collector records every exact image recipe, source hash, stable
observation and restoration result. If a palette does not change, the
sample remains in the report as an ambiguous observation rather than
being discarded.

### Extraction results: Windows 11 26H2 build 26300.9974

The uploaded [Extraction report](windows11-26h2-wallpaper-probes-extraction.json)
contains 15 settled probes at 1280x800. All source and registered wallpaper
hashes match. Fourteen observations reached two stable captures; the
75%-red/25%-muted-red image reached 18 observations without changing the
palette from the preceding 50/50 image. Preserve that unchanged result as
a negative observation. The original wallpaper path and baseline palette
were both restored. In all 15 captures, the low 24 bits of ImageColor
match DWM ColorizationColor exactly. The private native COM method was
not requested in this run, so the registry alpha bytes are not yet
independently confirmed as native COM alpha.

| Controlled image | Patch area | ImageColor RGB | ImageColor alpha |
| --- | ---: | --- | ---: |
| Solid vivid red | — | #D24444 | 175 |
| Solid vivid green | — | #008700 | 175 |
| Solid vivid blue | — | #6868CC | 175 |
| Solid muted red | — | #956767 | 161 |
| Orange on purple | 0.5% | #B5518B | 175 |
| Orange on purple | 1% | #B65281 | 175 |
| Orange on purple | 2.03% | #B7527D | 175 |
| Orange on purple | 4% | #BC535C | 175 |
| Vivid red on muted red | 6.25% | #C54E4E | 169 |
| Vivid red on muted red | 25% | #D24444 | 175 |
| Vivid red on muted red | 50% | #D44343 | 175 |
| Muted red on vivid red | 25% | #D44343 | 175 |
| Red on green | 25% red / 75% green | #008700 | 175 |
| Red on green | 75% red / 25% green | #D24444 | 175 |
| Red on green, corner | 25% red / 75% green | #008700 | 175 |

The 0.5%, 1%, 2.03% and 4% orange patches move ImageColor gradually
away from the Basic solid-purple DWM candidate (#B25098) rather than
producing a clear 1% discontinuity. A 25% orange patch on purple in the
Refinement report does produce the orange-family candidate. These results
do not support a simple hard 1% cutoff as the whole selection rule.

The 25% red / 75% green sample selects green even though red has the
larger raw channel span (177 versus 118). Reversing the areas selects
red. Moving the same 25% red patch from the center to the corner does
not change the selected green-family result. This contradicts the
literal historical patent embodiment that selects the remaining bucket
with the greatest average channel span after a minimum-population filter.
The patent is a useful historical lead, not a 26H2 implementation
specification. See [US8847973B2](https://patents.google.com/patent/US8847973B2/en).

The Scoring report rejects both simple candidate scores tested so far.
For red #E13030 (channel span 177) against green #148A14 (span 118),
the observed switch lies above 32.5% red and at or below 35% red.
The linear score `population × channel span` predicts a 40% tie, and
the squared score `population × channel span²` predicts 30.77%.
Both predictions fall outside the observed interval. A power-law score
with an exponent between roughly 1.53 and 1.80 could fit this pair, but
one pair does not establish that model.

The equal-lightness orange/purple samples do not behave like a simple
winner-takes-one-bucket selection. As the orange patch grows from
13.984% to 22.5%, native ImageColor moves gradually from #BA5463 to
#BF534A. This could reflect merging similar-color buckets, a continuous
weighted representative, or another color-space transformation. The
report does not distinguish those mechanisms.

The historical Microsoft patent describes filtering near-neutral pixels,
grouping similar RGB values by per-channel ranges, averaging each group,
discarding groups below a population threshold, and selecting the
remaining group with the largest average channel span. Its detailed
embodiment is not a specification for Windows 11 26H2: the observed
red/green winner boundary contradicts its literal maximum-span selection
rule, and the current report does not identify the 26H2 grouping distance.
The new ScoringRefinement probes hold lightness and channel span nearly
constant while varying hue distance to test whether a similarity boundary
explains the gradual orange/purple results. See
[US8847973B2](https://patents.google.com/patent/US8847973B2/en).

The native Alpha is now directly confirmed for all 19 Scoring samples.
For solid near-L*=50 red samples, the measured pairs are:

| Source channel span | Native Alpha |
| ---: | ---: |
| 12 | 137 |
| 24 | 149 |
| 36 | 161 |
| 37 | 161 |
| 47 | 171 |
| 49 | 173 |
| 50 | 175 |
| 51 | 175 |

These values are close to `min(175, 125 + channel span)`, but spans
37, 47 and 49 are each one below that expression. The previous Extraction
set also showed a one-unit discrepancy. The native API confirms the
alpha byte itself, not its exact calculation. The new sweep adds
near-L*=50, hue-zero samples with spans 32, 34, 35, 38, 40, 44, 46, 47,
48, 49 and 52. Keep the formula unresolved.

The UI Settings Accent also has a separate low-chroma fallback. At
source spans 12 and 24, DWM/ImageColor updates to #806E6E and #896B6B,
but UI Settings Accent remains #0078D4. At span 36, Accent changes to
#976969. The next sweep brackets this transition as well; do not assume
that the UI Accent and DWM color are always identical.

### Boundary probe results

The uploaded [Boundary report](windows11-26h2-wallpaper-probes-boundary.json)
contains 12 settled probes at 1280x800. All 12 private COM calls returned
HRESULT 0x00000000. Native ARGB matched ImageColor before and after the
call, native RGB matched DWM ColorizationColor, and the call changed no
ImageColor value. All source and registered wallpaper hashes match.
The original wallpaper path and palette were restored.

| Probe | Source channel span or patch area | Native ARGB | Result |
| --- | ---: | --- | --- |
| Solid muted red | 37 | 0xA1956767 | alpha 161 |
| Solid muted red | 48 | 0xADA46161 | alpha 173 |
| Solid muted red | 50 | 0xAFA75F62 | alpha 175 |
| Red on green | 37.5% red | 0xAFD24444 | red family |
| Red on green | 40% red | 0xAFD24444 | red family, unchanged palette |
| Red on green | 42.5% red | 0xAFD24444 | red family, unchanged palette |
| Orange on purple | 20% orange | 0xAFC65113 | orange family |
| Orange on purple | 21.25% orange | 0xAFC55213 | orange family |
| Orange on purple | 22.5% orange | 0xAFC4530E | orange family |

The red-on-green results move the observed winner boundary below 37.5%,
not at the linear model's 40% prediction. The orange-on-purple result
already moves into the orange family at 20%, below the linear model's
21.30% prediction. Three captures reached 18 stable observations with
no palette change; these are retained as negative observations rather
than discarded.

### Boundary probe set

The collector accepts `-ProbeSet Boundary`. It was designed around the
earlier linear-score hypothesis and its results reject that hypothesis.
The three solid colors also supplied direct native-alpha measurements.
Use `-IncludeNativeWallpaperColor` only in the disposable Windows
reference VM. The private API is undocumented.

### Scoring results

The uploaded [Scoring report](windows11-26h2-wallpaper-probes-scoring.json)
contains 19 samples at 1280x800 on Windows 11 26H2 build 26300.9974.
All 19 native COM calls returned HRESULT 0x00000000. Native ARGB
matched ImageColor before and after the call, native RGB matched DWM
ColorizationColor, and no call changed ImageColor. Every source wallpaper
hash matched the registered wallpaper hash. The original wallpaper path
and palette were restored.

| Controlled image | Area | Native ARGB | UI Settings Accent |
| --- | ---: | --- | --- |
| Red on green | 30% red | 0xAF008700 | #038801 |
| Red on green | 31.25% red | 0xAF008700 | #038801 |
| Red on green | 32.5% red | 0xAF008700 | #038801 |
| Red on green | 35% red | 0xAFD24444 | #D24444 |
| Red on green | 37.5% red | 0xAFD24444 | #D24444 |
| Orange on purple, L*≈48 | 13.984% orange | 0xAFBA5463 | #BA5463 |
| Orange on purple, L*≈48 | 15% orange | 0xAFBA5461 | #BA5461 |
| Orange on purple, L*≈48 | 15.938% orange | 0xAFBC535C | #BC535C |
| Orange on purple, L*≈48 | 17.5% orange | 0xAFBB5459 | #BB5459 |
| Orange on purple, L*≈48 | 20% orange | 0xAFBB5552 | #BB5552 |
| Orange on purple, L*≈48 | 22.5% orange | 0xAFBF534A | #BF534A |

The red/green boundary is above 32.5% and at or below 35% red.
The 31.25%, 32.5% and 37.5% samples reached 18 stable observations
without changing the UI palette; these unchanged observations are
preserved rather than discarded.

The low-chroma alpha samples show that DWM/ImageColor and UI Settings
Accent can diverge. At spans 12 and 24, the native ARGB values are
0x89806E6E and 0x95896B6B, while UI Settings Accent remains #0078D4.
At span 36, Accent changes to #976969. This is a separate fallback
condition from native ImageColor extraction.

### Scoring refinement probe set

The collector now accepts `-ProbeSet ScoringRefinement`. It contains
29 controlled probes:

- Seven red/green ratios between 32.97% and 34.45%, narrowing the observed
  winner boundary.
- Eleven equal-lightness, near-equal-channel-span similarity probes.
  They vary hue distance and reverse the area ratio at the two widest
  hue separations. This tests whether similar colors are grouped before
  the representative color is calculated.
- Eleven near-L*=50, hue-zero solid colors with channel spans 32, 34, 35,
  38, 40, 44, 46, 47, 48, 49 and 52. These refine native Alpha and the
  low-chroma UI Accent fallback boundary.

Before applying any wallpaper, the collector now reopens each generated
BMP and verifies one background pixel and, where present, one patch
pixel against the authored RGB values. Each report sample records this
pixel validation alongside the image recipe and SHA-256.

Run it in the same disposable Windows VM with Automatic accent and a
static Picture background. Keep the schema-5
`capture-windows-accent.ps1` beside the collector:

```powershell
.\capture-windows-wallpaper-probes.ps1 -ApplyTemporarily -ProbeSet ScoringRefinement -IncludeNativeWallpaperColor
```

The private COM diagnostic is called once per settled sample, not during
the polling loop. Submit the new `wallpaper-probes.json` report. The
collector restores and verifies the original wallpaper and palette.

### Scoring refinement results

The maintainer supplied [29 ScoringRefinement samples](windows11-26h2-wallpaper-probes-scoring-refinement.json)
at 1280x800 on build 26300.9974. Every source/registered SHA-256 matched,
every sampled BMP background/patch pixel matched its recipe, and all 29
native calls returned S_OK with matching ImageColor before and after
the call and matching DWM RGB. The original path and palette were restored.

| Probe | Patch area | Native ARGB | UI Accent | Stable captures |
| --- | ---: | --- | --- | ---: |
| red-33pct-on-green | 32.969% | 0xAF008700 | #038801 | 2 |
| red-33_25pct-on-green | 33.203% | 0xAF008700 | #038801 | 18 |
| red-33_5pct-on-green | 33.438% | 0xAF008700 | #038801 | 18 |
| red-33_75pct-on-green | 33.750% | 0xAF008700 | #038801 | 18 |
| red-34pct-on-green | 33.984% | 0xAF008700 | #038801 | 18 |
| red-34_25pct-on-green | 34.219% | 0xAF008700 | #038801 | 18 |
| red-34_5pct-on-green | 34.453% | 0xAF008700 | #038801 | 18 |
| similarity-solid-hue0 | solid | 0xAFD44343 | #D44343 | 2 |
| similarity-solid-hue180 | solid | 0xAF008181 | #038282 | 2 |
| similarity-hue30-patch40 | 40.000% | 0xAFC74E35 | #C74E35 | 2 |
| similarity-hue60-patch40 | 40.000% | 0xAFC15333 | #C15333 | 2 |
| similarity-hue90-patch40 | 40.000% | 0xAFD24444 | #D24444 | 2 |
| similarity-hue120-patch40 | 40.000% | 0xAFD24444 | #D24444 | 18 |
| similarity-hue150-patch40 | 40.000% | 0xAFD24444 | #D24444 | 18 |
| similarity-hue165-patch40 | 40.000% | 0xAFD44343 | #D44343 | 2 |
| similarity-hue180-patch40 | 40.000% | 0xAFD44343 | #D44343 | 18 |
| similarity-hue150-patch60 | 60.000% | 0xAF008543 | #048644 | 2 |
| similarity-hue180-patch60 | 60.000% | 0xAFD44343 | #D44343 | 2 |
| alpha-l50-span-32 | solid | 0x9D926868 | #946A6A | 2 |
| alpha-l50-span-34 | solid | 0xA0936867 | #956A69 | 2 |
| alpha-l50-span-35 | solid | 0xA0936867 | #956A69 | 18 |
| alpha-l50-span-38 | solid | 0xA4986668 | #996769 | 2 |
| alpha-l50-span-40 | solid | 0xA59B6464 | #9D6666 | 2 |
| alpha-l50-span-44 | solid | 0xA99E6366 | #A06467 | 2 |
| alpha-l50-span-46 | solid | 0xABA06262 | #A26464 | 2 |
| alpha-l50-span-47 | solid | 0xABA06262 | #A26464 | 18 |
| alpha-l50-span-48 | solid | 0xADA06262 | #A26464 | 18 |
| alpha-l50-span-49 | solid | 0xADA06262 | #A26464 | 18 |
| alpha-l50-span-52 | solid | 0xAFA4615F | #A56260 | 2 |

The red/green series retains green through 441/1280 (34.453125%) red;
the preceding Scoring series returned red at 448/1280 (35%). The
unchanged outputs are not independent confirmations of recomputation.
Treat this as an observed interval, not an established native threshold.
The equal-span red/cyan pair produces red even when cyan covers 60%,
whereas the 150-degree patch selects green at 60%. The 30- and 60-degree
patches move the representative toward orange; 90–180-degree patches at
40% retain a red-family result. No universal hue-distance threshold or
population-only winner rule is established.

### JPEG preprocessing hypothesis

For the eight Scoring and eleven ScoringRefinement low-chroma solid
samples, an in-memory Pillow/libjpeg JPEG encode/decode at quality 85
followed by `min(175, 125 + floor(mean decoded channel span))` reproduces
all 19 observed Alpha bytes. Direct authored RGB gives seven one-byte
errors. Examples:

| Authored RGB | JPEG-decoded RGB (local experiment) | Native Alpha |
| --- | --- | ---: |
| #916F6F | #916F6E | 160 |
| #916E6E | #906E6D | 160 |
| #996B6B | #996B6B | 171 |
| #9A6B6B | #996B6B | 171 |
| #9B6B6B | #9B6B6B | 173 |
| #9B6A6A | #9B6B6B | 173 |

The same model matches the archived near-neutral purple solids, the two
uncapped mixed-color observations (small orange on gray and vivid red on
muted red), and the Boundary solid alpha samples. This is offline
analysis of synthetic recipes, not execution of Windows or project
acceptance tests. Multiple JPEG qualities fit the solids; the exact
codec, quality, scaling order and native analysis pixels are unresolved.
Windows maintains [transcoded and display-size wallpaper caches](https://www.winhelponline.com/blog/find-current-wallpaper-file-path-windows-10/).
Source/registered file hashes do not identify the rendered cache.

The UI Accent remains separate from native ARGB. Source span 32 has
native RGB #926868 and UI Accent #946A6A; source span 24 in the preceding
report has native RGB #896B6B and default UI Accent #0078D4. This supports
the provisional HSL saturation gate, not an exact cutoff.

### Cache isolation probe set

Use the same static Picture, Automatic accent, original blue wallpaper
and single-display VM. CacheIsolation requires the opt-in native
diagnostic and schema-5 accent collector:

```powershell
.\capture-windows-wallpaper-probes.ps1 -ApplyTemporarily -ProbeSet CacheIsolation -IncludeNativeWallpaperColor
```

The 16 probes comprise five red/green boundary and orientation probes,
five cyan/red area and orientation probes, four repeated low-chroma
solids and two new fallback-boundary solids. Before each probe the
collector verifies the original reference palette, native ARGB and
wallpaper hashes. Each result records the independent reference and
whether native ARGB changed from it. Results identical to the reference
remain inconclusive.

The collector reads TranscodedWallpaper and, when unambiguous, the
single display-size CachedFiles JPEG. It records format, dimensions,
SHA-256, interior pixel RGB and a nine-point solid-color uniformity
sample. For uniform sampled colors it records a predicted alpha.
Original reference caches expose metadata only; no file paths or image
bytes are exported. Missing, unreadable, ambiguous or changing caches
remain diagnostic results. Compare cache hashes and sampled colors with
the target and reference; a cache match alone cannot identify the
extractor input. No cache file or registry value is edited. Existing
wallpaper restoration remains in effect.

Keep the extractor and alpha model out of the KDE runtime until the
input preprocessing and representative-color selection are resolved.

### Cache isolation results (build 26300.9974)

The complete [CacheIsolation report](windows11-26h2-wallpaper-probes-cache-isolation.json)
contains 16 independent probes at 1280x800. Every probe changed native
ARGB from the verified blue reference, changed the palette, had two
stable captures, matched the source/registered wallpaper SHA-256, and
returned consistent native ARGB/registry RGB. All BMP sample pixels
matched their authored recipes. The original path and palette were
restored. The original TranscodedWallpaper was a 1920x1200 JPEG with
the same hash before every probe; all probe caches were 1280x800 JPEGs
with different hashes from that reference. The matching display-size
CachedFiles JPEG was missing in every observation.

| Probe | Decoded cache RGB (background / patch) | Native ARGB | UI Accent | Alpha from solid sample |
| --- | --- | --- | --- | ---: |
| isolated-red-low-left | #148914 / #E03030 | 0xAF008700 | #038801 | — |
| isolated-red-high-left | #148914 / #E03030 | 0xAFD24444 | #D24444 | — |
| isolated-red-low-right | #E03030 / #148914 | 0xAF008700 | #038801 | — |
| isolated-red-high-right | #E03030 / #148914 | 0xAF008700 | #038801 | — |
| isolated-red-high-top | #148914 / #E03030 | 0xAF008700 | #038801 | — |
| isolated-cyan-60-left | #BC5858 / #208484 | 0xAFD44343 | #D44343 | — |
| isolated-cyan-60-right | #208484 / #BC5858 | 0xAFD44343 | #D44343 | — |
| isolated-cyan-60-top | #BC5858 / #208484 | 0xAFD44343 | #D44343 | — |
| isolated-cyan-75-left | #BC5858 / #208484 | 0xAF008181 | #038282 | — |
| isolated-cyan-solid | #208484 | 0xAF008181 | #038282 | 175 |
| isolated-alpha-span-34 | #916F6E | 0xA0936867 | #956A69 | 160 |
| isolated-alpha-span-35 | #906E6D | 0xA0936867 | #956A69 | 160 |
| isolated-alpha-span-48 | #9B6B6B | 0xADA06262 | #A26464 | 173 |
| isolated-alpha-span-49 | #9B6B6B | 0xADA06262 | #A26464 | 173 |
| isolated-fallback-span-28 | #8B6F6E | 0x9A8F6968 | #916B6A | 154 |
| isolated-fallback-span-30 | #8D6F6F | 0x9B906969 | #926B6B | 155 |

The two red fractions were exactly 441/1280 (34.453125%) and
448/1280 (35%). At the lower fraction both orientations select green.
At 35%, red on the left selects red; red on the right or top selects
green. This contradicts the orientation-independent population/span
models and invalidates the previous interpretation of a universal
red/green area threshold. Sampling, resizing, compression boundaries
and scan/order-dependent grouping remain distinct explanations; these
observations do not establish intentional position weighting.

Cyan #208484 covering 60% selects red #D44343 in all three orientations,
and at 75% on the left selects #008181. Both source colors have channel
span 100, including after decoding the cache. A simple population
rule cannot reproduce this behavior. The older observations were not
merely carried over from the preceding sample.

All seven solids, including six with uncapped Alpha, match
`min(175, 125 + max(R,G,B) - min(R,G,B))` using their sampled decoded
cache RGB. In particular #9B6B6B and #9B6A6A yield the identical cached
JPEG hash and decoded RGB #9B6B6B, and the same native ARGB 0xADA06262.
The two source spans 34 and 35 both decode to span 35 and return Alpha
160. This is direct evidence of the relevant JPEG color quantization,
not proof of the native extractor's internal pixel buffer or scaling
order. All sixteen observations also match the seven-role CIELAB
shade equations (112 role colors, calculated offline from native RGB;
not a runtime or test-suite execution).

The two new red-family candidates #8F6968 and #906969 have HSL
saturation 39/247 and 39/249 respectively, both above the provisional
0.15 gate. Both produce non-default UI accents. The previous rejected
#896B6B has saturation 30/244; the previously accepted #8C6783 has
saturation 37/243. The new data do not narrow the tightest existing
cross-hue saturation bracket. Keep the gate provisional.

The existing sync-accent.py now exposes
`derive_wallpaper_alpha(range_sum, pixel_count)` for opaque,
already-preprocessed image statistics. It uses integer division,
rejects invalid statistics and returns a colorization-strength byte.
It does not load images, calculate the representative RGB, assign
surface opacity or alter KDE settings. No new dependency or separate
runtime theme is introduced. The calculation remains staged alongside
the shade functions, pending the unresolved image preparation and
representative-color algorithm. Do not unconditionally JPEG-encode
every image or use this helper for unknown/transparent/native fallback
conditions.

Next, investigate the native selection and normalization implementation
and the sampling geometry before requesting another broad empirical
sweep. The current evidence is sufficient to stage the alpha reduction
and preserve the orientation counterexamples, but not to claim exact
automatic-accent parity or enable a guessed extractor.

### Target-build extraction investigation

The existing theme regression suite preserves all 16 isolated
automatic palette observations, seven uniform-solid Alpha observations,
the cache collision and the orientation/area counterexamples.
The alpha reduction has integer rounding, ceiling and invalid-input
cases. These are reference-based regression cases, not desktop acceptance.

The maintainer supplied the exact running x64 shell32.dll from the
26H2 VM (OS build 26300.9974). Static PE inspection identifies:

- File version: 10.0.26100.9974 (the component's own version).
- SHA-256: 10560eff83911e165674adafd31e05450ca827f2b5800e91130823b1e854f5d0.
- CodeView PDB: shell32.pdb, GUID 64708141-4AA5-C991-B8A9-4F15C5BA6002,
  age 1.
- Matching public symbols could not be downloaded in the analysis
  environment. Names are assigned only where internal diagnostic strings
  identify them. The following addresses are RVAs in this exact file,
  not stable API addresses.

The internal diagnostic string for CWallpaperRenderer::ComputeImageColorizationColor
identifies its entry at RVA 0x4F34D4. It reaches the ImageColor update
routine at 0x1D340 and the actual calculation at 0x1D448. The per-image
data routine at 0x1246A4 clamps each analysis dimension separately to
256 and requests a 32-bit bitmap. Its producer and storage contract are
documented below. The initialization at
0x15E978 sets Alpha bounds 125 and 175 and retains the native failure
default 0xC4FFFFFF. The Alpha reduction includes all analysis pixel
positions in its denominator; pixels whose final bitmap fourth byte
is zero are excluded from the channel-span sum.

The branch identified by feature 41486951 is present in this exact
module. Its weighted-RGB routine (per-image accumulation in 0x1246A4,
reduction at 0x4F7B30) is materially different from the legacy 64-bin
path. For the weighted branch, the following is a mathematical description
of the observed operations:

- Normalize each RGB byte to 0..1.
- Starting at position zero in the analysis bitmap's storage order,
  sample every max(1, floor(width * height / 250)) pixels. The
  divisor is recovered from the unsigned reciprocal multiply and shift;
  see the corrected boundary analysis below.
- Assign a sample to its largest RGB channel, resolving ties in red,
  green, blue order. Let M = max(r,g,b), D = max(0.01, 3*M-r-g-b).
  Its weight is (r+g+b+2)*D.
- Each of the three groups accumulates total weight and all three
  weighted RGB channels. Select the group with greatest total weight,
  resolving equal group weights in the same order. Divide the weighted
  channel sums by that group's weight, multiply by 255 and truncate.
- Alpha is a separate reduction over the full analysis image, not the
  sampled RGB subset. Per-pixel weights/products are single precision;
  the group sums and final division are double precision.

This explains why the same channel span need not give the same weight.
For the decoded red #BC5858 and cyan #208484, the weights are about
2.6882 and 1.2395 respectively: an ideal two-solid sample population
would switch near 68.44% cyan. The 60% and 75% observations bracket this
prediction. The red #E03030 and green #148914 weights are about 4.4930
and 2.4722, yielding an ideal tie near 35.49% red. Fixed-stride sampling,
resampling and boundary pixels can change the sample populations relative
to the authored areas. The corrected sampling divisor now reproduces
all three 35%-left/right/top observations from both captured WIC inputs.
Do not add a coordinate bias or a fitted exponent.

The post-selection normalization follows RVA 0x1D9BF and the helpers
at 0x596E04..0x597484. It uses encoded-RGB weighted RMS brightness
B = sqrt(0.2126*r^2 + 0.7152*g^2 + 0.0722*b^2), distinct from the later
CIELAB shade stage. Its observed sequence is:

1. Bound B to 0.55..0.65 by proportional channel scaling, with byte
   clipping and truncation.
2. Increase each channel's distance from the integer brightness pivot
   floor(255*B) by a factor of 1.4, then clip and truncate.
3. Target 3.2:1 contrast against white using linear-light luminance
   (sRGB transfer threshold 0.03928). Adjust integer HLS lightness
   through a bounded search while retaining hue and saturation.
4. Bound encoded-RGB RMS brightness to 0.30..0.45 by proportional
   scaling again.

The imported HLS functions are confirmed as SHLWAPI.dll ColorRGBToHLS
and ColorHLSToRGB. They use an integer HLS range of 0..240. Exact
portable rounding equivalence for every RGB value is not yet established.
The normalization preserves the separately calculated Alpha byte.

Offline arithmetic on the seven sampled uniform cache observations,
including weighted single-precision products and truncation of the raw
representative, reproduces their native RGB results. This numerical
comparison supports the weighted branch for those observations; it
does not independently query the VM's live feature state. It also
does not establish full-image input preparation or exhaustive HLS parity.

The existing sync-accent.py stages the following single-image functions:
`derive_weighted_wallpaper_seed(pixels, width, height)` and
`normalize_weighted_wallpaper_seed(seed)`. They consume an already
prepared opaque RGB analysis buffer (up to 256 by 256). The first
returns raw weighted RGB and Alpha, the second returns normalized
RGB for the existing derive_automatic_palette() shade stage. Explicit
binary32 operations retain the observed intermediate quantization.
No new dependency, decoder, file lookup, display configuration write
or runtime palette owner is added. The existing regression suite now
also defines cases for the seven uniform cache references, mixed-color
selection, fixed-stride buffer order and invalid analysis input.
Do not treat the synthetic uniform buffers as recorded native pixels.

### Target-build bitmap preparation and multi-image reduction

Further static analysis of the same SHA-256-identified shell32 file
traces the image object constructor (RVA 0x22B270), its vtable at
0x60A8C8, size method at 0x1AE40, and bitmap method at 0x1AF90.
The decoder path at 0x4F7D34 creates a WIC decoder from a stream,
obtains frame zero, and obtains the image size through the oriented
bitmap source. The path also reads System.Photo.Orientation
(0x1B5BC) and maps orientation values to WIC flip/rotate flags.
This is not an unconditional image rotation on every format.

The per-image analysis routine invokes the bitmap method with the
independently capped dimensions and interpolation argument **one**.
This corrects the preceding interpretation of the call. At RVA 0x12476F
the fifth argument is set to 1 and stored at caller [rsp+0x20] at
0x1247A1. The callee retrieves that fifth argument at 0x1B01B and
passes it unchanged to IWICBitmapScaler::Initialize at 0x1B030.
The Windows SDK defines one as bilinear interpolation; zero is
nearest-neighbor. See [WICBitmapInterpolationMode](https://learn.microsoft.com/en-us/windows/win32/api/wincodec/ne-wincodec-wicbitmapinterpolationmode).
It requests the format whose GUID is
6fddc324-4e03-4bfe-b185-3d77768dc90e, identified in the
[Microsoft SDK header](https://github.com/microsoft/win32metadata/blob/main/generation/WinSDK/RecompiledIdlHeaders/um/wincodec.h)
as GUID_WICPixelFormat32bppBGR, not 32bppPBGRA. At 0x1B106 it
constructs a 32-bit BI_RGB DIB with negative height; at 0x1B23F it
copies pixels with stride width*4. The native reader at 0x1248AD
through 0x124CCE walks four bytes per pixel, across top-down rows,
using offsets 2, 1 and 0 as R, G and B. It skips positions whose
fourth byte is zero, but advances the sampling index even for those
positions. The weighted path does not unpremultiply the stored RGB,
unlike the legacy path. The requested BGR pixel format does not
establish how WIC populates the fourth byte for every source format.
Do not equate that byte to the original file's alpha channel.

At 0x4F7B30 the weighted reduction iterates the available image
objects and sums all four doubles in each of three groups before
selecting the overall largest group. It separately sums image area
and channel spans, so it must not average per-image Alpha or
normalized colors. Each bitmap starts its own sampling index at
zero. The reducer leaves the native fallback untouched if no group
has a positive accumulated weight. Failed image acquisition is not
a successful blank bitmap.

The staged portable function derive_weighted_wallpaper_bitmaps()
now accepts one or more tightly packed top-down 32-bit analysis
buffers, preserves the fourth-byte validity check, and reduces
per-image statistics. It reuses exactly the same weight arithmetic
as the existing opaque RGB entry point. It returns None for no
weighted group, and rejects empty input or invalid bitmap dimensions
and byte lengths. This explicit no-group result must not be fed to
the RGB normalizer. The function does not implement source alpha
conversion, monitor enumeration or native decoder fallback policy.

The earlier offline approximations of the nine mixed CacheIsolation
recipes gave eight of nine winner agreement. They used the incorrect
sampling divisor 1000, so that discrepancy cannot establish a decoder
or resampler mismatch. Pillow BILINEAR uses a wider filter for
downsampling than the measured four-point interpolation. The actual
stream selected by the native extractor remains unproven. The following
captured-buffer analysis isolates the arithmetic from source preparation.

### Focused WIC bitmap boundary capture

The existing collector accepts `-ProbeSet BitmapBoundary`, a subset
of CacheIsolation containing only the three already measured 35% red
orientations (left, right, top). It requires the original 1280x800
single-display reference, Automatic mode, and schema-5 accent
collector. It restores and verifies the original wallpaper between
probes and at completion, using the existing isolation safeguards.

For each settled synthetic BMP and matching synthetic
TranscodedWallpaper JPEG, the collector recreates the public WIC
decode path: a read-only stream, frame zero, independently capped
dimensions, interpolation mode 1, 32bppBGR conversion, and a
tightly packed top-down CopyPixels buffer. It rejects unexpected
dimensions or orientation metadata, changing file hashes, caches
identical to the reference, and mismatched interior colors.
The source and cache buffers are independently hashed and gzip
compressed into the JSON report (the gzip_base64 field). The
fourth byte is retained exactly rather than assumed to be source
alpha or forced opaque. Original reference wallpaper pixels are
not captured. No extra executable or DLL is included, and no
cache or registry entry is edited.

This is a public API recreation, not an interception of the private
shell analysis buffer: the decoder's internal stream selection,
orientation and any feature-dependent handling may still differ.
Comparing the actual WIC bytes for the two input paths with the
measured native ARGB distinguishes arithmetic from source preparation.
The results below resolve the orientation counterexample. The runtime
remains disconnected pending source decoding and palette ownership.

Run from the folder containing the two capture scripts:

```powershell
.\capture-windows-wallpaper-probes.ps1 -ApplyTemporarily -ProbeSet BitmapBoundary -IncludeNativeWallpaperColor
```

Submit the new wallpaper-probes.json; there is no need to repeat
the other 16-probe or 29-probe collections. The original Windows
DLL and symbols remain outside the repository.

### WIC bitmap boundary results

The maintainer supplied the complete
[BitmapBoundary report](windows11-26h2-wallpaper-probes-bitmap-boundary.json).
All three targets were independently settled, native ARGB matched
the registry, and the original wallpaper and palette were restored.
All six gzip payloads decode to exactly 262,144 bytes; their SHA-256
values match the captured hashes. All 393,216 fourth bytes are 255.
This rules out skipped pixels or source-alpha handling for these
specific publicly recreated WIC buffers.

The source BMP buffers are reproduced exactly by a pixel-center
four-point bilinear sampler. For destination coordinate i, source
extent S and destination extent D, use (i + 0.5)*S/D - 0.5,
clamp the two neighboring source indices, and truncate the final
interpolated RGB value. Each dimension is capped independently at
256; do not preserve aspect ratio at this stage. Offline integer
arithmetic on the three original image recipes reproduces all
196,608 source-buffer pixels and all three SHA-256 values. In
particular the top boundary contains one row of #BA402A, rather
than #BB412B from round-to-nearest. This confirms this resampling
contract for the three opaque controlled BMPs, not for arbitrary
formats, color profiles or scaling ratios.

The portable `prepare_opaque_wallpaper_bitmap(pixels, width, height)`
function stages this bounded pixel-center interpolation on packed,
already oriented, opaque RGB8 bytes. It emits top-down BGRX with
marker 255 and has no decoder, JPEG encoder or runtime side effects.
The existing theme suite contains regression cases for the captured
source buffers, both sets of hashes, marker values, Alpha and the
independent native seven-shade palette. The suite has not been run
during routine development.

### Corrected weighted sampling divisor

The previous reconstruction misread the reciprocal integer division.
Reinspection of the SHA-256-identified target shell32 confirms the
unsigned 32-bit pixel-count multiplication at RVA 0x124870..0x12487E:
the multiplier is 0x10624DD3, the high 32 bits of the product are
shifted right by four, and the result is clamped to at least one at
0x124882..0x124885. For the supported analysis area (1..65,536),
this is exactly floor(pixel_count / 250), not /1000. In particular,
65,536 positions give a stride of 262 and 251 samples, including
index zero. The loop increments the index at 0x124CCB even for a
skipped pixel. No color weight, normalization or Alpha constant
needs to change.

Using this corrected divisor on the three captured JPEG WIC buffers
gives the following offline weights. These are calculated from the
recorded bytes, not internal accumulator readings from shell32.

| Red orientation | Red samples | Green samples | Red weight | Green weight | Winner |
| --- | ---: | ---: | ---: | ---: | --- |
| Left | 90 | 161 | 404.37 | 398.03 | Red |
| Right | 85 | 166 | 378.66 | 410.39 | Green |
| Top | 88 | 163 | 393.13 | 402.97 | Green |

The weighted RGB and existing normalization also reproduce the
complete native ARGB on all six recorded WIC buffers:

| Red orientation | Source BMP seed | JPEG seed | Source BMP ARGB | JPEG ARGB | Native ARGB |
| --- | --- | --- | --- | --- | --- |
| Left | #E13030 | #DF3030 | 0xAFD24444 | 0xAFD24444 | 0xAFD24444 |
| Right | #148A14 | #148914 | 0xAF008700 | 0xAF008700 | 0xAF008700 |
| Top | #148A14 | #148813 | 0xAF008700 | 0xAF008700 | 0xAF008700 |

The previously unresolved orientation counterexample is resolved by
the native sampling divisor, with no aspect-ratio change, cache
invalidation hypothesis, arbitrary position bias or fitted exponent.
The synthetic 256x160 alternative proposed earlier is not needed
and is not implemented. Both input streams produce identical final
ARGB for these three targets, so this does not identify the renderer's
actual stream or prove decoder equivalence for all images.

The correction is shared by the opaque RGB and BGRX/multi-image entry
points. The existing regression definitions now distinguish stride
eight from stride two at 2,000 positions, and compare the full native
ARGB for each of the six recorded buffers. The suite has not been
executed. The recorded fixture is unchanged.

The staged weighted color calculation, normalization, full-image
Alpha and seven-shade generation now have direct captured-buffer
support for the previously failing orientation case. Further work
should connect source decoding and orientation handling without
unconditionally re-encoding input images, establish the actual
automatic-accent ownership contract, and preserve manual and
wallpaper-following behavior across the KDE renderers. Exact parity
for arbitrary images, transparency, multi-monitor source selection,
and live application color refresh remains unverified. No installed
theme behavior changes in this correction.

### Local wallpaper file analysis and renderer roles

The same calculation module now exposes a complete read-only file
analysis pipeline. It uses Pillow (already in the NixOS theme runtime
and native-resource importer) for local BMP, JPEG, PNG and WebP still
images, applies EXIF orientation before calculating the analysis
dimensions, prepares the existing 256-pixel-capped bitmap, combines
all supplied image statistics, and then derives the normalized RGB,
Alpha, and seven-role candidate palette. The original file is never
modified or recompressed. Untagged images use their decoded RGB values.
Tagged RGB and Gray8 images use one fixed-point RGB8-output executor.
RGB uses independently generated matrix/TRC tables or full-domain
verified supplemental data. D50 Gray8 v2/v4 monitor profiles use the
independent gray grid and shared input-curve generator. Only the two
original gray gamma controls have measured native output hashes; the
sampled and v4 parametric extensions follow the common native curve
dispatch. The former Little CMS runtime approximation is removed;
unsupported profile and
pixel-format combinations are explicit decoder errors. Arbitrary ICC
and non-RGB native parity have not been established.

The opt-in command accepts explicitly selected files, not an assumed
primary containment or wallpaper-package directory. A source with
more than 40 million pixels, animation, unsupported pixel format,
invalid orientation, unsupported transparency or a failed decode is an
error, not a request to use a guessed accent. Opaque RGBA and
untagged indexed/gray images within the supported format contract can
be converted to RGB. Tagged Gray8/GrayAlpha8 images retain their
single-channel samples until ICC conversion. Untagged transparent PNG
and supported tagged PNG share premultiplied resampling and the
measured candidate fixed-point unpremultiplication rule. GrayAlpha8
and Gray8 PNG transparency keys compose the independent gray transform
with the measured RGB-alpha path; their full Windows decode/cache
ordering still needs native measurement. Unsupported profile families
and non-PNG transparency remain outside the reviewed contract. Nonzero resized alpha is a validity
marker, not a weight in the native analysis loop.

```bash
python3 -I scripts/theme/sync-accent.py --analyze-wallpaper /absolute/path/to/image.jpg
```

Multiple file arguments use the existing pooled statistics path.
The JSON distinguishes weighted_seed, colorization_argb,
colorization_alpha, palette and mode_accents. The latter uses
AccentLight2 for dark and AccentDark1 for light, as observed in
the WinUI resources. Both modes consume the same computed palette.
The command performs no KDE, Kvantum, wallpaper or theme-setting
writes. It is shipped in the existing appearance script; no daemon,
new application or independent color theme is installed. The
original directory/mode/selection invocation remains unchanged.
The regression definitions cover EXIF rotation, opaque RGBA,
transparent PNG gradients and mixed-alpha edges, unverified tagged and
non-PNG transparency rejection, size bounds, the seven uniform
reference colors as lossless files, mode-role mapping and pooled
file analysis. They have not been executed.

Plasma 6.8.3 still owns the live effective color: its
[wallpaper reader](https://github.com/KDE/plasma-workspace/blob/v6.8.3/wallpapers/image/plugin/utils/mediaproxy.cpp)
uses the mode-dependent metadata color when present, and
[plasma-apply-colorscheme](https://github.com/KDE/plasma-workspace/blob/v6.8.3/kcms/colors/plasma-apply-colorscheme.cpp)
routes accent changes through applyScheme. The
[Colors KCM](https://github.com/KDE/plasma-workspace/blob/v6.8.3/kcms/colors/colors.cpp)
requests the wallpaper accent through PlasmaShell's color method.
Supplying a WinUI shade as a KDE accent does not guarantee an identical
effective selection role: KDE's applicator blends some backgrounds.
A tray palette-change observer that also writes the global accent
would create a second authority competing with the wallpaper provider.
The installed controller checks the active native accent settings before publishing a Windows ramp. The NixOS Kvantum 1.1.9 integration also reads the committed asset hashes in the application's existing mode.

### Native automatic-color diagnostic

OpenGlass reverse-engineers the private
`IDesktopWallpaperPrivate::ComputeImageColorizationColor` shell32 method.
Its implementation obtains a native ARGB result, retains its alpha, then
requests the Shell's forced wallpaper transition and reads the applied
DWM RGB. The project explicitly avoids reproducing Windows' image-analysis
algorithm. See its [private interface declaration](https://github.com/ALTaleX531/OpenGlass/blob/b6dcd558ca5d842ac0b0b065cfcf2d76def9f9d7/Common/DesktopWallpaper.hpp)
and [color hook](https://github.com/ALTaleX531/OpenGlass/blob/b6dcd558ca5d842ac0b0b065cfcf2d76def9f9d7/OpenGlassThemeExtension/ColorHooks.Shell.cpp).
Its documented shell32 builds are 10.0.17763.737 and 10.0.26100.9549.
This is reverse-engineered, undocumented behavior, not a 26H2 API contract.

The baseline capture on build 26300.9974 returned 0xAF2475CE. Its full
ARGB matched ImageColor before and after the call, including alpha 175,
and its RGB matched DWM ColorizationColor. The call did not change
ImageColor in this observation. This confirms the registry/private-method
relationship for the baseline wallpaper only; it does not establish the
same result for every probe or another Windows build.

The [accent capture script](../scripts/capture-windows-accent.ps1)
has an opt-in `-IncludeNativeWallpaperColor` diagnostic. It invokes only
the private color-computation method, and only after both registry mode
values confirm Automatic. It does not send the forced Shell refresh
message, change wallpaper or explicitly write registry values. The
private method's internal side effects are undocumented, so the capture
records ImageColor both before and after the call. It also records the
HRESULT, native ARGB/alpha and comparisons against DWM RGB. Manual or
conflicting mode is skipped. An unavailable private interface is
reported without discarding the ordinary capture. This diagnostic is
opt-in for the bulk probe collector and is not used by the Linux runtime theme.

Run it once on the current Automatic wallpaper:

```powershell
.\capture-windows-accent.ps1 -AccentMode Automatic -IncludeNativeWallpaperColor
```

The complete simultaneous schema-5 baseline, including its registry and
native ARGB evidence, is preserved in the
[CacheIsolation report](windows11-26h2-wallpaper-probes-cache-isolation.json).
Keep it separate from the earlier schema-2 automatic capture in
[windows11-26h2-accent-captures.json](windows11-26h2-accent-captures.json),
whose DWM values had not yet changed from manual orange. Do not attach
a later native result to those older registry values.

### Native colorization-strength alpha

A second OpenGlass reverse-engineering note describes the native image
analysis alpha for shell32 10.0.17763.737 and 10.0.26100.9549:

`alpha = min(175, 125 + floor(rangeSum / pixelCount))`

`rangeSum` sums `max(R,G,B) - min(R,G,B)` over nontransparent
analysis pixels. `pixelCount` uses the full analysis image area, including
skipped transparent pixels. The inspected implementation caps each
analysis dimension at 256 pixels and combines sums/counts across images.
The note distinguishes legacy unpremultiplication from the 26100
feature-41486951 weighted-RGB path. It also records a native fallback
alpha of 196 and cached `ImageColor` during initialization. See the
[reverse-engineered analysis notes](https://github.com/DreY85/OpenFluidGlass/blob/49dd5176acd3afabc03066680a2de2b59296e472/OpenGlassGUI/Configuration.design.md)
and [native implementation notes](https://github.com/DreY85/OpenFluidGlass/blob/49dd5176acd3afabc03066680a2de2b59296e472/OpenGlassThemeExtension/Design.md).

This describes colorization strength derived from image RGB statistics,
not the wallpaper file's transparency. It is a third-party reverse
engineering result for two older shell32 builds, not a guaranteed 26H2
contract. Our refinement samples support it: the small orange region on
gray predicts alpha 144 and reports 0x90; the two mixed orange/purple
images exceed the 175 cap and report 0xAF; the two muted purple samples
predict 138 and 154 and report 0x8A and 0x9A. The two solid samples with
channel range 35 report 159 rather than the simple formula's 160, so
the exact 26H2 preprocessing/rounding remains to be checked. This makes
the varying ImageColor high byte consistent with native colorization
strength, not image transparency.

The optional COM diagnostic has confirmed the baseline relationship.
That baseline alpha is at the 175 ceiling, so it does not independently
validate the alpha formula. The lower alpha values in the refinement
set remain registry observations, not separate COM checks. No alpha
formula is wired into the runtime theme. The wallpaper-to-RGB selection
algorithm remains a separate unresolved problem.

### Capture procedure

For maintainer acceptance, use a single display and a static picture in
the target Windows VM. Set Personalization > Colors > Accent color to
Automatic, select the exact original wallpaper used on KDE, and let the
wallpaper transition finish. Run the read-only
[accent capture script](../scripts/capture-windows-accent.ps1) from
Windows PowerShell 5.1:

```powershell
.\capture-windows-accent.ps1 -AccentMode Automatic -SourceWallpaper 'C:\path\wallpaper.jpg' |
    Set-Content -Encoding UTF8 accent-automatic.json
```

The script reports the Windows build, both appearance modes, wallpaper
placement, display size, all seven runtime accent colors, and raw values
from both known AutoColor registry locations. Its optional native-color
diagnostic is described above and is disabled by default. It also records the raw
Explorer AccentPalette bytes, DWM/Explorer accent DWORDs, and the base
Accent observed through UISettings when Manual is selected. It hashes the
registry-selected wallpaper file and, when supplied, the original image.
The two hashes may differ because Windows can transcode the wallpaper.
The original path is operator-supplied; it is not independently proven to
be the active image. No file paths are included in the JSON. The command
argument and registry-derived mode are separate fields. A missing or
conflicting registry value remains unknown. Two identical snapshots one
second apart reject observed changes but cannot prove the shell has
finished updating. Use the script only after the visible transition has
settled.

Capture the same original image in both modes, then repeat with warm,
green, purple and neutral images. Keep the display and wallpaper
placement fixed. Use a unique JSON filename for each capture. For manual
accent references, select a known color in Windows and run the following
command. The script records the actual base Accent from UISettings;
the optional ManualColor argument records the operator-entered RGB. The
schema 3 and later report a match or mismatch without rejecting the capture:

```powershell
.\capture-windows-accent.ps1 -AccentMode Manual -ManualColor '#9F5A8C' |
    Set-Content -Encoding UTF8 accent-manual-custom.json
```

Repeat manual captures for several distinct hues and the default blue,
in both light and dark modes. These independent references separate
wallpaper-to-base-color extraction from base-to-shade generation. Compare
Windows AccentLight2 in dark mode and AccentDark1 in light mode against
the live KDE selection role and screenshots. Do not fit a purported
native algorithm from only the default blue example. Record unseen images
and manual colors separately for eventual acceptance. Record only the input classes and boundary colors covered by the native observations.

On KDE, keep Dolphin and Konsole open during a manual accent change, a
wallpaper change, and both dark/light switches. Verify slider, checkbox,
progress, focus, selection, glow and taskbar indicator colors. Check an
existing window and a newly opened window separately. The destination
Kvantum atlas is synchronized before a mode switch, but same-style
reload is not guaranteed by Qt/Kvantum. Do not mark that condition
passed until it is observed in the target session. No application
restarts or temporary fallback-style cycling are part of this check.
