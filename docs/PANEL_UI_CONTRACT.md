# Panel geometry and input contract

Reference desktop: Windows Modern on Plasma 6.8.3 / Qt 6.12, Wayland, 150% output scale.

- Use Qt logical coordinates. A 48px panel occupies 72 physical pixels at 150%.
- Task icons and Start use a 24px logical canvas. Retain optical padding in the artwork. The Start SVG has a 64px canvas with a 56px painted area, which renders at 31.5 physical pixels at 150%; do not tighten the viewBox to the path bounds or apply an extra scale. The owner's screenshot measured 36px for the previously cropped Start logo and about 32px for Firefox, file manager and terminal. Do not force arbitrary third-party artwork into a cropped shape.
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
- Task icons use a 24 logical-pixel canvas and 87.5% maximum painted extent (31.5 physical pixels at 150%). Normalize real task icons by alpha bounds, preserving aspect ratio and the Start optical inset.
- Native symbolic status families use the union of actual font outline bounds and one isotropic transform per family. A 16 logical-pixel box has a maximum painted extent of 23 physical pixels at 150%. Signal levels do not resize independently. Battery remains wider than tall, as in the original artwork. Locate installed Windows Modern glyphs directly, falling back to the icon name when absent.
- The Windows clock default is a 12 logical-pixel font, H:mm and yyyy/M/d. Existing mode 1 becomes the theme default; regional format remains available separately. Explicit 12/24-hour and custom date settings are retained.
- Start footer uses 56 logical-pixel height, 28px side insets, 24px avatar and 20px power glyph. The neutral SVG fallback is project artwork, not a recovered Windows account bitmap.
