# Panel geometry and input contract

Reference desktop: Windows Modern on Plasma 6.8.3 / Qt 6.12, Wayland, 150% output scale.

- Use Qt logical coordinates. A 48px panel occupies 72 physical pixels at 150%.
- Task icons and Start use a 30px logical canvas. Retain optical padding in the artwork. The Start SVG has a 64px canvas with a 56px painted area, which renders at 39.375 physical pixels at 150%; do not tighten the viewBox to the path bounds or apply an extra scale. The owner reported that the previous 24px canvas (31.5 physical pixels of painted area) was too small on a 48px logical panel. Do not force arbitrary third-party artwork into a cropped shape.
- Tray uses 16px logical icon boxes; do not use the task icon size or multiply by DPR. Imported source outlines have already been normalized to their optical bounds.
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

## Calendar wheel and panel optical follow-up (pending live acceptance)

- The current provisional task canvas is 30 logical pixels, with the same 87.5% painted extent and preserved aspect ratio. Start, Search, Task View and Icon Tasks use this canvas with a 4px total cell inset. This is a measured adjustment of the previous baseline, not verified Windows 11 parity.
- Status glyphs and the notification bell use an 18px logical box. The default 32px overflow/notification and 24px core cells stay fixed, so larger glyphs do not inflate their layout. The 16px overflow chevron remains a separate affordance. Keep Qt responsible for output scaling.
- The fallback modern battery keeps its outline, terminal and fill vertically centered; its panel canvas is 22.5 by 18 logical pixels (rounded up for width). The pinned resource branch contains the three icon MUN libraries and SegoeIcons.ttf; the font table directory has no color glyph tables. No named modern battery artwork was found. This does not rule out an unclassified numeric image group. Do not claim the project-drawn battery is an extracted Microsoft asset or redistribute private resources.
- The calendar owns the wheel events over its grid. Angle deltas accumulate to 120 units; a coalesced event pages at most once. Pixel deltas accumulate to a provisional 64 logical-pixel threshold, then latch for the continuous swipe and inertia until 300ms of inactivity. Zero and horizontal-dominant input does not page. Reset partial input on zoom changes and reopening. Test real mice and touchpads in Plasma, including at 150% scale; offscreen QtTest covers synthetic detents and the pixel-input handler, not native touchpad delivery.

## 26H2 Start and Quick Settings reference follow-up

- Target the owner-provided 26H2 screenshots and the documented responsive Start layout, not the earlier single-list rendering. Start uses 560x640 or 768x720 provisional logical dimensions, six/eight pinned columns, two preview rows by default, category cards with actual Kicker app previews and a list/grid/category view selector. Existing explicit view and pin settings are retained. Native KDE categories are preserved; Windows' usage-ranked category taxonomy is not reproduced yet.
- Keep a single scrolling home surface. Hide the redundant All apps shortcut; the All section remains inline. Do not add Phone Link or dummy Windows-only controls.
- Quick Settings keeps a three-column, two-row viewport, uses 12px column and 16px row gaps at 100% and conditionally shows page dots and one directional arrow when additional rows exist. The gutter is absent when all items fit. Keep real KDE toggle states and native slider interaction. Use a 4px track and 20px thumb, smaller tile icons and a split divider visible only during interaction.
- This revision is an integration candidate; CI and matched-scale desktop screenshots are still required. Reference: https://blogs.windows.com/windows-insider/2025/06/09/announcing-windows-11-insider-preview-build-26200-5641-dev-channel/ and https://blogs.windows.com/windowsexperience/2026/09/29/how-to-get-the-windows-11-2026-update/.

### 26H2 customization and fidelity follow-up

Microsoft's released 26H2 documentation confirms the independent Pinned, Recent and All switches, explicit Small/Large/Automatic Start size choices, and responsive category/grid views. Keep these preferences local, collapse empty sections, and preserve the last expanded pin state. Hiding identity substitutes the generic avatar and removes the name while leaving the account menu reachable. Use 16px top search inset, a 22px gap to the scrolling home surface, compact pin spacing and the existing footer. The volume detail action uses the existing mixer glyph beside a chevron, with a 32px-tall interactive target. KDE category labels and app grouping remain the current backend, and exact Windows category ordering/typography/material geometry still need a paired live screenshot review.

Sources: https://learn.microsoft.com/windows/whats-new/whats-new-windows-11-version-26h2 ; https://support.microsoft.com/en-us/windows/experience/personalization/customize-the-windows-start-menu ; https://support.microsoft.com/en-us/servicing/os/windows-11/2026/08/kb5120998-windows-11-24h2-25h2-update .

## Notification center and calendar reference follow-up

