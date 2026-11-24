# Panel geometry and input contract

Reference desktop: Windows Modern on Plasma 6.8.3 / Qt 6.12, Wayland, 150% output scale.

- Use Qt logical coordinates. A 48px panel occupies 72 physical pixels at 150%.
- Task icons and Start use a 28px logical canvas. Retain optical padding in the artwork. The Start SVG has a 64px canvas with a 56px painted area, which renders at 36.75 physical pixels at 150%; do not tighten the viewBox to the path bounds or apply an extra scale. The owner reported that the previous 24px canvas (31.5 physical pixels of painted area) was too small on a 48px logical panel. Do not force arbitrary third-party artwork into a cropped shape.
- Tray uses 16px logical icon boxes; do not use the task icon size or multiply by DPR.
- Use Plasma's native compact/full representations for digital clock; give the full representation explicit positive minimum/preferred/maximum layout hints. No second popup window, manual resize timers or saved-size overrides.
- Use Kirigami.WheelHandler for Flickable/ListView and attached Qt Controls scrollbars. It handles Wayland wheel delta conversion; use 120 logical pixels (three 40px rows) per detent for lists, at least one row per detent for quick settings. Native scrollbar dragging maps position to content range; no snapping or separate drag animation.
- A build/geometry formula check is not a GUI test. Run QtTest wheel/drag checks at QT_SCALE_FACTOR=1.5; verify the real calendar/notification surface and quick-settings behavior under Plasma before marking an integration build verified.

Upstream references:
- https://develop.kde.org/docs/plasma/widget/setup/
- https://api.kde.org/plasmaquick-appletpopup.html
- https://api.kde.org/qml-org-kde-kirigami-wheelhandler.html
- https://invent.kde.org/plasma/plasma-workspace/-/blob/master/applets/digital-clock/main.qml
- https://invent.kde.org/plasma/plasma-desktop/-/blob/master/applets/kickoff/KickoffListView.qml
- https://invent.kde.org/frameworks/kirigami/-/blob/master/src/wheelhandler.cpp
- https://github.com/Eisteed/menu-11-next/blob/master/contents/ui/MenuRepresentation.qml

Revision after owner comparison screenshots:
- Task icons use a 28 logical-pixel canvas and 87.5% maximum painted extent (36.75 physical pixels at 150%). Normalize real task icons by alpha bounds, preserving aspect ratio and the Start optical inset. Search and Task View share the 28px canvas and disable icon-size rounding. The new extent is a screenshot-driven adjustment pending live visual acceptance.
- Native symbolic status families use the union of actual font outline bounds and one isotropic transform per family. A 16 logical-pixel box has a maximum painted extent of 23 physical pixels at 150%. Signal levels do not resize independently. Battery remains wider than tall, as in the original artwork. Locate installed Windows Modern glyphs directly, falling back to the icon name when absent.
- The Windows clock default is a 12 logical-pixel font, H:mm and yyyy/M/d. Existing mode 1 becomes the theme default; regional format remains available separately. Explicit 12/24-hour and custom date settings are retained.
- Start footer uses 56 logical-pixel height, 28px side insets, 24px avatar and 20px power glyph. The neutral SVG fallback is project artwork, not a recovered Windows account bitmap.

## Microsoft UI Kit baseline (controls, not measured shell geometry)

