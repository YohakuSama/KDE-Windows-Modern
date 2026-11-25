# Native Windows resources

Windows Modern overlays verified original Windows artwork on the existing
icon theme. Keep original Microsoft resources and generated artwork for
authorized local/private use; public release archives must not contain
the owner's proprietary resource payload.

## Reference library and runtime inputs

| Resource branch | Role | Reviewed revision |
| --- | --- | --- |
| `resources/windows11` | Complete reference library, including unused artwork for future development | `272e06c87be0f548cebb2558392019b941df20d4` |
| `resources/theme-runtime` | Exact mapped inputs for current installation and packaging | `7046c2bd3a21bbe77b33876f8390540b80a72b4f` |

The full library contains the source MUN libraries, all indexed PNG/ICO
frames, fonts, wallpapers, audio and provenance. Keep it intact. Removing
a file from the runtime selection must not remove it from the reference.

At the reviewed runtime pin, the resource tree has 104 files totaling
35,025,393 bytes before ZIP compression: 61 icon previews, 23 wallpapers,
18 sounds, one icon extraction font and the original resource index.
No complete MUN libraries, additional font files or unused frames are needed
for indexed imports.

The normal installer uses bundled `native-resources/` when available.
Otherwise, the staging script fetches only the compact runtime branch,
checks its exact pin and resource hashes, and stores the verified snapshot
in `${XDG_CACHE_HOME:-$HOME/.cache}/windows-modern/runtime-resources/<pin>`.
The private `bash scripts/package.sh --owner` package and NixOS source
installation share that same verified cache. Bundled inputs are checked
against the current pin before importing. Old resource directories cannot
override a newer pin. The generated asset manifest also tracks the
importer code fingerprint, so changed extraction logic invalidates old SVGs.
It verifies required files, content hashes and ZIP integrity before writing
`dist/.owner-manifest`; it never pads the ZIP to a fixed size.

## Import from a local Windows archive

The importer also accepts a local Windows ZIP/TAR archive, an extracted
Windows directory or an indexed reference checkout. Install Python 3,
Pillow and fontTools for a manual import. NixOS's desktop installer supplies
its own Python environment.

From the checkout or complete private package, run as the desktop user:

```bash
python3 scripts/import-windows-assets.py /path/to/Windows-resources.tar.gz
```

Generated icons, wallpaper packages, sound theme and a source/output
manifest live under `${XDG_DATA_HOME:-$HOME/.local/share}/windows-modern/native-assets`.
Use `--reuse` with a successful previous import to refresh the mapping from
its remembered source:

```bash
python3 scripts/import-windows-assets.py --reuse
```

Keep that local source available. The indexed reader verifies PNG previews
against the reference index. Raw archive mode can extract icon groups from
MUN libraries directly. The Segoe icon font is an extraction input for
SVG glyphs, not an installed text font.

## Update the resource mapping

1. Identify the actual missing UI role and current Windows build. Compare
   the original artwork at the same scale and for all relevant states.
2. Find the original in the full reference library. Record its module/group
   ID or glyph codepoint in `scripts/native-assets-map.json`. Do not invent
   an original or replace third-party application logos with generic glyphs.
3. Review and update the compact runtime tree with only the new mapped
   previews and originals. Reuse the exact reviewed resource bytes; retain
   the original full provenance index. Pin the reviewed commit in
   `scripts/stage-native-resources.sh`. If the reference index changes,
   update its reviewed identity in `scripts/native_assets_index.py`.
4. Reimport and verify the entire mapped output and compare it on the
   running desktop. Do not equate a valid resource ID with correct semantics.

