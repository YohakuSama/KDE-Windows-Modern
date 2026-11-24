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

A ZIP archive, a TAR archive (including tar.gz), or an extracted directory
containing Windows/ also works. An archive may contain the resource directories
at its root or under a Windows/ directory. Do not run as root.
For example, use `python3 scripts/import-windows-assets.py ~/Downloads/Windows-resources.zip`.
The importer reads only the selected members, never executes Windows binaries
and never installs or sets the Segoe text fonts. Output lives in
$XDG_DATA_HOME/windows-modern/native-assets (default ~/.local/share).
Future icons/themes/all installations pick it up automatically.
The local manifest records the SHA-256 and byte size of each selected original
resource, as well as the generated output hashes. Duplicate selected paths,
non-regular archive entries, out-of-root selected paths and resources larger
than 64 MiB are rejected before the previous import is changed. The import
never extracts an archive member to its original path.

Run the source-reader regression tests without any Windows resources:

```bash
python3 -m unittest discover -s tests/native-assets -v
```

The test fixtures are synthetic; keep the archive, generated files and local
manifest out of public source control.

## Verified reference inventory

The supplied archive contains 467 files: 3 MUN libraries (711 icon groups),
338 font-directory files, 31 wallpaper-directory files and 95 audio-directory
files. Segoe Fluent Icons identifies itself as version 1.56. The three MUN
file versions are 10.0.26100.7705 (imageres), 10.0.26100.9974 (shell32) and
10.0.26100.1 (imagesp1). File versions alone do not prove the Windows OS
release or build; do not relabel the source by assumption.

Initial import: 358 mapped icon paths, 22 distinct usable stock wallpaper
images, 20 sound-event filenames. Exact SHA-256 duplicates share disk
content, and conflicting target paths fail before the previous local
import is replaced. The icon map is intentionally semantic: original color
resources by MUN group ID; monochrome vectors by Segoe Fluent codepoint
(https://learn.microsoft.com/windows/apps/design/iconography/segoe-fluent-icons-font).
SVG files derived locally from the font preserve the em box and semantic
ColorScheme-Text class. Icon names/contexts remain compatible with KDE.
Different context/role names and genuine app logos are not indiscriminately
collapsed. KDE Wi-Fi strength steps map to the available Windows levels;
unverified locked, blocked and special states keep existing artwork.
The current KDE network applet appends -symbolic to its live connection name,
and the native battery widget requests battery-NNN[-charging][-profile-powersave]-symbolic.
These standard names now resolve directly to the same imported artwork. Numeric
battery and energy-saving variants remain distinct. File actions and window
control icon names are also mapped; decoration SVG buttons are separate.

The Bloom package uses Windows/img0.jpg and img19.jpg for light and dark.
The lock package uses Screen/img100.jpg; other usable full images are offered
as stock choices. Duplicate Spotlight and lock-screen images are not copied
twice; the small Spotlight preview and solid blue placeholder are excluded.
The public fallback package is retained for installs without owner resources.
A standalone `./install.sh sessionlock` selects the installed native lock
package if present, without changing the desktop wallpaper. With no installed
native lock package it keeps the current lock wallpaper. Native system greeter
installation is separate and still requires review.

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

The follow-up map covers 389 names, including explicit restart, sign-out, sleep, notification bell/snooze and offline network roles. These added codepoints exist in the supplied Segoe Fluent Icons font. The same names are replaced rather than layered; existing special-state fallback remains where Windows equivalents are not established.

The subsequent real-archive check covered all 45 selected source files with the
new source reader (matching its committed Git blob), 22 distinct JPEGs and
18 WAV sources. Added 18 icon aliases for microphone active/muted, touchpad,
keyboard, keyboard brightness, night-light enabled, lock/unlock, application
menu and zero-volume states. The supplied font contains each required glyph;
the ten touched glyphs rasterized to nonempty images offline. The 407 mapped
paths resolve to 193 distinct generated icon contents in the offline
source-generation check. The battery saver tile now requests the actual
power-saving icon instead of the low-battery icon. Leave unconfirmed off/blocked
states on the existing fallback artwork. This is not live Plasma verification.
