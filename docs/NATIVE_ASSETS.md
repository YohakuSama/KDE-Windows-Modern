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

The reviewed reference snapshot has 713 groups, 5,405 frames and
467 original files. The three MUN modules contain 369 `imageres`, 335
`shell32` and 9 `imagesp1` groups. The current mapping selects 61 of
those groups. The remaining groups stay in the reference branch for
future semantic review; do not map them by ID alone.

The reference snapshot includes `SegoeIcons.ttf`, but its original file
inventory contains no `Sysbatt.ttf`, `AXPIcons.ttf`, SystemApps Search
state images or Task View PRI. The source manifest has no Windows build
identifier. These absences are specific to the reviewed branch revision,
not proof that those files do not exist in a separate 26H2 installation.

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
be imported separately from an authorized Windows 11 26H2 installation.
Record the exact source build reported by that installation; the reference
branch itself does not establish the build. Do not substitute a similarly
named MUN icon.

| UI role | Windows source | Import rule |
| --- | --- | --- |
| New battery outline/fill states | `SystemApps/MicrosoftWindows.Client.Core_cw5n1h2txyewy/SystemTray/Assets/Sysbatt.ttf` | Convert the original paths into private local SVGs; do not install or redistribute the font. Glyph roles are documented below. |
| Battery font fallback location | `SystemResources/Windows.UI.ControlCenter/Assets/Sysbatt.ttf` | Use only if the SystemApps copy is absent. |
| Search activation, light taskbar | `SystemApps/MicrosoftWindows.Client.Core_cw5n1h2txyewy/StartMenu/Assets/SearchIcons/SearchIconOnLight.scale-100.png` | Preserve the original PNG and its state. |
| Search idle, light taskbar | `SystemApps/MicrosoftWindows.Client.Core_cw5n1h2txyewy/StartMenu/Assets/SearchIcons/SearchIconOffLight.scale-100.png` | Preserve the original PNG and its state. |
| Search activation, dark taskbar | `SystemApps/MicrosoftWindows.Client.Core_cw5n1h2txyewy/StartMenu/Assets/SearchIcons/SearchIconOnDark.scale-100.png` | Preserve the original PNG and its state. The matching dark idle PNG is optional; use the existing Segoe E721 role when absent. |
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

## Local shell artwork import

The new importer accepts an extracted Windows directory, including the
original SystemApps and SystemResources trees. It exports the exact
SysBatt outline/fill paths, the required original light idle/active and dark
active Search PNGs at the highest available scale, and both original Task View
SVGs embedded in the Settings PRI. A dark idle Search PNG is imported when
present; otherwise that state uses the existing Segoe E721 role. Incomplete
required input leaves the previous import untouched.