- Windows 11 26H2 GA, build 26300; record the actual reference build and
  settings before comparing shell surfaces. Compare physical screenshot
  measurements after dividing by output scale (1.5 for the owner's setup).
- Windows UI Kit and WinUI 3 Gallery:
  https://learn.microsoft.com/windows/apps/design/downloads/
- Geometry: 4 epx control corner radius, 8 epx overlay radius:
  https://learn.microsoft.com/windows/apps/design/signature-experiences/geometry
- Type ramp: caption 12/16, body 14/20, body strong 14/20 semibold,
  body large 18/24, title large 40/52. Use the user's system font:
  https://learn.microsoft.com/windows/apps/design/signature-experiences/typography
- Scroll viewer: 16 epx interaction region, 2 epx panning indicator, 6 epx
  expanded thumb. No fixed 8px thumb or always-painted rail. Keep native
  attached scrollbar dragging and wheel handling. Reserve the gutter:
  https://learn.microsoft.com/windows/apps/develop/ui/controls/scroll-controls
- Notification center: the large clock is an optional feature. Preserve
  existing enabled behavior; expose a switch in clock appearance settings.
  Use the official type ramp (40 title large, 14 body, 18 strong month
  heading) as a provisional baseline, not a measurement of the shell:
  https://blogs.windows.com/windowsexperience/2025/10/16/new-experiences-currently-rolling-out-for-windows-11/
- Do not claim 1:1 fidelity from app control resources. Taskbar icon
  painted bounds, shell flyout width/height, exact grid, alignment, material
  and interaction require captures of the matching native shell. The 28px
  task canvas is still provisional pending that comparison.

## Notification and tray follow-up from 150% owner captures

- Do not wrap the complete notification/calendar flyout in a Flickable. Give notifications the available space and keep calendar navigation and all six rows within the screen budget. Hide the empty agenda; keep real events and optional time zones.
- All Fluent scrollbars retain the 16 epx input region and native thumb drag. Paint the 2 epx indicator only during interaction; expand to 6 epx on hover/press. Quick Settings retains the 24H2 paging arrows and wheel access to extra rows. Brightness and volume sliders are functional controls, not redundant scrollbars.
- The imported font's battery-unknown-charging glyph is 2560 font units wide, while normal battery outlines are approximately 1664 and charging outlines 1836. It must not determine normal battery scaling. Keep the normal battery levels and charging states together, separate the exceptional glyph. Treat the loudest speaker and mute glyph separately from the ordinary speaker family, preserving the relative speaker body geometry. Bluetooth uses its own original outline. No change to the 16 logical-pixel tray box, 28px task box, or installer.
- These changes use the actual source font geometry; verify the rendered desktop at 150% before claiming a matching shell appearance.

## Follow-up from the Chinese desktop capture

- Follow translated UI language for calendar date/month/weekday labels independently of LC_TIME. The Simplified Chinese catalog selects zh_CN; untranslated interfaces keep the system locale.
- Keep the native clock full representation. Apply an 8 logical-pixel popup margin and retain all frame borders through the native AppletPopup window properties. At 150%, the margin is 12 physical pixels before frame shadows. Do not change docked panel geometry.
- Quick Settings uses its entire three-column width. No reserved rail, thumb, or paging arrows. Wheel/touch/keyboard still reach every tile. Other overflow lists paint a scrollbar indicator only on gutter hover or press.
- Align independent status outlines to the center of their original 16px logical canvas. Retain common scale within families; separate standard and limited Wi-Fi states so weak signal art keeps its relative dot position. Center tray cells with equal top/bottom layout stretch and refresh grouped hover boundaries after Repeater delegates exist.
- No change to the task icon canvas, panel layout or installer. Full desktop horizontal centering cannot be assessed from cropped tray screenshots. Native popup placement requires Wayland verification.

## Modern battery and shared system group

- Use a project-drawn color battery glyph based on Microsoft's October 28, 2025 KB5067036 visual update. The original resource archive contains the older single-color glyphs, not a confirmed copy of the new colored asset. The new artwork is not represented as an extracted Microsoft original.
- Use actual cumulative battery percentage, charging/fully-charged AC state, and the KDE power-saver profile. Green indicates charging or fully charged on AC, yellow power saver, red critical (project threshold 5%), neutral other states. Unknown values never show a false percentage. No internal battery: keep the native applet representation. The taskbar percentage is optional, enabled by default, with stable text width; vertical panels keep their compact icon-only layout.
- The battery visual is shared by the taskbar, Quick Settings footer and battery page. Its 20x16 logical-pixel canvas occupies 30x24 physical pixels at 150%, retaining the existing 16px logical glyph height. Other glyph sizes and taskbar height remain unchanged.
- Quick Settings highlighting is rendered once per contiguous physical run of network, volume and battery cells, behind their real layout geometry. Do not round three independent rectangles or bridge unrelated tray items.
- Default Windows clock format is now h:mm AP, with literal English AM/PM even on a Chinese desktop. Keep the explicit regional and 24-hour choices. The compact time line remains right aligned above yyyy/M/d.
- Shared dateformat.js copies must remain byte-identical. Pass QML Locale enums to JS helpers rather than resolving them inside a .pragma library.
- Reference: https://support.microsoft.com/en-au/servicing/os/windows-11/2025/10/october-28-2025-kb5067036-os-builds-26200-7019-and-26100-7019-preview
