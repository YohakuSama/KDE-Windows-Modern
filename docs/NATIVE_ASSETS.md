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
The private `bash scripts/package.sh --owner` package reuses that cache.
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

The source checkout includes read-only coverage and inspection tools, the
metadata-only reference snapshot, and tests. See the current
[native coverage guide](https://github.com/YohakuSama/KDE-Windows-Modern/blob/main/docs/NATIVE_COVERAGE.md)
for development checks.

## Current coverage boundaries

- The current reference library lacks an identified 26H2 SysBatt Fluent
  Icons source. The legacy imported Segoe battery family is not evidence
  of the newer battery artwork.
- The newer colored Search activation glyph has not been identified in the
  reviewed library. Use the verified monochrome search role until the
  exact source is available.
- The original indexed account portraits are absent. The existing group 88
  mapping provides a default image; actual user portraits take precedence.
- Native Plasma desktop selection, notification toast behavior and
  application menus need live validation independently of icon imports.

The owner retains the full reference material for filling these gaps.
Do not remove unused development sources merely to reduce package size.