The owner's notification/calendar screenshot shows a 26340 prerelease watermark; the visual structure is a reference for the 26H2 target, not proof that every preview feature ships in GA. Keep one native Plasma popup; frame the notification history and calendar separately inside it with a 10px logical gap. The native popup background and compositor blur remain, so the gap is not a true independent DWM surface. Use a 14px notification title and month heading, 12px weekday labels, 13px dates, compact 28px navigation targets and a stable focus footer. The optional seconds clock is off by default; explicitly saved preferences are retained. The app header, timestamp and message body have separate visual roles. Preserve the native history model and actions, and use a real deadline-based focus timer in the applet, not in the popup. Focus owns only the manual inhibition it sets, and never replaces an existing manual DND or clears a changed value. KDE calendar/time-zone extras remain conditional and fit within the screen budget. No claim of pixel parity until a live Wayland comparison is performed.

### Tray optical-size correction after owner screenshot

A 404x73 physical-pixel screenshot showed removable-media ink about 10x16px and battery ink about 23x14px. For a normal 48 logical-pixel panel, use a 20px status canvas while keeping the regular 32px and core 24px cell pitch; the chevron is 18px, and the battery uses a 25x20px canvas plus only 6px horizontal cell clearance. This is a screenshot-driven correction, not a verified physical Windows 11 measurement. The removable-device applet now draws the canonical status SVG directly (the existing local importer maps e88e, normalized by its own optical family), keeping native device presence, menus and activation. Preserve aspect ratio and disable Kirigami size rounding on SNI icons. The battery remains project artwork; its outline, level fill and terminal have more usable area. The current Windows clock mode already formats English AM/PM; 24-hour and regional modes remain explicit choices. Fix the notification button's final-property collision before packaging. Validate the actual painted bounds and active taskbar build in a live session.

### Original battery assets only

Supersedes the previous project-drawn battery notes. Use the locally imported original Microsoft Segoe glyph family until the exact newer battery asset is supplied. Do not imitate the new icon with QML rectangles or paths. The square original glyph is centered in a stable wider cell without stretching; the real charge state selects a mapped glyph. Percentage is independently toggleable in tray configuration and battery details, defaults off for new installations, and remains visible in Quick Settings. Missing new artwork is a fidelity blocker, not a passing acceptance result.

### Fixed tray reference baseline (supersedes the 18px and 20px experiments)

Microsoft's Windows 11 app-icon construction table specifies tray resources at 16/20/24/32 physical pixels for 100/125/150/200% scaling, and taskbar app resources at 24/30/36/48. Use this 16 logical-pixel tray baseline; the original imported status glyphs already have 23/24-em optical normalization. This is an icon-resource guideline, not a direct pixel measurement of every 26H2 system glyph. At a standard 48 logical-pixel panel height, both default and scale-with-panel modes now select 16px; use a 16px chevron and bell, 32px ordinary and 24px core hit cells. The battery keeps the established wide 20x16 layout box and a 20px square source canvas (30 physical pixels at 150%) to preserve the authentic horizontal glyph aspect. Its exact 26H2 asset is still unavailable. Do not enlarge a normalized source to compensate for the previous unnormalized source. In the owner's 462x87 screenshot, bright ink bounds measured USB 18x28, Wi-Fi 28x20, volume 28x24, battery 36x22, bell 20x22 physical pixels. Under the same 150% output and source artwork the 16/20 ratio predicts about 22px USB height, 22px Wi-Fi/volume width and 29px battery width; these are predictions, not new screenshots. Application artwork, click semantics and the percentage preference remain unchanged. Require actual paired screenshots before any further optical-size change. Source: https://learn.microsoft.com/windows/apps/design/iconography/app-icon-construction .

### Owner screenshot regression: menu rows and nested flyout frames

The owner screenshots showed 24px-class action glyphs competing with the text in the Start power/account menus; compact action glyphs now use an independent 16px logical box, 32px row target, 13px text, and 10px text/icon gap. Context menus use the same constants. The power footer button uses the compact glyph without changing its 40px hit target. A pointer-opened menu must not preselect its first action; keyboard navigation remains available. Do not invent replacement icons. The clock's native AppletPopup already paints the outer frame (PlasmaWindow exposes StandardBackground and SolidBackground, not NoBackground); remove only the extra two inner outlines, preserving the calendar and focus behavior. This eliminates one source of the nested-outline defect but is not the Windows two-independent-surface solution. A shared Plasma CompactApplet FrameSvgItem uses widgets/tabbar for its expanded accent indicator; do not globally edit that SVG to fix one clock without assessing other tab consumers. The screenshot still shows large tray ink, but the installed build cannot be identified from an image. Do not change the established 16px tray baseline again without checking the installed source version and scale. Stage changes in a review branch and run CI; live matched screenshots remain a separate gate.
