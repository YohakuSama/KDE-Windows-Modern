# Native Windows resources

Use your own Windows installation media or extracted resource archive. No
Windows binary, font, sound or wallpaper is redistributed by this repository.

## Import

Install Python 3, Pillow and fontTools using your distribution packages (Arch:
python-pillow and python-fonttools; Debian/Ubuntu: python3-pil and
python3-fonttools; Fedora: python3-pillow and python3-fonttools).

From the repository root as the desktop user:

```bash
python3 scripts/import-windows-assets.py ~/Downloads/Windows-resources.tar.gz
./install.sh icons
./install.sh themes
./install.sh sounds
```

An extracted directory containing Windows/ works too. Do not run as root.
The importer reads only the selected members, never executes Windows binaries
and never installs or sets the Segoe text fonts. Output lives in
$XDG_DATA_HOME/windows-modern/native-assets (default ~/.local/share).
Future icons/themes/all installations pick it up automatically.

## Verified reference inventory

The supplied archive contains 467 files: 3 MUN libraries (711 icon groups),
338 font-directory files, 31 wallpaper-directory files and 95 audio-directory
files. Segoe Fluent Icons identifies itself as version 1.56. The three MUN
file versions are 10.0.26100.7705 (imageres), 10.0.26100.9974 (shell32) and
10.0.26100.1 (imagesp1). File versions alone do not prove the Windows OS
release or build; do not relabel the source by assumption.

Initial import: 256 mapped icon paths, 22 distinct usable stock wallpaper
images, 20 sound-event filenames. Exact SHA-256 duplicates share disk
content, and conflicting target paths fail before the previous local
import is replaced. The icon map is intentionally semantic: original color
resources by MUN group ID; monochrome vectors by Segoe Fluent codepoint
(https://learn.microsoft.com/windows/apps/design/iconography/segoe-fluent-icons-font).
SVG files derived locally from the font preserve the em box and semantic
ColorScheme-Text class. Icon names/contexts remain compatible with KDE.
Different context/role names and genuine app logos are not indiscriminately
collapsed. Five KDE Wi-Fi strength steps map to the available Windows levels;
unverified locked, blocked and special states keep existing artwork.

The Bloom package uses Windows/img0.jpg and img19.jpg for light and dark.
The lock package uses Screen/img100.jpg; other usable full images are offered
as stock choices. Duplicate Spotlight and lock-screen images are not copied
twice; the small Spotlight preview and solid blue placeholder are excluded.
The public fallback package is retained for installs without owner resources.
Native system greeter installation is separate and still requires review.

The freedesktop sound theme maps matching events only. Do not force-enable
notification sounds when the owner has disabled them. To restore the previous
sound theme run ./uninstall.sh sounds. To return to the bundled artwork,
remove or rename the local native-assets directory and reinstall icons/themes.
The previous Plasma settings remain covered by the installer backup.

## Remaining validation

The archive parsing, image decoding, glyph generation, WAV format and
deduplication were exercised on the supplied archive. Plasma rendering,
symbolic recoloring, native applet FrameSVG sheets (including the battery
compositor), third-party app icons, pointer cursors and full material/layout
fidelity require live validation or further mappings. Unmapped names keep
the existing theme and Breeze/hicolor compatibility fallback. No additional
icon theme is activated.
