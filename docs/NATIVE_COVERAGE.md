# Native artwork coverage and NixOS testing

The owner requires original Windows 11 resources wherever an equivalent exists. Do not substitute newly drawn approximations for missing Microsoft artwork. Never fall back to KDE artwork for project-owned system controls. Preserve actual third-party application identities, and report unresolved Windows artwork instead of assigning a misleading glyph. Do not publish Microsoft binaries, extracted artwork, or proprietary fonts to this public repository.

## Inventory

Run the read-only coverage tool against the checkout and installed desktop:

```sh
python3 scripts/icon-coverage.py > icon-coverage-source.json
python3 scripts/icon-coverage.py --installed > icon-coverage-installed.json
```

The second report checks the XDG icon theme and desktop entries, including the paths exported by NixOS. It separates verified native output hashes, mapped but unverified names, bundled artwork, absent theme entries, and absolute icon paths. A matching native file hash outside the directories listed in the icon theme index is reported separately as `native_output_unindexed` and excluded from verified coverage; a file on disk is not necessarily visible to the theme loader. Static QML literal candidates include some non-icon references. The separate `source_references` inventory also lists QML icon bindings, private role paths, C++ theme lookups, Konsole caption roles and direct artwork. The scan is heuristic; dynamic providers and native widget internals still require runtime review. Explicit Breeze inheritance is removed. A missing theme entry can still trigger implicit toolkit fallbacks or resolve via hicolor; treat project-owned controls using those fallbacks as unresolved coverage, not verified Windows artwork. Dynamic QML names, native widget SVGs, scale selection and actual pixmaps need desktop checks. Review the report before sharing. No files are uploaded.

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
desktop user into the default XDG destination. Start and both greeter
implementations share the imported default portrait selector, and the
existing login battery control uses the same SysBatt renderer as the tray.
Missing local resources retain their documented fallback behavior; a
greeter with a different XDG data directory does not automatically see
another user's private import:

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

### Paginated Quick Settings and media layout consumers

A second pass through the original, hash-matched XBF payloads resolved
specific consumers rather than combining unrelated constants. In ShellCommon's
paginatedcontrolcenterview.xbf, TogglesGroup and SlidersGroup explicitly
reference PaginatedControlCenterViewWidth (376), and the L2Frame references
the same template's local L2FrameMinHeight (400). The footer has both
Height and MinHeight set to 48; the root MaxWidth is 380. The ordinary
ControlCenterWidth resource is 360. The KDE paginated card now uses 376
as its shared width and 400 as its detail-page minimum, preserving a
larger home height and clamping to the actual available work area. The
376px inner view is used as the KDE outer card because its host frame is
different. Overflow and non-Quick Settings applets retain their existing
widths. The logical measurements are multiplied only by the existing
optional applet UI scale; Qt owns output scaling.

The ControlCenter SplitTogglePaginatedTemplate explicitly uses
SplitToggleSecondaryWidth (48 in the light and dark dictionaries).
Use that width for the details target, clamped to half the cell in narrow
layouts, rather than forcing equal halves at every width. Keep a single
shared border and preserve the two independent actions. The high-contrast
variant and exact Windows hit-test/overlap behavior remain unresolved.
The existing 48 toggle and footer, 4 slider track and 178 media height
are now named in one tray geometry module.

