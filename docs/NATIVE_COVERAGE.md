# Native artwork coverage and NixOS testing

The owner requires original Windows 11 resources wherever an equivalent exists. Do not substitute newly drawn approximations for missing Microsoft artwork. Never fall back to KDE artwork for project-owned system controls. Preserve actual third-party application identities, and report unresolved Windows artwork instead of assigning a misleading glyph. Do not publish Microsoft binaries, extracted artwork, or proprietary fonts to this public repository.

## Inventory

Run the read-only coverage tool against the checkout and installed desktop:

```sh
python3 scripts/icon-coverage.py > icon-coverage-source.json
python3 scripts/icon-coverage.py --installed > icon-coverage-installed.json
```

The second report checks the XDG icon theme and desktop entries, including the paths exported by NixOS. It separates verified native output hashes, mapped but unverified names, bundled artwork, absent theme entries, and absolute icon paths. Static QML literal candidates include some non-icon references. The separate `source_references` inventory also lists QML icon bindings, private role paths, C++ theme lookups, Konsole caption roles and direct artwork. The scan is heuristic; dynamic providers and native widget internals still require runtime review. Explicit Breeze inheritance is removed. A missing theme entry can still trigger implicit toolkit fallbacks or resolve via hicolor; treat project-owned controls using those fallbacks as unresolved coverage, not verified Windows artwork. Dynamic QML names, native widget SVGs, scale selection and actual pixmaps need desktop checks. Review the report before sharing. No files are uploaded.

Use the generated report and current mapping to count target paths. These are mapped names, not a claim of complete native artwork coverage. Count paths separately from unique original Windows resources. Do not label an icon native merely because its name is present in the bundled pack.

If the local source was already imported, the existing importer can export resource IDs and hashes without uploading binaries:

```sh
python3 scripts/import-windows-assets.py --reuse --catalog windows-resource-catalog.json
```

Verify exact source artwork before adding mappings. Account pictures and Microsoft Store packaged app assets may be outside the three MUN libraries. Check the actual archive first. If absent, request the precise original assets (and their originating Windows build), not a substitute SVG.

## Reviewed reference-branch coverage

The `resources/windows11` branch is the existing source of truth. Do not
download a second copy of these MUN resources or copy the entire reference
branch into the runtime package.

| Module | Indexed groups | Currently mapped groups | Not yet mapped |
| --- | ---: | ---: | ---: |
| `imageres.dll.mun` | 369 | 56 | 313 |
| `shell32.dll.mun` | 335 | 4 | 331 |
| `imagesp1.dll.mun` | 9 | 1 | 8 |
| **Total** | **713** | **61** | **652** |

The reviewed reference commit `272e06c87be0f548cebb2558392019b941df20d4`
contains 5,405 original icon frames and 467 original files. The current
mapping has 269 source entries: 61 MUN group references and 208 Segoe
Fluent Icons glyph references (910 target paths). These are source mappings, not 269 distinct
visuals or a claim that all 713 groups are relevant to the current desktop.
The runtime branch deliberately stages only the selected mapped previews,
not the complete archive.

The reference snapshot contains the three MUN modules above and the
`SegoeIcons.ttf` extraction font. It does not contain a `SystemApps`
tree, a PRI resource index, `Sysbatt.ttf`, `AXPIcons.ttf`, the
`StartMenu/Assets/SearchIcons` state PNGs, or the
`Windows.UI.SettingsAppThreshold.pri` Task View SVGs. Its manifest also
does not record a Windows build number. Do not label this snapshot as a
verified Windows 11 26H2 resource set.

## Windows 11 26H2 shell assets

