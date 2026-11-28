# Cursor theme

Windows Modern supports two XCursor layers without a custom KWin renderer
or runtime daemon:

1. **Private Windows 11 26H2 original XCursor import (`Windows-Modern-26H2`)**:
   Generated locally from an authorized Windows 11 26H2 installation or
   extracted ISO via `scripts/import-cursor-assets.py`. Never committed to
   Git or bundled into public release archives.
2. **Public open-source fallback (`Bibata-Modern-Ice` v2.0.7)**:
   Designed by Abdulkaiz Khatri (ful1e5), GPL-3.0. White fill, black outline,
   rounded profile, multiple cursor sizes (16–96). Used whenever no local
   Windows 26H2 cursor import is present, and inherited by
   `Windows-Modern-26H2` (`Inherits=Bibata-Modern-Ice,breeze_cursors`) for
   X11-only auxiliary roles that have no Windows system cursor counterpart.

## Local Windows 11 26H2 cursor import

In Windows 11 26H2 (`Build 26300.9974`), `Resources/Themes/aero.theme` and
`dark.theme` (`[Control Panel\Cursors]`, `DefaultValue=Windows Default`) map
13 Aero roles (`aero_arrow.cur`, `aero_helpsel.cur`, `aero_working.ani`,
`aero_busy.ani`, `aero_pen.cur`, `aero_unavail.cur`, `aero_ns.cur`,
`aero_ew.cur`, `aero_nwse.cur`, `aero_nesw.cur`, `aero_move.cur`,
`aero_up.cur`, `aero_link.cur`). `Cursors/` additionally supplies
`aero_pin.cur`, `aero_person.cur`, `beam_r.cur` (`IBeam` black core with
white outline, avoiding Win32 hardware XOR inversion), and `cross_r.cur`
(`Crosshair` with white outline). When `System32/ole32.dll` is present, its
32-bit multi-DPI `RT_GROUP_CURSOR` groups `2`, `3`, and `4` supply authentic
Windows 11 drag-and-drop cursors (`dnd-move`, `copy`, and `alias`/`link`).

Run as the desktop user against an extracted Windows directory, parent ISO
tree, or archive:

```bash
python3 scripts/import-cursor-assets.py /path/to/26H2 --build 26300.9974
```

The importer validates `aero.theme` when present, converts straight-alpha
Windows `.cur` / RIFF `ACON` `.ani` frames (18 steps × 3 jiffies = 50 ms)
into premultiplied ARGB32 `Xcur` binaries, preserves exact per-frame
`(xhot, yhot)` hotspots, maps Windows `32/48/64/96/128` pixel canvases to
KDE's `24/36/48/72/96` nominal sizes (matching `breeze_cursors` so default
size `24` at `150%` Wayland scale selects the native `48×48` frame 1:1
without resampling), and writes SHA-256 provenance to
`${XDG_DATA_HOME:-$HOME/.local/share}/windows-modern/cursor-assets/manifest.json`.

Both `./install.sh` and `./install-nixos.sh` verify and install
`Windows-Modern-26H2` automatically when present (or from a local `26H2/`
checkout directory) and restore the previous cursor configuration on
uninstall. The user's selected cursor size is never overwritten.

## Public fallback provenance

Upstream source and build instructions:
https://github.com/ful1e5/Bibata_Cursor/tree/v2.0.7
Upstream compiled archive:
https://github.com/ful1e5/Bibata_Cursor/releases/tag/v2.0.7
License:
https://github.com/ful1e5/Bibata_Cursor/blob/v2.0.7/LICENSE
Checksum reference:
https://github.com/freebsd/freebsd-ports/blob/main/x11-themes/bibata-cursor-theme/distinfo

The installer fetches the pinned archive and extracts only `Bibata-Modern-Ice`.
Integration ZIPs bundle that exact open-source artwork, retaining aliases as
symlinks. No upstream installer is executed. If the user already installed a
cursor theme themselves, their copy is left alone; uninstall removes only
files marked as installed by Windows Modern.

Choose the system cursor size in System Settings > Colors & Themes > Cursors.
KDE handles Wayland/XWayland/X11 cursor scaling natively.