The original MediaTransportControls.xbf declares F8AC and F8AD for
PreviousButton and NextButton. Its IconRepeatButtonStyle sets Segoe
Fluent Icons, 16 font size, 40 minimum width and height. The play/pause
style inherits IconButtonStyle with the same 40 minimum and 16 font size;
the play/pause control has a 26px margin on either side. The KDE media
row now uses these measurements and private, original-font role paths,
replacing its hand-painted triangles and bars. F5B0 PlaySolid and F8AE
PauseBold are verified original-font semantic choices for the two
states (see the [Segoe Fluent Icons reference](https://learn.microsoft.com/windows/apps/design/iconography/segoe-fluent-icons-font));
the exact runtime AnimatedIcon state selection and animation are not
established. Previous/Next now use Qt AbstractButton auto-repeat while
Play/Pause remains a single action. The existing original template's
IconRepeatButtonStyle reference is the basis for enabling repeat;
the 250ms initial delay and interval are the public XAML RepeatButton
[Delay](https://learn.microsoft.com/en-us/windows/windows-app-sdk/api/winrt/microsoft.ui.xaml.controls.primitives.repeatbutton.delay)
and [Interval](https://learn.microsoft.com/en-us/windows/windows-app-sdk/api/winrt/microsoft.ui.xaml.controls.primitives.repeatbutton.interval)
defaults, not measured shell-specific timings. Each invocation still
checks the current MPRIS capability. No global media aliases or backend
commands are changed. Exact press/release and repeat timing still needs
side-by-side validation.

The tray resources also establish four logical pixels of horizontal
padding on several icon content templates, and 16px in the ordinary
battery and image content definitions. Do not arbitrarily enlarge the
existing 16px tray slot solely to match screenshots. The optical
normalized glyphs, actual content geometry and small-taskbar variants
need separate validation before changing the visible tray scale.

See the source hashes, property offsets and usage records in
windows11-26h2-ui-parameters.json. No Windows binaries are added.
Live acceptance and runtime resource selection remain open.

### Ordinary taskbar Search and tray content geometry

The verified TaskbarResources.xbf minimum extents are 220 for the ordinary
full Search box (Wave3) and 100 for the compact Search pill, with corner
radius 16 in both. The full box template uses an 11px icon leading margin
and text margin (37,0,16,1); the compact content grid has 22px horizontal
padding, a 16px FontIcon and a 4px trailing icon margin. The KDE full
Search preferred baseline is now 220 rather than the sampled 248, with
2px horizontal host margins. Compact Search uses the 100px minimum and
grows to fit translated text. The existing height adaptation, full-box
icon size and label font remain provisional; the original runtime
frame height and complete style are not established. The bottom
component of the original full text margin is recorded but its exact
text baseline is not applied yet. The Search popup anchor uses the
actual rendered pill rectangle, including when the panel constrains
the applet, rather than inferring it from the preferred side margins.

The ordinary SearchBox Wave3 template resolves idle and hover to
SearchBoxTextControlBackground3 and SearchBoxTextControlBackgroundPointerOver3.
Inactive-pressed and all three active states resolve to
SearchBoxTextControlBackgroundFocused with the focused border brush.
The dark idle/hover brushes contain white at opacity 0.1435 and 0.1659;
the focused border contains white at 0.18. Apply those original inputs
and make pressed/selected share their focused fill. Resolve the light
idle/hover and light/dark focused brush inputs via the public
[WinUI common theme dictionary](https://github.com/microsoft/microsoft-ui-xaml/blob/main/controls/dev/CommonStyles/Common_themeresources_any.xaml):
light #B3FFFFFF/#80F9F9F9, focused #FFFFFFFF/#B31E1E1E (light/dark);
the light focused ControlStrokeColorDefault is #0F000000. These are
ARGB brush inputs applied over the current taskbar surface. The ordinary
idle/hover elevation border gradients and exact shell framework version
still require review; preserve the existing border approximation.
Custom, compact, shy-tablet and high-contrast state palettes
are not inferred from the ordinary full-box states. KWin output still
needs desktop acceptance.

The ordinary SystemTrayResources image template explicitly sets
16x16 and references SystemTrayIconContentPadding (4,0,4,0). The
battery templates have 16px and 12px variants and the same grid padding.
Keep the current 16px ordinary canvas; enforce the two 4px insets in
core cell sizing and battery/text sizing even at compact KDE spacing.
Vertical panels adapt the padding along their primary axis. Existing
system-group outer padding and third-party application identities are
preserved. The glyph's actual ink geometry and runtime selection of the
small variant need further review. Separate normal, small and tablet
taskbar hit margins are now recorded, but are not blindly applied to
all task buttons.

### Shared appearance and mode-specific rendering

The full installer now materializes one visible global theme, Windows
Modern. Its existing package ID (org.kde.windowsmodern.dark) is retained
for Plasma settings and the patched boot greeter; it does not select the
active color mode. The canonical package owns the desktop layout,
session splash and login resources. The historical light Store product
is now generated from this common package, not a second source package.
The NixOS transaction backs up and retires the old installed light
package; an active legacy light identity is migrated before the shell
starts, without reapplying defaults or changing the current mode.

The 120 byte-identical Plasma style files and four duplicate light
layout/splash files now have one source. The appearance materializer
builds complete dark/light renderer packages from the common base and
mode-specific values. It copies real files, so installed KPackage
resources never depend on source-tree symlinks. The existing Store
product IDs remain compatible exports of that source. No publishing
or version change is involved.

Switch the mode using the Quick Settings Dark Mode tile or
scripts/theme/switch-mode.sh light|dark. The helper changes the KDE
palette, renderer style, icon theme, Kvantum style and Aurorae decoration
using the native palette/theme utilities and KDE notifications. It never
applies a global theme, resets layout, changes wallpaper, rewrites
shortcuts or restarts the session. It retains the current accent choice
rather than generating a new accent. Missing assets are detected before
switching; a failed switch attempts to restore the previous appearance
settings. Existing applications that do not accept live style changes
may need to be reopened.

A further 13 Plasma widget SVG pairs have identical content except for
hexadecimal color literals. The materializer now generates their light
variants from the shared artwork and explicit per-widget color mappings
in scripts/theme/appearance-packages.py. The substitutions reproduce the
previous light SVGs byte for byte; geometry, element IDs, opacity and
fallback palette values remain unchanged. Edit the common SVG for layout
changes and its light mapping for mode-specific color changes. These are
existing KDE theme values, not newly decoded Windows brush roles or a
wallpaper-accent algorithm.

Another 12 widget pairs differ only in their embedded CSS role colors
and, in a few cases, accent or editor palette literals. The materializer
resolves their existing light CSS colors by role (including the three
mode-specific gradient stops) before applying the per-widget literal
mapping. All 12 previous light SVGs are reproduced byte for byte. The
same dark color may map to different light colors depending on its role;
do not combine these mappings into a single global substitution.

Seven more SVG pairs share geometry and element IDs but also have
mode-specific paint or opacity. Their light outputs now use the same
materializer with explicit role and paint overrides, including tasks.svg
(all taskbar edges and states), frame, line edit, list item, and three
background resources. Preserve the old light hover opacity, fill choices,
and existing fallback colors byte for byte. Edit the shared tasks.svg
and regenerate its derived states with scripts/theme/tasks-frames.py;
the repository health check examines both complete staged variants.

The final Plasma source overlays have been removed. The configuration
icons, separators, plasmoid heading and solid taskbar now use the same
element structure and KDE background color role in both modes. The
dark configuration icon and separator fills now use currentColor, like
the existing light assets. Their fallback colors remain unchanged;
live palette resolution must be checked in both modes. Panel and
heading fills remain explicit so the material tint is not replaced
with an unrelated palette color.

All 14 former light source files are now generated: the four shared
SVGs above, the two derived panel variants, the six popup/tooltip
variants, switch artwork and renderer metadata. The existing popup and
panel generators are reused during staging; their source commands
maintain the common dark artwork. The switch generator also writes only
the common source. All previous light renderer contents are preserved.
Transparency toggles restore files from the same appearance materializer
as installation and packaging; obsolete local light source directories
are ignored. Store renderer archive names and plugin IDs remain stable
outputs, not independent themes. The light global-theme Store export
now derives its metadata, defaults, layout and splash from the common
global package. Only two mode-specific dependency IDs and two preview
images remain separate; the identical preview/splash image is copied
when exporting. The old package ID is retained only at the external
Store/migration boundary. The installer ignores obsolete source copies,
migrates existing settings and removes the old installed package.

Aurorae now has one caption-button and layout source. The appearance
materializer generates both native decoration packages, including the
mode-specific text colors, metadata and neutral frame rendered by
window-frames.py. Nine light caption SVGs retain their old contents
exactly; maximize adopts the common crisp-edge rendering hints for
every state. Layout, button sizes, state opacities, warning red and
shadow geometry are unchanged. Normal installation, NixOS transactional
staging and Store exports use this same source. Actual fractional-scale
caption rendering needs owner acceptance.

Kvantum now shares one configuration template and one SVG geometry
template. The appearance materializer stages both native engine
configurations and artwork under the existing installed filenames.
The three duplicate light slider frame keys are removed so both modes
use the same 2 px slices. All 616 SVG IDs and their internal references
are retained. Mode-specific colors and opacity remain paint roles, not
separate geometry. Checked, mixed and radio indicators share compound
contours and backing paths; the light backing stays transparent and the
dark backing stays white. Menu indicators use the common compound
contour instead of two differently structured drawings. Focused input
corners, normal tab-frame corners, flat-button atlas placement and menu
shadow hints have common geometry. The existing selection opacities,
slider outline and window material update path remain intact. Exact Qt
SVG antialiasing and fractional-scale rendering need desktop acceptance;
these are existing Qt theme resources, not newly verified native artwork.
Both KDE color schemes now have one template and one shared fixed-role
palette, scripts/theme/palette.json. The materializer reproduces both
previous .colors files byte for byte, including their distinct inactive,
selection and semantic foreground roles. Kvantum reads its existing
palette values from that same source, and Aurorae uses the same neutral
window base. The normal installer, NixOS transaction and the KDE Store
color-scheme archive use the generated files; their historical names and
package IDs stay unchanged. Plasma's existing fixed SVG fallback roles,
dynamic accent rendering validation and material tuning are separate remaining
work. No dynamic-color behavior or renderer geometry changes here.
KDE supports adaptive SVG colors via the current-color-scheme
stylesheet (https://develop.kde.org/docs/plasma/theme/theme-colors/);
do not automatically substitute fixed Windows material colors or
opacity with unrelated palette roles. This first consolidation does not
claim that selecting an arbitrary color scheme in KDE's native Colors
page automatically changes every fixed-color renderer. Use the shared
mode switch for coordinated changes. Exact live rendering remains for
owner acceptance.

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

## Native widget accent bindings

The materializer converts reviewed solid accent paints in 18 widget atlases to KSVG's `ColorScheme-Highlight` and `currentColor`. The slider and switch also receive the shared per-mode highlight fallback. This retains element IDs, dimensions, opacity and other paint; branding and unrelated colors are not replaced. All nine accent stops in four gradient paint servers (analog meter, containment controls and glow bar) now inherit the native Highlight color via a scoped SVG group. The original offsets, opacities, IDs and linked gradients are retained. The analog meter and containment editor are KDE-specific controls without a corresponding verified Windows paint server; their three legacy teal companion stops have been removed from the shared source in favor of a uniform accent. The three opaque two-stop gradients consequently render as a flat accent, while the glow bar keeps its opacity gradient. This is a host-control styling decision, not a reconstruction of Windows accent shade formulas. Qt SVG source inspection supports the inherited-color approach, but desktop rendering still requires acceptance. KDE owns the accent by default. The opt-in Windows ramp path publishes the mode-specific final shades through the generated color schemes without KDE's additional accent mixing; native KDE preferences remain untouched.

Kvantum and KDE consume the same selected mode shade. Native KDE accent settings take precedence when the user selects them. Windows automatic mode reads the loaded local image for each active screen through the tray's Plasma 6.8 wallpaper adapter. It supports still images, slideshows and settled endpoints of scheduled day/night wallpaper packages. A preview or a crossfade keeps the previous palette. Desktop-window attachment, output, visibility and device pixel ratio changes schedule another discovery through the same debounced observer.

The shared decoder applies supported RGB and v2/v4 D50 Gray8 monitor ICC transforms before resampling. Tagged and untagged transparent PNG use premultiplied samples. GrayAlpha8 and Gray8 PNG transparency keys preserve gray input through ICC conversion; their composed alpha path is implemented but not independently measured end to end. Missing JPEG ICC fragments and unreadable PNG ICC data retain the previous automatic palette. The expanded gray curve dispatch follows the native static branch; only the two original gamma controls have independent native output hashes. Arbitrary forward LUTs, other gray profile families and non-PNG transparency remain open. See the [ICC investigation](windows11-26h2-icc-investigation.md).

### Initial automatic accent ownership

A full desktop installation with neither a stored Windows ramp nor an explicit KDE wallpaper/manual accent selection initializes the Windows automatic analyzer after wallpaper selection. A temporarily unavailable or unsupported initial wallpaper retains the measured default blue as an explicitly pending request, not an analyzed wallpaper or cached source. The existing tray retries on the next settled-image event. Existing native choices (including an explicit false wallpaper setting) and existing Windows states are preserved. The NixOS upgrade path does not implicitly migrate prior KDE automatic selection. The applet-only preview and standalone look-and-feel installer retain native defaults when no accent setting exists, without opting into Windows automatic extraction without the native wallpaper bridge.


### Version-matched live Kvantum reload

The NixOS test runtime uses a narrowly scoped patch against Qt 6 Kvantum V1.1.9 when the pinned package version is exactly 1.1.9. Other versions retain the stock plugin. No system package or declarative configuration is replaced. The appearance writer publishes `live-reload.json` beside the local theme after successful synchronization, including both mode pairs' SHA-256 hashes. The patched style records the actual user configuration and SVG as the normal theme loader opens them. It observes this receipt, acquires a nonblocking shared appearance lock, checks the actual resolved user artwork and reconstructs the same Kvantum style on the GUI thread. It clears the process-local pixmap cache and uses Qt's standard application style replacement, without a temporary Breeze style or app restart. Custom application themes, widget-local styles and application-wide stylesheet proxies are not forcibly replaced. Applications must actually load the patched Qt 6 plugin; stock Qt 5/Qt 6 processes retain their previous behavior. The source has not been built or exercised in a desktop session. Exact arbitrary ICC transforms and universal live reload remain open.

## Dynamic accent source-completion ledger

The target remains Windows 11 26H2 build 26300.9974. This ledger
replaces informal near-completion estimates. Each row has a distinct
acceptance scope. A source-complete row means the stated scope has
an implemented path, not that arbitrary inputs or live KDE behavior
have passed acceptance. A partial row requires additional implementation,
reference comparison or both. An open row has a known missing path.
Diagnostic tools, fixture collection and documentation do not count as
completed runtime functionality. Do not convert the unweighted row
count into an overall percentage.

| Acceptance scope | Source status | Remaining evidence or work |
| --- | --- | --- |
| Manual preset dispatcher and 48 stored ramps | Partial | Two preset ramps independently measured; compare the remaining 46. |
| Custom saturated CIELAB and near-gray HSL branches | Partial | Both branches exist; original-input boundary and rounding checks remain. |
| Weighted bitmap statistics and pooled image reduction | Implemented | Recorded buffer cases match; arbitrary real desktop sources require acceptance. |
| Automatic candidate normalization and fallback | Partial | Native normalization and seven-role generation are implemented; exact saturation/lightness boundaries remain open. |
| Colorization strength (alpha) calculation | Implemented | Measured candidate formula exists, distinct from surface opacity; broader image acceptance remains. |
| Opaque BMP/JPEG/PNG/WebP decoding and orientation | Partial | Supported decode path exists; WIC parity across formats and pixel variants is not established. |
| Transparent PNG processing | Partial | Shared RGB/GrayAlpha path exists; tagged GrayAlpha and additional pixel modes need reference comparison. |
| Transparent non-PNG and unreviewed pixel formats | Open | No verified decoder path for these combinations. Establish native handling before enabling. |
| Reviewed RGB matrix/TRC ICC transforms | Implemented | Independent tables and full-domain evidence for measured controls; broader profile coverage remains outside this scope. |
| Reviewed D50 Gray8 monitor ICC transforms | Implemented | Independent grid and two measured gamma ramps; extended sampled/v4 curves require reference comparison. |
| Forward RGB LUT ICC transforms | Open | Input/output curves and measured execution exist; independently generated CLUT and general supported profile dispatch remain open. |
| Remaining ICC families and profile combinations | Open | Determine the Windows decoder's supported scope; do not silently accept an approximate transform. |
| Live wallpaper discovery, events and cache invalidation | Implemented | Native Plasma still/slideshow/scheduled-image adapter; multi-screen, scale, activity and file-replacement acceptance pending. |
| Accent selection ownership and persisted original manual input | Implemented | Native selection precedence, pending automatic state, transactional writes and manual recomputation; legacy states without original input remain unchanged. |
| Full Windows-style accent selection UI and interaction | Partial | Command-based selection exists; equivalent graphical controls and native interaction coverage not established. |
| Shared dark/light palette publication, primary fill and link roles | Implemented | Both generated schemes and Kvantum use mode-specific shades; desktop acceptance pending. |
| Independent selection background, pressed/hover and on-accent roles | Partial | Host selection role currently also supplies the primary fill; audit each renderer rather than changing every KColorScheme Highlight consumer. |
| Live application refresh | Partial | Version-matched Qt 6 Kvantum path exists; stock/other renderer refresh and actual process behavior unverified. |
| Full install and mode-switch integration | Implemented | Initialization and synchronization paths exist; full installation, upgrades and live mode switches require owner acceptance. |

At this review there are 19 source acceptance scopes: eight implemented,
eight partial and three open. No live acceptance is claimed. The
remaining reference-dependent work should be batched (manual palette,
format/alpha handling and ICC scope), while renderer-role and UI work
can proceed separately. Do not spend another development batch only
adding diagnostics if an independent runtime task is ready.

Manual selections now recompute from the persisted original RGB on
synchronization and mode reapply. The previous saved palette remains the
ownership and rollback reference; a normalized Accent is never used as
a substitute for missing original input. This lets subsequent reference
corrections reach existing installations without requiring reselection.

## Phase A: shared visual foundation (Windows 11 26H2)

Reference build: 26300.9974. The layout source manifest and parameter
ledger distinguish recovered native values from host adaptations. A valid
XBF header does not establish a decoded layout or a native control mapping.

| Scope | Source status | Remaining work |
| --- | --- | --- |
| A01 PRI/XBF mapping | Partial | Recover remaining layout dictionaries and map properties to their actual consumers. The recorded 19 original files are private; the repository stores selected decoded evidence, not the full archive. |
| A02 Layout parameters | Partial | Apply all verified values and recover missing geometry. Credential width now uses the recorded 296 logical-pixel value in both hosts; their field heights remain host-specific. |
| A03 Logical pixels/DPI | Partial | Shared popup geometry exists; audit remaining layout constraints and all screen configurations. |
| A04 Typography | Partial | Start search and menu rows use actual system font metrics; baseline, line-height, fallback fonts and other surfaces need reference mapping. |
| A05 Native icons | Partial | Private import supports selected shell resources; confirm exact build, role and state coverage, including the hibernate candidate. |
| A06 Icon fallback | Partial | Lock credential actions now use mapped glyphs or action text rather than painting a toolkit fallback. Audit dynamic, implicit and same-name resolution elsewhere. |
| A07 System and application coverage | Partial | Finish native application, settings and plugin inventory; retain third-party brand identities. |
| A08 Icon optics and interaction | Partial | Establish original visible bounds, state variants and hit-area geometry for all controls. |
| A09 Cursors | Open | The current Bibata Modern Ice theme is an approximation. Original 26H2 cursor frames, hotspots and timing are not established. |
| A10 Basic controls | Partial | Shared control styling exists; compare each control's geometry and state against native evidence. |
| A11 Input, scrolling and lists | Partial | Start search adapts to system font metrics and RTL. Start, tray and clock scrollbar copies are identical again. Audit list, tab and dropdown geometry and remaining input states. |
| A12 Menus and popups | Partial | Start context, power and view-mode menus use common row extent and radius; measure other menu and popup roles against original parameters. |

The menu font sizing, minimum row extent, RTL padding and scrollbar
synchronization are host integration corrections, not newly decoded Windows
parameters. Text is retained as a functional fallback where private glyphs
are unavailable; that fallback is not counted as native icon coverage.

Package-local copies are necessary for separately installed applets and
lock/login packages. Shared-copy equality is checked by the existing
verification script; appearance and behavior still require the owner's
manual acceptance. A01–A12 are not closed by this ledger.

The existing icon coverage report compares the private manifest's recorded
input hashes with the seven hashes in the 26300.9974 owner audit, and
reports the two reference-only outputs (dark idle Search and default PNG
portrait) alongside the generic required outputs. It does not claim that
manifest metadata independently verifies the original Windows files or
runtime rendering. The broader importer remains unchanged.

The recorded KDE 6.8.3 metadata has 98 module declarations. Against the
current source mapping, 70 declarations have a matching declared icon name
or its symbolic alias and 28 do not. These are source name matches only,
not installed coverage or exact Windows semantic matches. Do not replace
KDE-specific functions or application identities just to increase counts.

### Phase A07: original glyph supplement

The complete 472,516-byte SegoeIcons.ttf blob in the existing reference
and runtime resource branches was read and SHA-256 checked against the
26300.9974 owner audit:
`031ada497ddcc9bf3f2536efba2f4bd53f12a0dead44460a4a934b06a952dd2b`.
The font's cmap contains 2,035 mapped code points; the existing required
font glyph mappings are present. The following additions have non-empty
TrueType outline data and matching semantics in Microsoft's
[Segoe Fluent Icons reference](https://learn.microsoft.com/en-us/windows/apps/design/iconography/segoe-fluent-icons-font)
and its [updated glyph list](https://learn.microsoft.com/en-gb/windows/apps/design/iconography/segoe-fluent-icons-font).

| Code point | Documented meaning | Glyph index | KDE role |
| --- | --- | --- | --- |
| F0C5 | WindowsUpdate | 892 | system-software-update |
| F87B | Spelling | 1242 | tools-check-spelling |
| F6FA | WebSearch | 1186 | preferences-web-browser-shortcuts |
| E927 | Swipe | 337 | preferences-desktop-gestures-touch |

Only the existing theme contexts and corresponding symbolic aliases are
mapped. These are semantic equivalents for the KDE controls, not claims
that a particular Windows XBF page uses these glyphs. The shared importer
and existing icon installation path remain unchanged. No font, original
artwork, new renderer or new runtime dependency is added to testing.
Keep ambiguous shared names, platform-specific functions and unverified
roles unchanged until their semantics and artwork are established.

### Reference archive recovery and reproducibility

The owner re-supplied the private layout-review archive. Its complete
compressed SHA-256 is
`c0e66b05371a0ea1f6447146d21c2b835083c35d448b4e5a0428cda66f315450`.
All 19 original source files (55,960,726 bytes) were re-read and matched
their recorded hashes. All 1,481 non-placeholder named XBF candidates
were located within their original PRI bytes by header, length and
SHA-256; the other 32 named candidates were one-byte placeholders.
This checks resource integrity, not complete node decoding or runtime
qualifier selection.

The existing UI parameter ledger now also records the zero-based
`pri_payload_offset` and `xbf_payload_bytes` for each of the 12 reviewed
XBF resources. To reproduce a lookup, use the matching source PRI,
read exactly that byte range, verify its `xbf_sha256`, then use the
recorded XBF-relative property and usage offsets. No new layout values
are inferred from the integrity check.

Retain the original archive on the owner's local storage or an authorized
private resource store; the public repository contains only the evidence
metadata. Do not rely on an earlier chat attachment being readable in a
new session, and do not put the original PRI/XBF payloads into this public
repository. If the raw bytes are unavailable, use only the previously
recorded evidence for its stated scope and leave other native-dependent
changes open.

### Shared control evidence and credential hosts

The restored original WinUI PRI contains both the modern generic theme
resource dictionary and its v1 alternative. The former declares a 4px
slider track, 18px thumb, 4px control radius and 8px overlay radius;
the latter declares a 2px track, 20px thumb, 2px control radius and 4px
overlay radius. These are separate dictionaries, not measurements to
average or interchangeable defaults. The source ledger records exact
resource offsets for the selected values. The existing Quick Settings
slider already matches the modern track and thumb baseline and is left
unchanged. Generic values for other controls are evidence for subsequent
consumer-specific review, not a reason to resize unrelated shell controls.

CommonStyles.xbf directly references the 3px field-button radius in the
submit template and reveal ButtonLayoutGrid. SubmitButtonStyle declares
28px minimum width, 24px minimum height and 12px font size. The KDE
credential hosts now share the 3px button radius through their existing
lockMetrics.js copies. The 12px font resource is used for the lock
screen's existing text fallback, not to infer glyph bounds. Their
existing host extents, authentication, focus and password reveal
behavior remain unchanged. The original forward-arrow converter's glyph
and optical bounds still need confirmation; the existing mapped arrow
roles are retained. The greeter power-menu frame uses the recorded 8px
overlay radius as the corresponding Qt menu role. The separately
installed greeter currently deploys the compatibility icon theme but not
the private native-assets tree. Its existing icon loading path is retained
to avoid a regression to text-only controls. Verified greeter asset
deployment remains an A06 blocker.

The same restored archive supplies StartResources.xbf, including the
separate small and large frame maximums (642/834 wide, 750/890 high),
96 by 84 pinned cells, 96px all-apps grid width and 156px category cards.
The source ledger records the literal resources and their pinned, grid,
category and frame references. The existing pinned cell height of 84
already matches the reference. The frame size and column-count changes
remain open until the XAML frame and the separate Photon bundle are
reconciled. No layout branch is selected by file name alone.