The private `scripts/import-shell-assets.py` importer extracts 38 SysBatt
outline/fill SVGs, original Search state PNGs (dark idle is optional), and
both Task View SVGs from the Settings PRI. It checks glyph coverage, preserves
Search image bytes, selects the highest available source scale, and records
source and output hashes. The files remain under the user's private data
directory; no Microsoft font or artwork is added to the public repository.
See [native asset import instructions](NATIVE_ASSETS.md#local-shell-artwork-import).

The source paths are identified, but the reference branch does not contain
these files or establish their exact build. A source mapping does not prove
that a glyph exists in the staged font. Remaining gaps include confirming the Hibernate glyph on the exact 26H2 build and obtaining a clean original default account portrait.

The official Fluent Person 48 Filled SVG path already exists in the Start menu fallback; it is distinct from an actual Windows default account picture. Microsoft documents the default picture location under `%ProgramData%/Microsoft/User Account Pictures` ([policy reference](https://learn.microsoft.com/windows/client-management/mdm/policy-csp-admx-cpls)). The shell importer supports that location on a clean local image.

## Owner audit: 26H2 build 26300.9974 and Plasma 6.8.3

The metadata-only [resource audit snapshot](windows11-26h2-resource-audit.json)
records the owner's extracted Professional image (offline registry build
26300.9974), seven original input hashes and 45 successful shell artwork
outputs: 38 battery SVGs, all four Search states, both Task View variants
and the default account portrait. This is evidence from the owner's local
manifest, not independent verification of the binary contents or desktop
acceptance. The older reference/runtime resource pins are unchanged.

The extraction output used a separate staging directory; to activate the
already-supported shell artwork, reimport the complete local image as the
desktop user into the default XDG destination:

```sh
python3 scripts/import-shell-assets.py /path/to/extracted/image --build 26300.9974
```

The coverage report now includes a separate private shell manifest check.
With an existing Qt metadata log, also include KCM plugin declarations:

```sh
python3 scripts/icon-coverage.py --installed --kcm-metadata /path/to/KDE-KCM-Metadata.txt
```

The reviewed log lists 98 distinct KCM modules and 84 distinct icon names.
The earlier installed-theme report verified mapped files for 41 modules,
listed three more as bundled without verified provenance, and did not list
54 modules. That last count is an audit gap, not proof that 54 icons are
absent. Nine names are shared by 23 modules. Preserve separate module
semantics (e.g. clock vs. recent files and language vs. renderer); do not
globally overwrite a shared name until every consumer has been reviewed.
KCM category icons, internal controls, and Qt's resolved icon paths still
need review. Third-party and platform identities remain distinct.

To inspect the exact Settings Fluent Icons, AXP Fluent Icons and Segoe
Fluent Icons from that build, use the existing shell inspector's private
font-review mode. It scans the live component paths under Fonts,
SystemApps and SystemResources, deduplicates by SHA-256, and generates
labeled review sheets and a glyph catalog without copying font files.
It requires Pillow and fontTools. The review images remain local/private;
the repository records source paths, hashes and approved semantic mappings,
not proprietary artwork or fonts. The recorded audit identifies four
different Settings font hashes and three AXP font hashes, so do not treat
identically named fonts as interchangeable.

```sh
python3 scripts/inspect-shell-resources.py /path/to/extracted/image/Windows /path/to/new/private/font-review --font-review
```

Font review uses FreeType's basic layout engine and individual grayscale
glyph masks rather than RAQM text shaping. Blank cmap entries remain in
the catalog as blank glyphs; unrenderable entries are labeled ERROR and
recorded with the exact font hash and codepoint. The inspector completes
the remaining pages and writes its catalog, returning a nonzero status
if issues were recorded.

The review sheets and glyph names are candidates, not proof of the
role used by a particular Windows component. Confirm the relevant
PRI/XBF or live Windows UI before mapping. Settings page icons, tray
states, Hibernate, Start animation and newer context-menu resources
remain unverified. Do not add guessed glyph IDs.

## Reviewed 26300.9974 glyph supplement

The owner's successful font-review archive records eight distinct fonts, no
render failures, and all 45 imported Shell outputs with matching hashes.
The reference Segoe font SHA-256
`031ada497ddcc9bf3f2536efba2f4bd53f12a0dead44460a4a934b06a952dd2b`
matches the 26H2 extraction. Its original cmap and actual glyph previews
were reviewed against the [Segoe Fluent Icons reference](https://learn.microsoft.com/windows/apps/design/iconography/segoe-fluent-icons-font).
The runtime resource pin need not change: the new mappings reuse that font.

The following 24 previously unverified or missing KCM names gain
original glyph mappings. These are semantic mappings for KDE roles, not
proof that Windows uses these glyphs for every comparable control.
The final column records identical rasterized glyphs in the owner's
SettingsAppThreshold SettingsIcons.ttf review (36px FreeType mask),
where established; it is not an outline-level identity test.

| Segoe codepoint | Meaning | KCM icon names | Equal Settings raster |
| --- | --- | --- | --- |
| `E950` | Component | `cpu`, `preferences-devices-cpu` | E950 |
| `E88E` | USB | `drive-removable-media-usb-pendrive` | E88E |
| `EC4F` | MusicNote | `emblem-music-symbolic` | EC4F |
| `E92E` | KeyboardStandard | `input-keyboard-virtual` | E765 |
| `E946` | Info | `ktip` | E946 |
| `E721` | Search | `plasma-search`, `preferences-desktop-baloo` | E721 |
| `E8B0` | Click | `preferences-desktop-cursors` | E3B3/E8B0 |
| `E7F4` | TVMonitor | `preferences-desktop-display-randr` | E7F4 |
| `ED15` | Feedback | `preferences-desktop-feedback` | ED15 |
| `E8D2` | Font | `preferences-desktop-font-installer` | E8D2 |
| `E7FC` | Game | `preferences-desktop-gaming` | E7FC |
| `EDA7` | KeyboardShortcut | `preferences-desktop-keyboard-shortcut` | Not established |
| `EFA5` | Touchpad | `preferences-desktop-touchpad` | EFA5 |
| `EDA4` | Touchscreen | `preferences-desktop-touchscreen` | Not established |
| `E72E` | Lock | `preferences-desktop-user-password` | E72E |
| `E7C4` | TaskView | `preferences-desktop-virtual` | E7C4/EE40 |
| `E7E8` | PowerButton | `preferences-system-power-management` | E7E8 |
| `E8F9` | SwitchApps | `preferences-system-tabbox` | E8F9 |
| `E716` | People | `preferences-system-users` | E716 |
| `E8EA` | CellPhone | `smartphone` | E8EA |
| `EC50` | FileExplorer | `system-file-manager` | EC50 |
| `EDA3` | NetworkAdapter | `network-card` | EDA3 |

All observed same-name theme contexts for these roles are overlaid, with
symbolic aliases where appropriate. The two power KCMs share the same
function family. Cross-function shared names (time/recent files,
language/renderer, window behavior/rules/scripts) are not repurposed
globally. Other module-specific conflicts, KDE-only functions, application
identity icons, native runtime lookups and page controls remain open.

Plasma NM's network-list model returns `network-wireless-{0,20,40,60,80,100}-locked`
for secured networks. The 26H2 Segoe, SettingsAppThreshold and NetworkUX
font previews have matching rasterized E670–E673 lock-and-signal glyphs
(dot, one arc, two arcs, three arcs). Map both normal and symbolic names
to original outlines, preserving the existing four-level Windows family
and the backend's security state. The original EDDB/EDDC solid caret
glyphs replace the drawn Quick Settings pager triangle. No proprietary
artwork is added to this commit.

The Quick Settings slider count previously shared its name with the
slider layout's QML id. Renaming the count and layout separates the
nominal height calculation from the object id, preserving slider and
footer height before the popup is mapped. Wi-Fi and Bluetooth list
delegates use full width with inset inner cards instead of relying on the
ListView-controlled x position. Live layout, DPI and interaction acceptance
is still required.

## Source-grounded Windows layout review

The initial 26300.9974 audit contained indexes, resource hashes and icon
previews. The subsequent private layout-review archive includes the
19 original source files (55,960,726 bytes), all independently hash-checked
against its manifest. The [layout source list](windows11-26h2-layout-sources.json)
now records the hashes of all 16 primary PRI files, the Photon Start bundle
and both WindowsLogo SVGs. The two logo candidates have identical bytes;
their names and hashes do not prove the taskbar Start button's actual role.

Collect this bounded source set from the existing full local extraction,
without remounting the ISO:

```sh
python3 scripts/inspect-shell-resources.py /path/to/image/Windows /path/to/new/private/layout-review --layout-review
```

The layout review compares each previously inventoried PRI with its recorded
SHA-256 and byte count. It saves the original bytes under a separate
private `sources/` directory and records exact schema paths, map section
and item identifiers for named XBF, XAML and Lottie candidates. For the
first supported embedded candidate it records the payload hash, size and
header bytes. It does not resolve PRI qualifiers, external files, later
candidates or any XBF node stream. An unresolved or empty candidate list
does not mean that the component has no layout. The original PRI bytes
are retained in the private review directory even if the narrow parser
cannot enumerate their schema, so a later decoder can recover further
resources without a new image extraction. An issue is recorded if an
expected source is missing, differs from the reference, or fails inventory.

Review the raw XBF with a suitable decoder (e.g.
[XbfTools](https://github.com/chausner/XbfTools)); the applicable framework
schema and version must match the source. WinUI templates, resource
references, theme dictionaries, visual states, adaptive layout and
runtime code still need resolution. The Photon bundle is not XAML and
needs separate inspection. Do not apply a nominal Width or Margin to KDE
until its component, property, state and source are established. Use Qt
logical pixels and its device scaling once; document every intentional
platform adjustment rather than rescaling already-scaled logical values.

The review directory contains original Microsoft data and remains private.
Commit only the source metadata, parser code, independently authored
theme changes and verified parameter records. No layout dimensions,
animation values or Start logo role are asserted by this collection mode.
Localized PRIs, external resources, PE resources and runtime measurements
can be investigated separately where the primary sources are insufficient.

### First decoded parameter evidence

The [selected UI parameter evidence](windows11-26h2-ui-parameters.json)
records exact PRI and XBF hashes, resource paths, theme scopes, values and
payload-relative offsets. The archived PRI candidates include 1,513 named
XBF entries. All 1,481 non-placeholder payloads match the header-derived
length and the owner's recorded SHA-256; 32 entries are one-byte space
placeholders. This is not a claim that all node streams were decoded.

The first review reads selected named resource dictionaries and simple
brush property records, informed by the open XbfTools format research.
No third-party decoder source or Microsoft binary payload is included.
Do not combine constants from alternative implementations merely because
their resource names describe the same feature. For example,
ShellCommon's PaginatedControlCenterViewWidth is 376, whereas the
ControlCenter package's L2FrameMinHeight is 400. These are different
resource scopes, not proof of one 376-by-400 runtime popup. A declared
ControlCenterHeight of 680 is not evidence that every quick-settings
popup is that tall.

The credential control template directly references CredentialControlsWidth
(296) for FrameworkElement.Width. Update the existing KDE unlock credential
panel maximum from 248 to 296 logical pixels, retaining layout clamping on
narrow screens. Password height, avatar size, placement and animation remain
unchanged until their specific original properties are resolved.

The taskbar theme dictionaries contain separate light and dark fill/stroke
colors and icon-pressed opacity. SystemTrayResources and logon CommonStyles
contain explicit AcrylicBrush tint, luminosity, and fallback parameters.
These are static material inputs, not final composited pixel colors.
Windows distinguishes [Acrylic](https://learn.microsoft.com/windows/apps/design/style/acrylic)
from [Mica](https://learn.microsoft.com/windows/apps/design/style/mica).
Do not apply acrylic tint opacity as whole-window opacity, equate a KWin
blur with Mica, or replace the wallpaper-derived accent with a fixed color.
Resolve runtime resource selection and state transitions before adopting
additional geometry, color or animation values. Maintain Qt logical pixels
and preserve the existing compositor adaptation until it is source-grounded.

### Same-name theme alternatives

The owner's pre-supplement installed audit lists 16 names with 16 additional
theme files that are not individually verified, despite a verified path
for each name. Examples include devices/battery.svg, apps/system-run.svg
and status/network-connect.svg. A theme lookup can choose a different
context or size. The coverage report now exposes the extra paths in
`same_name_alternates` and `unverified_same_name_files`; the legacy
native name count remains the number of names with at least one verified
output path. Do not interpret the extra paths as confirmed non-Microsoft
artwork: they may contain identical bytes or intentionally different
application identity artwork. Inspect each before overriding it.

## Runtime assets and NixOS

NixOS uses the reversible desktop installer and builds the tray, taskbar and
desktop context-menu plugins against its own Plasma/Qt ABI. The Fedora 44/45
CI builds are ABI-specific checks, not NixOS binaries. The installer does not
modify the Nix store, configuration.nix, Home Manager or the system greeter.
See the [installation instructions](../README.md).

The complete reference branch `resources/windows11` stays available for
unmapped artwork. The pinned `resources/theme-runtime` branch is the
smaller exact input set for installation. The metadata-only snapshot is
`docs/windows11-resource-index.json`. A group ID alone does not establish
its meaning; inspect the real image, compare state families, update the map,
then review and pin the runtime selection.

Native palette, icon states and input behavior need verification on the
target desktop. Do not claim full coverage based on source checks alone.

## Taskbar and Quick Settings icon audit

The existing runtime `SegoeIcons.ttf` contains E7C2 (Move) and E744
(ResizeMouseMedium), documented by Microsoft. Both are mapped as optional
original-font roles for the taskbar's advanced Move and Resize actions.
They are original glyph candidates for the operation, not evidence of a
particular 26H2 menu resource. The runtime resource pin is unchanged.
The six other unmapped literal roles (Activities, menu editor, Keep Above,
Keep Below, exclusion from capture, and grouping) retain their text and
operations without unverified icons. The show-desktop sliver retains its
edit-mode marker rather than reusing the Move glyph.

Taskbar system menu actions, including generated media actions, request
private imported SVGs rendered as palette-tinted QIcons. KDE-specific
activity actions are text-only; application, file and media identities
remain separate. Quick Settings tiles, slider icons, network/device rows
and list entries use the existing private glyph resolver. Bluetooth and
removable hardware may use a mapped generic icon for that same device
category; unknown network states must not be assigned a fake strength.
Missing private glyphs leave artwork empty instead of resolving through
Breeze. Text and interaction geometry remain available.

Start context-menu actions, view selector/checkmark and search-section
chevrons now request private mapped Windows artwork. Missing action icons
leave a reserved empty slot; application/result identity icons are unchanged.
Notification and calendar flyout buttons use private SVG sources rather
than global icon names, including the DND banner and reply action.
Search uses only the original E721 mask when a build-specific state image
is missing; the old colored compatibility path is no longer requested.

The optional Konsole integrated chrome's owned stylesheet now uses mapped
E8BB tab-close and E76B/E76C scroll glyphs on the native QTabBar buttons.
Qt still owns the actions and geometry; the original paint behavior returns
when the custom chrome is disabled. Arbitrary user styles remain untouched.
These are reviewed original font roles, not a claim of exact Terminal or
26H2 shell artwork. Desktop acceptance is pending.

Remaining review includes profile icons in Konsole, third-party application
icons, native applet configuration pages, remaining theme lookups, dynamic
pixmaps, and the 26H2-specific shell assets listed above. The two recent-file compatibility
SVGs have had invalid editor-only attributes removed, but their provenance
is still unverified. Do not count them as Microsoft originals.

## System action review

Use Microsoft's [Segoe Fluent Icons reference](https://learn.microsoft.com/windows/apps/design/iconography/segoe-fluent-icons-font) to distinguish semantic roles. PowerButton E7E8, Restart3 F305, Lock E72E, SwitchUser E748, SignOut F3B1 and the moon-shaped QuietHours E708 used for Sleep are existing mapped roles. The original SignOut mapping was present; same-name status aliases were not. Synchronize power aliases in the status and actions directories so a stale status icon cannot win. The round clock used for Hibernate is visible in a [June 2026 Windows 11 screenshot](https://www.atera.com/blog/how-to-disable-and-enable-hibernate-in-windows-11/) and [earlier Windows 11 screenshots](https://www.guidingtech.com/how-to-enable-and-use-hibernate-mode-on-windows-11/). The [Windhawk Start Menu Buttons project](https://github.com/ramensoftware/windhawk-mods/blob/main/mods/windows-11-start-menu-buttons.wh.cpp) selects E823 for Hibernate; Microsoft names E823 Recent. The official E823 preview is a matching round clock. Map E823 as an optional original-font candidate, not as proof of the 26H2 shell resource ID. Confirm on the exact target build before claiming full coverage. Keep its real `canHibernate`/`hibernate()` action independent of artwork. Never use the E708 Sleep crescent or a KDE icon for Hibernate. Keep third-party application logos; the missing Store app artwork is not a test blocker.

Public visual references: [Windows Icon Archive](https://github.com/limehawk/windows-icon-archive) (Windows artwork remains Microsoft's; reference only), [Fluent System Icons](https://github.com/microsoft/fluentui-system-icons) (MIT-licensed separate design system), [Win11 Icon Theme](https://github.com/yeyushengfan258/Win11-icon-theme) (GPL-3.0, already credited). None establishes exact 26H2 equivalence or grants a new license to Microsoft proprietary artwork.
