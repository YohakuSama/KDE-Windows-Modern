# Current panel geometry and input contract

Compare the owner-provided Windows 11 build at the same display scale,
language, light/dark variant and settings. Use Qt logical coordinates.
Current implementation values are provisional until verified on the desktop.
Use the [project quality ledger](PROJECT_QUALITY_LEDGER.md) for task
status and unresolved requirements. This contract records implementation
geometry and interaction constraints, not a second progress inventory.

## Taskbar

- Standard panel height: 48 logical pixels. Start, Search, Task View and
  tasks use a 30px icon canvas constrained by their cells, with a 4px
  total inset. `core/design/taskbarGeometry.js` is the shared source of
  this canvas rule; each applet receives a self-contained native copy.
  Preserve aspect ratio and optical padding. Let Qt apply
  fractional scaling; do not crop app artwork. Constrain the canvas by both
  cell dimensions and hide it when no usable extent remains. Task stripes
  use the available applet extent rather than their own grid's size. Check
  zero-task and first-task transitions, narrow/vertical panels, and manual
  multi-stripe settings without invalid or negative layout hints.
- Default tray glyph box: 16px. Ordinary cells: 32px. Core grouped cells:
  24px. Keep state-family scale, actual status, user spacing preferences,
  independent click targets, RTL and the native fallback representation.
  The older 18px and 20px tray experiments are superseded.
- One grouped hover surface per contiguous run of network, volume and
  battery cells. Keep real device availability and overflow semantics.
- Battery percentage defaults off and is independently configurable.
  Real backend level, charge and saver state drive the state renderer.
  It prefers the privately imported 26H2 SysBatt outline/fill assets and
  retains the reviewed legacy Windows glyph path when unavailable.
  The owner audit records the 38 imported outputs; installed coverage
  and actual optical/state parity remain open.
- Preserve native tooltip ownership, window preview lifecycle, compact
  close affordance and real app actions.

## Start and Search

- Start uses a 626x734 (Small) or 818x874 (Large, auto at screen width >= 1600)
  logical inner content surface inside the 8px KSVG dialog frame, matching
  Windows 11 26H2 `StartResources.xbf` outer extents (642x750 and 834x890),
  with a 25px inner margin (8 + 25 = 33px outer inset, leaving exact 576 = 6x96
  and 768 = 8x96 content columns). Search uses a wider 758x734 or 992x874
  logical inner content size (774x750 or 1008x890 outer), clamped to the same
  work area. Both use the same frame, height and vertical placement. Search home
  and results keep one stable Search size; entering or leaving Search may
  change the width. Narrow screens may clamp both to the same width.
- The full taskbar Search box opens at its own anchor with no duplicate
  input on the empty Search page; Start keeps its own top input.
  Start's native search actions live at applet scope, not button scope.
  The Search entry binds to the same-panel ready provider's open action
  and mirrored state together, watching native action registration and
  readiness without polling. Without a ready provider, it clears its
  mirrored state and does not launch an unrelated search backend.
- Preserve real Kicker/Milou actions, configurable Pinned/Recent/All,
  category/list/grid views, alphabetical navigation, user preferences,
  app previews and the footer. No dummy Windows services or promotions.
- Follow the system font and locale. Use reviewed original icon roles.
  The owner audit records all four original Search state outputs and
  the source can select the private PNGs. Verify local installation,
  state selection and optical bounds; the legacy mask is not 26H2 parity.

## Quick Settings

- One native popup and navigation stack, three tile columns, real hardware
  states, conditional availability and reachable extra rows. The 376px
  paginated card and 328px content group retain the existing 24px side
  insets. Mirror tile position, keyboard direction and drag targets
  together. Conditional page dots and a directional arrow occupy the
  trailing gutter, with no permanent painted scrollbar rail.
- The 178px media card and 12px gap have their own height budget. Keep
  media visible if one full tile row and the fixed controls still fit;
  later rows remain reachable through the existing pager. This constrained
  desktop adaptation needs reference acceptance.
- All three popup geometry copies reject stale panel/anchor rectangles
  from different outputs, and size limits distinguish unavailable display
  geometry from a genuinely small logical work area. Plasma retains final
  placement and its native available-screen clamp.
