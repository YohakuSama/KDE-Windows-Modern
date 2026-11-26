# Current panel geometry and input contract

Compare the owner-provided Windows 11 build at the same display scale,
language, light/dark variant and settings. Use Qt logical coordinates.
Current implementation values are provisional until verified on the desktop.

## Taskbar

- Standard panel height: 48 logical pixels. Start, Search, Task View and
  tasks use a 30px icon canvas constrained by their cells, with a 4px
  total inset. Preserve aspect ratio and optical padding. Let Qt apply
  fractional scaling; do not crop app artwork.
- Default tray glyph box: 16px. Ordinary cells: 32px. Core grouped cells:
  24px. Keep state-family scale, actual status, user spacing preferences,
  independent click targets, RTL and the native fallback representation.
  The older 18px and 20px tray experiments are superseded.
- One grouped hover surface per contiguous run of network, volume and
  battery cells. Keep real device availability and overflow semantics.
- Battery percentage defaults off and is independently configurable.
  Real backend level, charge and saver state drive the current compatibility
  drawing. The exact newer Microsoft artwork has not been identified;
  native visual parity remains open. Do not claim the drawing is original.
- Preserve native tooltip ownership, window preview lifecycle, compact
  close affordance and real app actions.

## Start and Search

- Start keeps its 560x640 or 768x720 logical content size. Search uses a
  wider 680x640 or 928x720 logical content size, clamped to the same work
  area. Both use the same frame, height and vertical placement. Search home
  and results keep one stable Search size; entering or leaving Search may
  change the width. Narrow screens may clamp both to the same width.
- The full taskbar Search box opens at its own anchor with no duplicate
  input on the empty Search page; Start keeps its own top input.
- Preserve real Kicker/Milou actions, configurable Pinned/Recent/All,
  category/list/grid views, alphabetical navigation, user preferences,
  app previews and the footer. No dummy Windows services or promotions.
- Follow the system font and locale. Use reviewed original icon roles.
  The newer colored Search artwork remains a fidelity blocker.

## Quick Settings

- One native popup and navigation stack, three tile columns, real hardware
  states, conditional availability and reachable extra rows. No redundant
  controls or permanent painted rail. Keep actual native input and routing.
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
  history/calendar cards. Keep conditional empty states/actions and a
  stable footer. No second popup or whole-flyout Flickable.
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
