# Cursor theme

Windows Modern uses Bibata Modern Ice v2.0.7, designed by Abdulkaiz
Khatri (ful1e5), GPL-3.0. White fill, black outline, rounded profile,
multiple cursor sizes (16, 20, 22, 24, 28, 32, 40, 48, 56, 64, 72, 80,
88, 96). KDE/XCursor handles pointer, text, resizing, waiting, drag and
other roles natively; the selected cursor size is not overwritten.

Upstream source and build instructions:
https://github.com/ful1e5/Bibata_Cursor/tree/v2.0.7
Upstream compiled archive:
https://github.com/ful1e5/Bibata_Cursor/releases/tag/v2.0.7
License:
https://github.com/ful1e5/Bibata_Cursor/blob/v2.0.7/LICENSE
Checksum reference:
https://github.com/freebsd/freebsd-ports/blob/main/x11-themes/bibata-cursor-theme/distinfo

The installer fetches the pinned archive and extracts only the chosen
theme. Integration ZIPs bundle that exact artwork, retaining aliases
as symlinks. No upstream installer is executed. If the user already
installed it, their copy is left alone; uninstall removes only files
installed by Windows Modern. Legacy installer-owned Win10OS cursors
remain removable through the existing uninstall path.

Design reference: Microsoft's Windows Insider Experimental build
26340.9354 (September 8, 2026) includes a screenshot of a softer pointer;
the official notes do not announce a complete new system cursor pack.
https://learn.microsoft.com/en-us/windows-insider/release-notes/experimental/preview-build-26340-9354

This is a stable open-source approximation, not Microsoft's proprietary
Insider pointer. No custom KWin cursor renderer or runtime dependency.
Choose the system cursor size in System Settings > Colors & Themes >
Cursors. KDE handles Wayland/XWayland/X11 cursor scaling.
