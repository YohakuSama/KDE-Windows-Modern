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

- Both views use the same anchored outer geometry: 560x640 or 768x720
  logical size, clamped to the work area. Search must not enlarge the
  popup or move its anchor.
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
  indicator, 6px expanded thumb, native attached dragging. Wheel detents
  accumulate to 120 units; handle continuous pixel gestures correctly.

## Calendar and notifications

- One native Plasma popup with bounded positive layout hints and separate
  history/calendar cards. Keep conditional empty states/actions and a
  stable footer. No second popup or whole-flyout Flickable.
- Regional time/date defaults, explicit 12/24-hour preferences, uppercase
  English AM/PM in explicit mode, seconds off by default.
- Preserve translated calendar labels, actual history, events, optional
  agenda and time zones. Clear history without cancelling transfer jobs.
  Focus owns only its own inhibition; keep native DND state.
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