Use the [official Windows 11 26H2 ISO](https://www.microsoft.com/software-download/windows11) or an authorized 26H2 GA installation (build family 26300), rather than an unversioned icon archive. An extracted image may contain both `Windows` and `ProgramData`. In that case the importer also looks for the original default account image under `ProgramData/Microsoft/User Account Pictures` (`user.png`, `user.jpg`, `user.bmp`, or a standard size-specific PNG). Use a clean source installation, since administrators can replace these defaults. The file is optional and remains private; no user-specific account pictures are collected.

```bash
python3 scripts/import-shell-assets.py /path/to/Windows --build ACTUAL_BUILD_NUMBER
```

On NixOS, if Pillow and fontTools are unavailable in the current environment:

```bash
nix-shell -p python3 python3Packages.pillow python3Packages.fonttools --run 'python3 scripts/import-shell-assets.py /path/to/Windows --build ACTUAL_BUILD_NUMBER'
```

Replace the placeholder in either command with the exact numeric build
reported by the source Windows installation. The importer records the declared
build, original resource paths, source hashes and generated output hashes in a
private local manifest. It
does not install or bundle the proprietary font itself. The applets
read the generated artwork from
`${XDG_DATA_HOME:-$HOME/.local/share}/windows-modern/shell-assets`.
Restart Plasma after importing to refresh the resource paths.

The standard owner bundle retains the import code, not this new local
artwork, until verified resources are available in the private runtime
library. The importer and rendering alone do not establish original binary
provenance. The later owner audit in
[NATIVE_COVERAGE.md](https://github.com/YohakuSama/KDE-Windows-Modern/blob/testing/docs/NATIVE_COVERAGE.md#owner-audit-26h2-build-263009974-and-plasma-683)
records the 26300.9974 local extraction and 45 generated outputs;
installation and actual rendering remain separate checks. See the
[project quality ledger](https://github.com/YohakuSama/KDE-Windows-Modern/blob/testing/docs/PROJECT_QUALITY_LEDGER.md#block-02) for current
coverage tasks.

## Current coverage boundaries

- The 26H2 SysBatt font, colored Search state images and two-tone Task View
  SVGs are now identified by their Windows source paths above, but are not
  present in the reviewed MUN resource branch. BatteryGlyph still uses the
  older imported Segoe level/charging/saver family until the private 26H2
  font is imported and verified. Do not draw a replacement.
- Search currently uses the genuine imported Segoe E721 role when no
  verified colored state image is installed, including the optional dark idle
  Search state. Task View uses E7C4 until both original PRI SVG variants are
  imported. These existing sources are not proof of 26H2 provenance; do not use
  Windows 10 or KDE/Breeze replacements.
- The default account SVGs are the official MIT-licensed Fluent Person 48
  Filled path, recolored by the theme (see [attribution](../ATTRIBUTION.md)).
  They are not verified 26H2 login portraits. Start, session unlock and
  login now share the same portrait selection: a successfully loaded user
  image takes precedence, then the privately imported Windows default
  portrait, then the Fluent fallback. Hidden Start account identity
  always uses the generic fallback. A separate login service account must
  have access to its own authorized local resource directory; a desktop
  user's private assets are not automatically visible in that account.
  The explicitly invoked optional system greeter transfer is described
  below.
- The existing login battery control and desktop tray share the original
  SysBatt renderer, level selection, 5:4 canvas and private lookup.
  The existing lock-screen control visibility policy is unchanged.
- Taskbar Start and Task View buttons in `SystemApps/MicrosoftWindows.Client.Core_cw5n1h2txyewy/Taskbar.View.dll`
  use compiled Win2D/Lottie C++ visual classes (`AnimatedVisuals.StartLight.cpp`,
  `AnimatedVisuals.StartDark.cpp`, `AnimatedVisuals.TaskViewLight.cpp`,
  `AnimatedVisuals.TaskViewDark.cpp`) rather than standalone taskbar SVG files;
  `Client.Core/Icons/WindowsLogo.svg` (`12×12`, `#4DD2FF` → `#0078D4`) is an
  inline consent badge asset, so `modules/startmenu/ui/start-logo.svg` remains
  explicitly classified as compatibility artwork and is never recorded as an
  extracted 26H2 binary asset.
- Start's power menu (`Files\StartDocked\PowerOptionsView.xbf` + `StartDocked.dll`)
  binds its dynamic choices from `Windows.Internal.UI.Shutdown.ShutdownUXViewModel`
  (`Windows.UI.Logon.dll` / `windowsudk.shellcommon.dll`), with `U+EC83`
  (`PowerOptionUpdateMenuFlyoutItem`) in XBF and `U+E708` (`Sleep`) / `U+E7E8`
  (`PowerButton`) in shell code. Hibernate continues to use the optional original
  Segoe Fluent `E823` glyph from `SegoeIcons.ttf` v1.56; never substitute the
  Sleep crescent or KDE artwork.
- Original Windows 11 26H2 cursors (`Cursors/aero_*.cur`, `aero_*.ani`,
  `beam_r.cur`, `cross_r.cur`, and optional `System32/ole32.dll` drag-and-drop
  groups `2`–`4`) are imported separately into
  `${XDG_DATA_HOME:-$HOME/.local/share}/windows-modern/cursor-assets` by
  `scripts/import-cursor-assets.py` (see [CURSORS.md](CURSORS.md)).
- Native Plasma desktop selection, notification toast behavior and
  application menus need live validation independently of icon imports.

The owner retains the full reference material for filling these gaps.
Do not remove unused development sources merely to reduce package size.

The optional non-NixOS system greeter uses the same generated native icon
import. When invoked via sudo from the desktop user, the live installer
prepares that user's import and transfers only the verified generated
artwork into /usr/share/windows-modern/native-assets. If the private shell
manifest matches the recorded 26H2 reference, its generated artwork is
also installed in /usr/share/windows-modern/shell-assets. Missing private
artwork is reported, not claimed to be original coverage. A direct root
invocation can only reuse a valid system import. The greeter uninstaller
removes only directories marked as installed by this path.
