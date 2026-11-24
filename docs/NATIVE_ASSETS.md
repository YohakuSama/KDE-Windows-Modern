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
Future icons/themes/all installations pick it up automatically. The local manifest now remembers the source path after a successful import. Keep the archive at a stable private location and use `python3 scripts/import-windows-assets.py --reuse` after a mapping update, without downloading or supplying the archive again.
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
The installer restores the locally imported original Bloom package (both light and dark) after Plasma's layout reset and restart. Run `./install.sh wallpaper` to restore it without changing panels, icons or fonts. If the generated package is missing, the installer tries the remembered original resource source; it reports failure if no original is available. The public compatibility wallpaper is retained, but applying it requires the explicit command `./install.sh wallpaper --allow-fallback`.
A standalone `./install.sh sessionlock` selects the installed native lock
package if present, without changing the desktop wallpaper. With no installed
native lock package it keeps the current lock wallpaper. Native system greeter
installation is separate. After installing the greeter, use System Settings >
Login Screen > Appearance (systemsettings kcm_plasmalogin) as the desktop
user. Select the imported JPEG in the installed Windows-modern-lock package
under contents/images and Apply. PLM's authorized helper copies the selected
image into its own wallpaper directory. The installer does not overwrite
existing login wallpaper settings; select your previous wallpaper there to
revert this optional choice.

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

The status mapping follow-up adds 22 paths (429 total) for account switching, limited Wi-Fi levels, wired limited/VPN, and unknown charging. Two existing no-route aliases use Ethernet warning. All nine changed glyphs rendered nonempty from the supplied font. Rerun the existing importer before reinstalling icons. See Microsoft's [Segoe Fluent Icons reference](https://learn.microsoft.com/windows/apps/design/iconography/segoe-fluent-icons-font).

The device compatibility follow-up adds five paths (434 total): headphones, headset, webcam, phone and mouse. All five source glyphs were checked in the owner's local font. Plasma 6.7/6.8 native applet icon-name consumers should use the existing icon theme rather than duplicating those glyphs into legacy sheets unnecessarily. Reimport resources before installing icons; keep the unconfirmed legacy roles unchanged.

## Shell and everyday application action coverage

The map now targets 549 paths (115 more than the previous 434), including both standard and symbolic forms of toolbar, file-manager, media, notification, password visibility, power, window and text editing actions. The old USB glyph used for the eject alias has been replaced with the dedicated Eject glyph. Existing color icons and genuine app logos remain distinct. Newly mapped source codepoints are documented by Microsoft for Segoe Fluent Icons; they are optional for older archives, and absent ones are listed in the local manifest rather than aborting the complete import. The original archive is not mounted in this session, so these additions have not been rendered from its bytes. Reimport locally to apply the new map. No Windows resources are committed.

## Native OSD coverage

The map targets 583 icon paths, including the actual KDE 6.8 OSD
names for screen brightness, keyboard brightness and layout, touchpad on,
Wi-Fi on, Bluetooth on, mobile connectivity, virtual keyboard activation
and dismissal, and power profiles. Plasma's existing OSD calls these
names through Kirigami. No replacement service is installed. Keep existing
artwork for distinct disabled, blocked and high-volume warning states
where a matching glyph has not been established. New codepoints remain
optional until checked with the supplied font.

## Persistent resource reference

The public GPL repository tracks the semantic mapping and documentation, not original Microsoft binaries, fonts, generated artwork or a private download credential. Keep the original archive in a private location you control and have permission to use. To refresh the mappings and produce a shareable metadata inventory, run:

```bash
python3 scripts/import-windows-assets.py --reuse --catalog docs/native-assets-catalog.json
./install.sh icons
```

On first use provide the original path instead of `--reuse`. The catalog contains only font version, codepoint numbers, MUN group IDs, selected source hashes/sizes, mapping hash and coverage; no artwork, local source path or executable data. It may be reviewed and committed as metadata after verifying it contains no private information. Use a new catalog filename or deliberately remove the old catalog before regenerating; the importer never overwrites an existing catalog. The archive does not need to be committed or attached to each conversation for future mapping review once the catalog is available. Actual rendering and source-file verification still use the private local archive.

## Reuse the indexed resource checkout

The owner resource-only branch `resources/windows11` at `272e06c87be0f548cebb2558392019b941df20d4`
contains 467 original files, 713 icon groups (including two named blank
resources), and 5,405 frames. The metadata-only snapshot is
`docs/windows11-resource-index.json`. All 63 existing numeric MUN mapping
keys occur in the index. The checked Git tree contains all 6,585 indexed
original/ICO/PNG paths; listed original and ICO file sizes agree. These are
metadata checks, not a fresh binary decode or visual review.

Use your existing local indexed checkout, not a fresh extraction:

```sh
python3 scripts/import-windows-assets.py /path/to/windows11-resource-checkout
./install.sh icons
./install.sh themes
./install.sh sounds
```

The importer recognizes `resource-manifest.json`, reads the originals from
`original/Windows`, checks selected sizes and SHA-256 hashes, and uses the
already exported indexed PNG preview for each mapped MUN group. It does not
extract all MUN groups again. Original archive/directory input is unchanged.
Use `--reuse` for mapping updates. Keep this checkout local and outside the
source tree; main and integration packages do not include Microsoft assets.
Task View E7C4 and GridView F0E2 are distinct roles; the latter is optional
pending verification against the supplied font. The supplied directories
still lack default account-picture files, Store package artwork and cursors.

### Keep the installed original icons current

The icon installer now checks the local manifest against the exact mapping
revision and verifies every expected mapped SVG before removing the old
installed theme. If the local import is stale or damaged it reruns the
existing importer with `--reuse`, using the remembered local source. If
that source is gone, it stops without deleting the installed icon theme.
Keep a local copy of the indexed owner resources even after the temporary
Git branch is removed. Without an import, bundled icons remain a fallback;
the installer explicitly reports that they are not verified Windows originals.

## Owner testing bundle

The exact resource index is in the `resources/windows11` branch at `272e06c87be0f548cebb2558392019b941df20d4`. Run `bash scripts/package.sh --owner` to build a private source-build test ZIP including the indexed PNGs and original wallpaper, MUN, Segoe icon font and audio inputs used by the importer. Its separate manifest is not uploaded by the public release script. The normal installer automatically imports these bundled files; `bash scripts/prepare-native-assets.sh` also restores them from the pinned branch when testing a checkout. Original account-picture files are absent from the index; the default account image uses the existing verified imageres group 88 mapping. Personal account photos take precedence.

## Battery source fidelity requirement (26H2)

The owner explicitly rejects project-drawn replacement artwork. The shared BatteryGlyph now renders the locally imported original Segoe Fluent Icons glyphs for the charge level, charging and energy saver; it does not construct an outline, fill or bolt. The current pinned resource set includes SegoeIcons.ttf and three MUN libraries, but does not include an identified SysBatt Fluent Icons source or SystemTray.dll. Segoe is a legacy Microsoft fallback, not the current 26H2 battery. Do not call it the redesigned icon or invent glyph paths, fill geometry or approximated color layers. Obtain and review the authentic newer glyph resources and their state mappings from the owner's 26H2 installation before implementing the new artwork. Microsoft documents the modern icon colors and independent Battery Percentage preference at https://blogs.windows.com/windows-insider/2025/02/28/announcing-windows-11-insider-preview-build-27802-canary-channel/ . The taskbar percentage is opt-in for new settings and independent from the Quick Settings footer; existing explicitly saved choices are retained. The tray configuration and battery details control the same setting.