- Brightness and volume share the same groove bounds, current tile grid
  margins, equal 27px end slots and 18px thumb at normal UI scale. The
  output button uses the reviewed Speakers E7F5 role. Retain drag, wheel,
  keyboard and native route selection.
- Follow the Fluent scroll control baseline: 16px input region, 2px
  indicator, 6px expanded thumb, native attached dragging. Shared sliders
  accumulate 120 angle units per detent, use pixels instead when available,
  and emit one backend update per coalesced event. The 40-pixel gesture
  threshold and idle reset are provisional input tuning; verify on the
  target touchpad. Main and detail display sliders use the native normalized
  PowerDevil zero endpoint and reject unavailable brightness backends.
  When several brightness controls exist, the panel's connector type must
  identify exactly one control. An unknown or ambiguous match leaves the
  main track disabled and opens the existing per-display brightness page
  through the details button. A sole available control remains usable.
  Exact external connector matching awaits a native identifier mapping.
- The hidden tray grid and its popup consume one geometry plan: five
  columns, up to three visible rows, a bounded work area, and the existing
  16px scroll rail when needed. Short screens can scroll instead of
  clipping remaining icons. The native KSVG frame and shadow are retained;
  exact Windows overflow dimensions and material compositing remain open.
- Audio input/output lists retain a selectable row when the preferred
  device is absent but one real device is available. The main mute action
  is keyboard accessible, the switch knob follows native drag position,
  and mirrored sound-output chevrons follow the slider layout direction.

## Calendar and notifications

- One native Plasma popup with bounded positive layout hints and separate
  history/calendar cards. Default flyout card width is 336 logical pixels
  (matching Windows 11 26H2 `NotificationCenterFlyoutWidth = 360` minus the
  `12px` horizontal `NotificationCenterFlyoutMargin`, yielding the exact
  `312px` `NotificationCenterFlyoutActualWidth` inside the `12px` card
  section insets). Keep conditional empty states/actions, 32px minimum
  notification group headers (`GroupHeaderMinHeight`), 16px app icons
  (`AppLogoIconSize`) and a stable footer. No second popup or whole-flyout
  Flickable.
- Regional time/date defaults, explicit 12/24-hour preferences, uppercase
  English AM/PM in explicit mode, seconds off by default.
- Preserve translated calendar labels, actual history, events, optional
  agenda and time zones. Clear history without cancelling transfer jobs.
  Focus owns only its own inhibition; keep native DND state.
- Missing private system artwork uses the original action's short text
  where needed, never a silently substituted KDE icon. Genuine
  application icons remain untouched by the system glyph mapping.
  Shared system button and menu content explicitly masks imported
  monochrome SVGs using the active foreground; the native control still
  owns its background, padding, focus, check state and activation.
- Calendar wheel paging handles 120-unit detents and continuous pixel
  input without repeated inertia paging. Verify real touchpad gestures.

## Desktop acceptance

Compare real light/dark captures at 100%, 125%, 150% and 200%. Exercise
hover, wheel, drag, keyboard, input method, popup geometry, context menus,
preview lifecycle, actual device states and notification behavior.

Reference: [Windows icon construction](https://learn.microsoft.com/windows/apps/design/iconography/app-icon-construction),
[geometry](https://learn.microsoft.com/windows/apps/design/signature-experiences/geometry),
[typography](https://learn.microsoft.com/windows/apps/design/signature-experiences/typography),
[scroll controls](https://learn.microsoft.com/windows/apps/develop/ui/controls/scroll-controls),
[Start customization](https://support.microsoft.com/en-us/windows/experience/personalization/customize-the-windows-start-menu),
[taskbar customization](https://support.microsoft.com/en-us/windows/experience/personalization/customize-the-taskbar-in-windows),
[Plasma widget API](https://develop.kde.org/docs/plasma/widget/setup/),
[AppletPopup](https://api.kde.org/plasmaquick-appletpopup.html) and
[Kirigami WheelHandler](https://api.kde.org/qml-org-kde-kirigami-wheelhandler.html).

See [WINDOWS11_FIDELITY.md](WINDOWS11_FIDELITY.md) and
[NATIVE_ASSETS.md](NATIVE_ASSETS.md) for open acceptance and artwork tasks.