The development Git checkout (not the installation ZIP) includes read-only coverage and inspection tools, the
metadata-only reference snapshot, and tests. See the current
[native coverage guide](https://github.com/YohakuSama/KDE-Windows-Modern/blob/main/docs/NATIVE_COVERAGE.md)
for development checks.

For an unidentified newer icon or embedded font, inspect an authorized local
Windows extraction into a new private directory:

```bash
python3 scripts/inspect-shell-resources.py /path/to/Windows /path/to/private/shell-inventory
```

A matching font family or resource ID does not establish the correct glyph.
Review the original artwork before adding it to the map.

## Windows 11 26H2 shell-only artwork

The reviewed 713-group MUN archive does not contain the following shell
assets. They belong to packaged SystemApps or a PRI resource index and must
be imported separately from an authorized Windows 11 26H2 installation
(build family 26300). Do not substitute a similarly named MUN icon.

| UI role | Windows source | Import rule |
| --- | --- | --- |
| New battery outline/fill states | `SystemApps/MicrosoftWindows.Client.Core_cw5n1h2txyewy/SystemTray/Assets/Sysbatt.ttf` | Keep as a private applet asset and load it locally. Glyph roles are documented below. |
| Battery font fallback location | `SystemResources/Windows.UI.ControlCenter/Assets/Sysbatt.ttf` | Use only if the SystemApps copy is absent. |
| Search activation, light taskbar | `SystemApps/MicrosoftWindows.Client.Core_cw5n1h2txyewy/StartMenu/Assets/SearchIcons/SearchIconOnLight.scale-100.png` | Preserve the original PNG and its state. |
| Search idle, light taskbar | `SystemApps/MicrosoftWindows.Client.Core_cw5n1h2txyewy/StartMenu/Assets/SearchIcons/SearchIconOffLight.scale-100.png` | Preserve the original PNG and its state. |
| Search activation, dark taskbar | `SystemApps/MicrosoftWindows.Client.Core_cw5n1h2txyewy/StartMenu/Assets/SearchIcons/SearchIconOnDark.scale-100.png` | Preserve the original PNG and its state. Confirm the matching off-state filename on the source build before mapping it. |
| Task View, light/dark variants | `SystemResources/Windows.UI.SettingsAppThreshold/Windows.UI.SettingsAppThreshold.pri` | Extract `Files/SystemSettings/Assets/Taskview_Light.svg` and `Taskview_Dark.svg` from the PRI. The names indicate the taskbar background variant, not the glyph brightness. |

The battery font is named `SysBatt Fluent Icons`. The verified state
codepoints include outline U+F8D0 (discharging), U+F8DB (charging),
U+F8E4 (plugged in), and U+F849 (energy saver). Fill levels use
U+F8D1–U+F8DA for discharging, U+F8DC–U+F8E3 for charging, and
U+F8E5–U+F8EC for plugged-in states. These codepoints do not supply the
font file; the original `Sysbatt.ttf` is still required.

`SystemTray/Assets/AXPIcons.ttf` is a separate AXP Fluent Icons font used
for additional tray/input-method glyphs. Do not treat it as the SysBatt
battery font or install either proprietary font as the desktop text font.

The original MUN reference archive has no indexed entries for these
SystemApps/PRI assets. Their absence from the 713 MUN groups is expected,
not evidence that the Windows installation lacks them. Keep the source
build, original relative path, SHA-256 and extracted file together in the
private resource manifest. Never add proprietary Windows files to a public
release or the public Git history.

Import these shell-only assets from an extracted or mounted Windows
installation. Use the build number reported by that installation:

\`\`\`bash
python3 scripts/import-shell-assets.py /path/to/Windows --build 26300
\`\`\`

The importer verifies the SysBatt family and required glyph coverage, selects
the highest available Search PNG scale for each light/dark and on/off state,
extracts both Task View SVGs from the PRI, and writes the original artwork
plus source/output SHA-256 records to
\${XDG_DATA_HOME:-$HOME/.local/share}/windows-modern/shell-assets.
The Plasma applets read this private directory directly. The font itself is
not installed as a desktop text font and no proprietary shell asset enters
the public ZIP. If the Windows installation reports a different 26H2 build,
pass that exact number to --build rather than copying the example.

## Local shell artwork import

The new importer accepts an extracted Windows directory, including the
original SystemApps and SystemResources trees. It exports the exact
SysBatt outline/fill paths, four original Search PNG states at the
highest available scale, and the two original Task View SVGs embedded
in the Settings PRI. The import is atomic; incomplete input leaves the
previous import untouched.

```bash
python3 scripts/import-shell-assets.py /path/to/Windows --build 26300
```

Replace the example build number with the actual source build. The
importer records the declared build, original resource paths, source
hashes and generated output hashes in a private local manifest. It
does not install or bundle the proprietary font itself. The applets
read the generated artwork from
`${XDG_DATA_HOME:-$HOME/.local/share}/windows-modern/shell-assets`.
Restart Plasma after importing to refresh the resource paths.

The standard owner bundle retains the import code, not this new local
artwork, until verified resources are available in the private runtime
library. The importer and rendering are not evidence that the original
26H2 binaries have already been obtained.

## Current coverage boundaries

- The 26H2 SysBatt font, colored Search state images and two-tone Task View
  SVGs are now identified by their Windows source paths above, but are not
  present in the reviewed MUN resource branch. BatteryGlyph still uses the
  older imported Segoe level/charging/saver family until the private 26H2
  font is imported and verified. Do not draw a replacement.
- Search currently uses the genuine imported Segoe E721 role when no
  verified colored state image is installed. Task View uses E7C4 until both
  original PRI SVG variants are imported. Do not use KDE/Breeze fallbacks.
- The original indexed account portraits are absent. The existing group 88
  mapping provides a default image; actual user portraits take precedence.
- Native Plasma desktop selection, notification toast behavior and
  application menus need live validation independently of icon imports.

The owner retains the full reference material for filling these gaps.
Do not remove unused development sources merely to reduce package size.
