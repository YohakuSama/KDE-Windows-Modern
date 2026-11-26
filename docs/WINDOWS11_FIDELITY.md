# Native Windows 11 visual fidelity

This fork replaces the upstream Windows 10/11 hybrid target. KDE and KWin remain the platform; do not fork backends or introduce a second renderer just to change appearance. Pixel-level parity is an acceptance target, not a claim about current code.

## Reference

Record Windows edition, build, locale, display resolution, scaling, accent, transparency, light/dark mode and Start settings from the owner's Windows 11 image/running VM. Until the build is identified, do not hard-code a build-specific Start menu structure as the final reference: Microsoft has changed Start between servicing releases. Compare the same configuration on KDE. Windows-specific assets are for local reference/import; source control carries original or redistributable assets.

## Material roles

Use Microsoft's [material guidance](https://learn.microsoft.com/windows/apps/design/signature-experiences/materials) and [Mica guidance](https://learn.microsoft.com/windows/apps/design/style/mica), then check the actual reference shell. Acrylic is live background blur/tint on temporary flyouts, menus and transient panels. Mica is an opaque wallpaper-tinted base for long-lived window surfaces, with active/inactive states. Smoke dims underlying UI for modal interaction. Do not call a transparent SVG Mica; do not apply Mica to all flyouts. Taskbar material and sub-surfaces must match the chosen shell build, with solid fallback when transparency is off. Use KWin/Plasma mechanisms first; implement real wallpaper sampling only where Mica needs it.

## Typography and layout

Follow the current KDE system UI font and Qt language fallback; never change font settings during a normal installation. Use regular body text and semibold section headers, scale relative to the system UI metrics and the chosen Windows 11 reference. Honor accessibility text sizing and fractional DPI. Preserve symbol glyphs independently of the text font. Pre-login UI follows the greeter session's font.

Keep theme frames in the Plasma style; share geometry, colors, typography roles and icons where components have the same visual semantics. Keep Start, clock, tray and window behavior modular. Use existing model/activation/keyboard/accessibility paths. Keep both color variants synchronized. Avoid duplicate generated files without a generator or parity check.

## Single icon library

`icons/windows-modern/` is the single installed Freedesktop icon theme. Do not
install multiple Windows-look icon packs or add per-widget hard-coded asset
paths. Keep a canonical SVG per visual role and use compatible aliases for
Desktop Entry names and state names. Identical alias content may share the
same Git blob. Preserve distinct color vs. symbolic roles, genuine application
logos, signal levels, muted/charging states and theme-aware recoloring.
Plasma FrameSVG icon sheets remain where its SVG APIs require them; use the
same icon design there rather than creating a separate user-visible theme.
Do not explicitly inherit Breeze. Keep hicolor for genuine third-party application identities. Project-owned system controls must resolve matching original Windows artwork directly; unresolved artwork must not be replaced by unrelated KDE glyphs. Qt/Plasma implicit fallbacks and unverified legacy theme assets remain coverage gaps.

Reference projects: [ELEVEN](https://github.com/innerpulsenet/ELEVEN) for
preserving panel/font settings and leveraging native KWin/Plasma geometry,
[Fluent KDE](https://github.com/vinceliuice/Fluent-kde) for theme integration,
and [Fluent System Icons](https://github.com/microsoft/fluentui-system-icons)
for consistent symbolic drawing. Review before importing; do not stack themes
or copy redundant renderers.

For original Windows reference assets, record the image build, file and
resource ID, then map by function/state, not by numeric extraction order.
Do not publish proprietary Windows resources; optional local imports can
remain outside Git. The chosen target is Windows 11 26H2 General Availability (OS build 26300), not an experimental preview. The supplied resource file versions alone do not prove the installed OS build.

## Acceptance matrix (pending unless verified on a live desktop)

| Surface | Compare |
| --- | --- |
| Start | Position, search, pinned grid, All/Recent, footer, keyboard, drag, menu; no Win10 default layout |
| Taskbar | Group alignment, size, glyphs, hover/press/indicator, overflow, multi-monitor |
| Quick Settings | Grouped entry, toggles, spacing, sliders, detail pages, material |
| Notifications/calendar | Native placement, date/time layout, cards, clear actions, material |
| Context menus/OSD | Surface role, edge, shadow, icon size, action state |
| Windows | Rounded corners where appropriate, shadow, title bar buttons, actual Mica where used |
| Lock/login | Wallpaper crop, type, account and input controls, session switching |
| Icons | Freedesktop name and alias resolution, symbolic/color states, DPI, dark/light |
| Installer | Upgrade without layout reset, reversible changes, system fonts unchanged |

Development and live acceptance are separate gates. Finish the scoped code/design changes, perform relevant source checks and use the existing CI before the combined integration merge. The owner then tests at 100%, 125%, 150%, 200%; light/dark, zh-CN and en-US, different wallpaper and system fonts, transparency on/off, and multiple monitors. Pending owner tests alone do not reduce code completion. Keep changes reversible, and do not label the integration a verified stable release or pixel-identical before live acceptance.

The [native resource importer](NATIVE_ASSETS.md) takes an explicit owner-provided archive. It generates the local canonical assets and a SHA-256 source manifest; the installer overlays only the mapped roles on the existing theme. Do not commit generated files or substitute unrelated Windows glyphs for KDE-only actions.

Shell popup frames are generated from one geometry template (see `scripts/theme/popup-frames.py`). Normal and explicit solid variants use opaque fallback colors; the translucent selector uses a consistent Acrylic-style tint with the same 8 px mask and edges. Tooltips use a distinct 4 px solid frame. Native KWin blur remains responsible for background sampling. The clock's two detached cards reuse the tray's optional native rounded-region blur helper on the same panel; without that helper, when the panel prefers opaque surfaces, or when KWin blur is disabled, both cards remain solid. No additional shader or required applet dependency is installed. Exact DWM noise, tint calibration, true wallpaper-tinted Mica and live compositor validation remain outstanding.

### Native material implementation boundary

KWin 6.8's existing blur effect provides blur strength, noise and saturation settings. Do not implement a second shader or overwrite the user's compositor preferences. Both Kvantum variants now use opaque window bases. Theme installation and transparency switching reuse the frame generator to sample the installed Windows-modern wallpaper package when optional Pillow is available. Active Aurorae and Kvantum surfaces use a bounded static tint, while inactive and disabled surfaces return to neutral. This is an approximation, not spatially adaptive Mica. Changing wallpaper independently in System Settings does not refresh the sample automatically. The transparency refresh command samples the saved local image once. Ambiguous or unsupported wallpaper sources use neutral window bases. The native panel and dialog solid selectors are also applied when transparency is disabled.

For client corners, prefer KWin's supported KDecoration3 mechanism (Breeze since Plasma 6.5), including native CSD rounding where Plasma 6.8 supports it. An owner-selected compatible upstream [KDE-Rounded-Corners](https://github.com/matinlotfali/KDE-Rounded-Corners) effect can be evaluated separately; do not install or enable it automatically. Avoid duplicate outlines and shadows. Aurorae client clipping, tiling, maximized and high-DPI behavior require live acceptance.

References: [Microsoft Mica](https://learn.microsoft.com/windows/apps/design/style/mica), [KWin native blur](https://github.com/KDE/kwin/tree/v6.8.2/src/plugins/blur), [KDE native corner rounding](https://blogs.kde.org/2025/07/19/this-week-in-plasma-rounded-bottom-corners/).

The owner clarified that the project should polish its current theme surfaces and existing applets, not rebuild the desktop. Aurorae V2 does not expose a theme-defined bottom client corner radius. Keep its existing titlebar, top rounding and shadows, and preserve KWin's native rounding for decorations that opt into it. Do not add a mandatory compositor effect or clip arbitrary application contents. See [KDE's Aurorae design notes](https://planet.kde.org/vlad-zahorodnii-2025-11-13-whats-next-for-aurorae/).

### Quick Settings acceptance detail

Use the Windows 11 scrollable Quick Settings baseline: three full-width columns, up to two visible rows, wheel/touch/keyboard navigation for later rows without a separate arrow or scrollbar rail, fixed brightness/volume/footer, direct rearrangement without a separate edit mode. Preserve existing KDE hardware availability and optional tile settings rather than adding nonfunctional Windows-only controls. Compare at the same scale in both variants; test drag into the last row, cancellation, click versus drag, persistence after logout, keyboard focus reveal, details back navigation, and wheel/touchpad scrolling. Touch reorder and exact Windows motion remain live-reference work. Reference: [Microsoft taskbar Quick Settings](https://support.microsoft.com/en-gb/windows/experience/personalization/customize-the-taskbar-in-windows) and [Microsoft keyboard/accessibility guidance](https://support.microsoft.com/en-us/accessibility/windows/navigate-and-explore-the-windows-taskbar).

### Tray geometry and current Plasma compatibility

For a standard 48 logical-pixel panel, the current project uses a 30 px task/Start canvas, a 16 px tray glyph box, 32 px normal tray cells and 24 px grouped network/volume/battery cells. The notification bell uses a 16 px glyph box in a 24 px cell. The 32 px native compact representation host is only a fallback, scaled into the smaller tray box. Preserve the source aspect ratio, state-dependent battery and network artwork, input-language text, user-selectable spacing and mirrored layouts. Qt applies the display scale. At 150%, the task canvas is 45 physical pixels and the tray box is 24 physical pixels; painted bounds depend on the artwork. These are current implementation targets, not measured Windows shell specifications. Imported artwork and native fallback delegates still require matched live comparison. Default order: overflow, application items, language, network, volume, battery, clock and notification bell, then the 6 px Show Desktop sliver. See [Windows taskbar styling measurements](https://github.com/ramensoftware/windows-11-taskbar-styling-guide#tray-icons-size) and [Microsoft Quick Settings](https://support.microsoft.com/en-us/windows/experience/personalization/customize-the-taskbar-in-windows).

### Desktop acceptance

The panel measurements in this branch are in logical pixels. The 30 px task icon canvas and 16 px tray glyph box are provisional project settings. There is no measured 26H2 screenshot in this checkout that establishes it as the Windows default. Leave output scaling to Qt and KWin. Record the Windows build, native resolution, scale, language, theme and input method with each comparison.

| Surface | Runtime and regression coverage | Outstanding desktop evidence |
| --- | --- | --- |
| Taskbar and tray | Native applet status and user pin/hide preferences decide visibility. Application artwork retains its aspect ratio. The tray reports effective-status changes to its proxy models. | Measure active glyph bounds, badge placement, drag ordering and context menus on matched displays. |
| Win+A and devices | Bluetooth uses BluezQt and the Bluedevil device page. Removable storage uses KDE's Disks & Devices applet. Per-display sliders use PowerDevil model roles. Cast launches an installed GNOME Network Displays service. Accessibility opens the installed KDE module. | Exercise pairing, failure, disconnection, USB busy/eject, external display hotplug, wireless projection and audio route changes. |
| Start, notification history, calendar, clock and OSD | Qt interaction tests cover the Start view, calendar and scrolling. The live tests in the source checkout drive the shell through real input. | Compare Chinese and English in each theme at 150%. Check focus, touchpad movement, text clipping and notification delivery in a running session. |
| Alt+Tab, Task View, snap, lock screen and window frames | The switcher suite loads the KWin layout. Window material tests exercise light and dark frame generation. | Compare window lifecycle, snap placement, gestures, lock-screen focus, shadows, animations and GPU blur in KWin. |
| NixOS lifecycle | Source builds target the installed Plasma version. The owner ZIP includes the runtime resources; desktop test suites stay in the checkout. The uninstall dispatcher has an isolated routing test. | Install, upgrade and restore on the target generation. Verify the running plugin identity after each change. |

No matched native screenshot set or target hardware session was supplied for this review. The live rows remain open. The desktop tests remain in the repository checkout under `tests/`. The lock-screen test uses a separate testing greeter.

Implementation references: [KDE Bluedevil](https://github.com/KDE/bluedevil/tree/Plasma/6.8/src/applet), [KDE Disks & Devices](https://github.com/KDE/plasma-workspace/tree/Plasma/6.8/applets/devicenotifier), [PowerDevil display controls](https://github.com/KDE/powerdevil/tree/Plasma/6.8/applets/brightness), [GNOME Network Displays](https://gitlab.gnome.org/GNOME/gnome-network-displays).

### Modern battery and grouped hover follow-up

The QML battery uses imported Windows battery-state glyphs. Replacing this legacy native family with reviewed original 26H2 artwork remains an open requirement. Compare the actual states and optional percentage against the matching Windows reference. Verify charging, charge limits, unplugged power saver, critical and unavailable battery states. The shared highlight must have no seams between adjacent network, audio and battery cells, including when percentage is enabled. Test AM/PM across midnight/noon, with the numeric date unchanged. The legacy glyphs come from Windows; the exact newer artwork is unresolved.

### Search home, clock and media source (owner reference, 2026-11-25)

The Search home reuses local Kicker usage models, existing Milou results and native applet actions. Compare both entrypoints, empty-query state, cleared filters, IME/keyboard input, actual recent/popular app launches and settings queries in the running desktop. The reference's promotional items and rewards controls are intentionally omitted. The modern colored Start search magnifier has not been verified in an owner-provided Windows resource set; the explicit local search glyph and scheme accent are a compatibility presentation, not a claim of exact original artwork. Check the region-default clock with 12- and 24-hour locales and real timezone changes; the migration of legacy forced formats is one-time. Check Firefox Nightly and Edge live MPRIS sources, controls and icon availability. No pixel similarity score or live acceptance is asserted without a same-scale screenshot comparison.

## Opt-in nested Wayland capture

The original nested desktop capture from PR #27 is retained in `tests/panel/nested-wayland.sh`. Build with `scripts/ci-build.sh BUILD_ROOT` first. Run the capture only as a separate disposable test user with a fresh Xvfb display and private session bus, for example:

```sh
WM_DISPOSABLE_DESKTOP=1 xvfb-run -a -s '-screen 0 1920x1080x24' dbus-run-session -- bash tests/panel/nested-wayland.sh BUILD_ROOT CAPTURE_DIR
```

Requires Weston, KWin, Plasma, KScreen, ImageMagick and a compatible rendering backend. The script checks the actual compiled tray and task-manager plugin mappings and records light/dark captures at 100%, 125%, 150% and 200%. It refuses an existing Plasma session and fails if rendering, scaling or plugin loading fails. This remains an opt-in integration test: the previous hosted runner could not supply a compatible nested rendering device. The normal compile and headless interaction CI does not certify physical desktop capture. Use the target NixOS live tests for the owner's hardware acceptance.

### Owner reference: boot, login and desktop background menu

The owner supplied a five-dot loading reference, centered account and password
form, account switcher with selected row, and compact desktop background menu.
The independent KSplash packages and greeter share the same five-dot source;
the Plymouth generator uses the same angular spacing. Shutdown mode hides
the boot logo and presents actual system status text. Plymouth does not expose
a separate reboot identifier through GetMode. No delay, authentication bypass
or power-state simulation is introduced.

The desktop background plugin applies a scoped light/dark row and surface
style to menus containing its own actions and associated submenus. Native
actions, availability, keyboard navigation and submenu activation remain
in Qt/KDE. Check first-open geometry, reopening, disabled paste, undo,
shortcut alignment, icons, arrows, shadow, DPI, RTL, dark/light and unrelated
application menus. Exact reference scaling was not supplied; these logical
measurements are provisional. DWM material and glyph parity remain unverified.

### Owner taskbar reference, measured at proportional scale

The supplied current screenshot is 568 x 199 pixels and its taskbar is
approximately 72 px high; the enlarged Windows crop is 1327 x 460 and its
taskbar approximately 150 px high. Comparing raw pixels is invalid.
Bright-pixel centers of the current Wi-Fi/volume/notification glyphs are
near y=164; reference Ethernet/volume near y=336. The charging battery
ink extends above its body in both screenshots. Keep its body and the
percentage on the common centerline, without offsetting all icons upward.
At a nominal 48 logical px taskbar, keep 16 px status canvases, 24 px
group cell pitch, and 32 px standalone cells. A battery is 20 px wide.
The reference implies a 40 px high hover surface and approximately
6 additional logical px before the first grouped glyph. Apply that inset
to the actual hit cell and preserve the spacing between adjacent glyphs.
Qt applies 100/150/200 percent scaling once. Simplify grouped status
tooltips to a single live status line; KDE actions remain native.
These are proportional screenshot measurements and implementation targets,
not independent certification of the reference's display scale or exact
glyph artwork. Confirm first/last cells, RTL, vertical panels, and actual
screen-space centering and tooltips in the running shell.

### Cross-platform optical size calibration

Do not equate a Windows icon resource size with a Qt source canvas. The
owner screenshots have different crop magnifications: current taskbar
approximately 71 pixels high; reference approximately 151. At a nominal
48px panel, a bright-pixel threshold of RGB channels >145 gives battery
widths 20.3/20.0, bell heights 14.9/15.3 and Chinese label heights
14.9/14.9 logical pixels (current/reference). These are measurements from
the supplied crops, not native DPI certification. Do not shrink these
already comparable surfaces.

Older bundled volume SVGs have a 22px viewport and around 16px full ink
width, while imported glyphs fill roughly 23/24 of their canvas. The
direct tray renderer now reads local SVG alpha bounds once per source,
caches a bounded result, and compensates excess padding only when the
largest ink dimension is less than 90% of the canvas. It preserves
aspect ratio, uses a shared full-volume reference for non-muted levels,
includes faint state waves and centers optical bounds. The bounded
compensation targets the imported 23/24 coverage, not a second DPI
multiplier. Unknown or unreadable assets retain normal sizing.
No changes to battery, clock, application icon sizes or the tray hit
targets are made by this correction. Confirm actual Qt rasterization
and same-scale Windows comparison in the live target session; synthetic
geometry and alpha-bound tests do not constitute visual acceptance.

### Follow-up: stable signal-state geometry and owner bundle acceptance

Measure the actual fallback SVGs using Qt's image decoder in the native
test target, including five output scale factors. Resolve standard KDE
theme names when no direct local status/action/device path is available.
Use one Wi-Fi family reference for all signal levels and a separate full
limited-network reference; do not resize weaker states independently.
The volume family retains its full-level calibration. No change to
battery or application-icon dimensions is made by this follow-up.

The private owner bundle is distinct from the public integration artifact.
Its package mode verifies exact mapped resource membership and hashes, source
SHA, pinned native resource revision, essential theme, installation,
local-build and artwork entries, and ZIP CRC integrity before adding the
package to its private manifest. Compressed byte count is not a completeness
criterion; never retain unused Windows files merely to reach a size target. Reject development tests, CI,
internal reports, historical screenshots and repository-only tools in the
owner ZIP. Keep those in the source checkout. Do not add filler or publish
the private resource bundle to the public Actions artifacts.

### Start and Search use distinct widths at the same height

The owner clarified that Search is wider than Start and must have the same
height. Keep the existing Start size preference (560 x 640 small, 768 x 720
large). Use a wider Search content size (680 x 640 small, 928 x 720 large),
subject to the same screen/work-area clamp. Preserve the common frame and
vertical placement; recompute the horizontal anchor using the actual width.
Search home and search results share one size regardless of query changes.
The width ratio of approximately 1.21 is derived from the owner's two
reference screenshots after normalizing their screen widths. Absolute
logical dimensions and compositor placement still require live calibration.

The existing live panel scenario `tests/panel/new_features.py OUT_DIR search`
measures the photographed rectangle and search-field geometry for Start,
input click, typed results, query clearing, direct taskbar Search, and Meta
typing. It checks equal height and vertical position, greater Search width
when space permits, and stable geometry within each mode. Run on a single
active display with a static contrasting desktop at each required DPI/theme.
Headless geometry tests are not live acceptance. No new CI workflow is introduced.

### Owner task preview and launcher tooltip reference

The taskbar screenshots show a short name-only label for a closed pinned
application, a live thumbnail for an open window, and a red close-hover
target. The previous task activation condition excluded launchers entirely.
Reuse the existing native non-activating tooltip window and its theme frame;
no separate popup service. Select the name-only delegate for zero windows,
keep existing grouped/text/thumbnail behavior for actual windows, and scope
shared-dialog visibility notifications to its current owner.

Use a 32 logical px close hit target, fixed header geometry, 4px radius,
red hover/darker press, and a 14px normalized icon canvas (about 12.25px
painted X, from the existing 84/96 optical normalization). The supplied
crops show a roughly 24px current X and 17px reference X; their exact DPI
is not established. Do not draw replacement artwork. Keep the original
close action and group-specific window index. A 12px native popup margin
and smaller card padding address the overly tight taskbar gap and doubled
edge inset. These are screenshot-derived targets, not Microsoft-published
metrics. Extend the existing real-session tests for launcher name, focus,
red hover surface and targeted window close, at 100% on one output first;
verify dark/light and fractional scaling visually on the target session.

### Integration audit: shared tooltip lifecycle and private package integrity

Only the current native tooltip owner may dismiss the shared window. Clear
click/hover ownership only for that task, and detach an obsolete content
delegate when a pinned app gains or loses its window. Bind the actual task
roles together before constructing the next card. Construct the lightweight
frame synchronously; keep the actual PipeWire thumbnail asynchronous. The
existing focus/preview/launcher scenarios are the live acceptance route.

Private owner archives are assembled under a temporary directory inside
`dist`, checked before publication, then renamed to the final filename.
A failed resource fetch, dirty or changing checkout, missing submodule,
incomplete archive, missing indexed resource or hash mismatch must not
publish a partially built final ZIP. Public packaging leaves prior verified
owner packages alone. The resource checker uses the existing index schema
consumed by the native asset importer. Its synthetic fixture checks do not
prove that a full pinned resource checkout was downloaded and packaged.

### Quick Settings grid and slider alignment, owner reference

In the marked reference, the usable slider groove is centered between the
outer edges of the three-column tile grid: both insets are approximately
36 logical px when normalized to the existing 312px content width. In the
owner's current capture the insets are about 30px and 43px. Equal lengths
alone are not sufficient. Use the actual grid margins for both slider rows,
with equal 27px end slots and an 18px thumb at the normal UI scale. Scale
these metrics with the existing optional panel UI scale, not display DPI.
Keep the brightness details slot inert and accessible only when present.
Remove the extra divider above the sliders and move the row separation into
the slider block, matching the owner's pictured reference proportions. The
right-hand output button uses the existing Speakers (E7F5) resource mapping
rather than MixVolumes (F4C3); the existing output routing is unchanged.
The screenshot proportions are design targets, not published Microsoft
control metrics or live Plasma acceptance. The existing actual-QML pointer
and wheel test also checks symmetric slot and groove bounds.

### Retired development branches

Keep the current main tree as the implementation baseline. The earlier
Fluent shell integration (1b511ca) and full local MUN exporter
(81db564) are retained in Git ancestry for future inspection,
not installed as parallel components. Their old popup, slider, sign-in,
style, packaging and CI implementations must not replace newer main code.
The resource reference branch already preserves the complete indexed
library; the current mapped runtime branch and existing shell inspector
remain the resource workflows. Do not add a second PE parser or duplicate
full-export tooling to the installable theme.

Restore the native microphone and desktop-portal capture indicator
classification from the earlier Fluent branch using the current visibility
policy. Reuse the existing SNI owner PID and native status updates, including
NixOS executable wrapper names. Only active or attention-state capture items
are shown; unrelated applications with matching artwork are not promoted.
No new monitor, polling, service, workflow or runtime dependency. The existing
tray status test covers the classification and active/idle visibility rules;
real microphone and screen-sharing acceptance remains a desktop test.

The history merge is an explicit retirement of older alternative source
trees, not a claim that all of their individual changes were replayed or
that all visuals were validated. Preserve the two resource branches.

## Dynamic accent acceptance (Windows 11 26H2)

Microsoft documents automatic wallpaper accent selection, and the public
[UISettings.GetColorValue API](https://learn.microsoft.com/uwp/api/windows.ui.viewmanagement.uisettings.getcolorvalue)
exposes the actual base accent and six shades. The PRI/XBF archive records
static brush references but does not disclose the shell's wallpaper
extraction and palette generation formulas. KDE extraction is the current
implementation; it is not evidence of Windows-equivalent colors.

### Captured Windows 11 26H2 baseline

The maintainer supplied seven UISettings captures from build 26300.9974,
preserved in [the runtime accent reference](windows11-26h2-accent-captures.json).
The original blue samples were produced with the v1 script argument
Automatic, but the Settings screenshot and the owner's correction
confirm the visible setting was Manual. The archive preserves the
original argument and the verified UI mode separately. The orange sample
was captured with Manual selected.

The blue ramp is the same in dark and light modes. The manual orange
sample adds a second base color:

| UISettings role | Blue | Orange |
| --- | --- | --- |
| Accent | #0078D4 | #FF8C00 |
| AccentDark1 | #0067C0 | #E37700 |
| AccentDark2 | #003E92 | #A14600 |
| AccentDark3 | #001A68 | #651900 |
| AccentLight1 | #0091F8 | #FF9910 |
| AccentLight2 | #4CC2FF | #FFB634 |
| AccentLight3 | #99EBFF | #FFD155 |

The Windows foreground/background roles invert between modes. The accent
ramp itself remained unchanged between the two blue captures. The orange
sample is currently light mode only.

### WinUI accent role mapping

The [upstream WinUI resource dictionary](https://github.com/microsoft/microsoft-ui-xaml/blob/main/controls/dev/CommonStyles/Common_themeresources_any.xaml)
defines the accent brushes separately for its Default (dark) and Light
theme dictionaries:

| WinUI role | Dark | Light |
| --- | --- | --- |
| Primary accent fill | AccentLight2 | AccentDark1 |
| Secondary fill | AccentLight2 at 90% | AccentDark1 at 90% |
| Tertiary fill | AccentLight2 at 80% | AccentDark1 at 80% |
| Primary accent text | AccentLight3 | AccentDark2 |
| Secondary accent text | AccentLight3 | AccentDark3 |
| Tertiary accent text | AccentLight2 | AccentDark1 |
| Selected-text background | Accent | Accent |
| Primary text on accent fill | #000000 | #FFFFFF |

The existing blue defaults in palette.json already match the primary
fill roles: dark uses #4CC2FF and light uses #0067C0. The orange sample
confirms that a manual Accent of #FF8C00 must use #FFB634 for a dark-mode
primary fill and #E37700 for a light-mode primary fill. The current
accentForSurface() helpers consume one Kirigami highlight color and
adjust it to a contrast threshold. They do not select the WinUI shade
roles or distinguish the base Accent used for selected-text backgrounds.
This is a confirmed implementation gap for non-default accents.

Microsoft documents that the Windows shell generates the six shades, but
does not publish the generation formula in the reviewed API documentation.
Two base colors are useful reference points, not enough to claim an exact
reconstruction. Do not fit a fixed HSL transform or hard-code the orange
sample as a general solution.

The registered wallpaper hashes for the blue dark and light captures differ.
The light blue and orange captures share a registered wallpaper hash, but
the original image hash was not supplied. The v1 script's AutoColorization
field was null, and its mode field merely echoed the command argument.
Those fields do not establish the registry mode or wallpaper algorithm.
The v2 capture script now records both known AutoColor registry locations,
the raw Explorer AccentPalette binary value, and the manual base color
observed through UISettings.

### Registry palette observation (manual orange)

The v2 orange capture reports Themes\\History\\AutoColor = 0, a Manual
registry mode with no detected conflict, and the same seven API colors as
its v1 predecessor. The 32-byte Explorer AccentPalette has eight four-byte
slots. In this capture each slot is RGB followed by 00. The first seven
slots exactly match UISettings in this order: AccentLight3, AccentLight2,
AccentLight1, Accent, AccentDark1, AccentDark2, AccentDark3. The last slot
is #0063B1; its meaning and the fourth byte's semantics are not established.
DWM AccentColor and Explorer AccentColorMenu both encode the base orange
as AABBGGRR (0xFF008CFF); StartColorMenu encodes AccentDark1 as 0xFF0077E3.
DWM ColorizationColor is recorded separately as the raw value 0xC4FF8C00.
These are observations, not a cross-version registry contract.

The format stores already-generated colors. It does not expose the
wallpaper extraction or seven-color generation formula. Do not infer the
formula from registry byte order or substitute the eighth slot for a WinUI
accent role. The existing shared-palette regression check compares the
raw bytes with the independent API capture. Keep the remaining extraction,
role propagation and live renderer refresh work open.

### Registry palette observation (automatic blue)

The v2 automatic sample reports 1 at both AutoColor locations, with no
conflict. The registered wallpaper hash, placement and reported display
size match the preceding manual orange sample. Its API Accent is #2475CE.
The first seven RGB slots again match the API; the eighth slot is #881798
and remains unassigned. Explorer AccentColorMenu encodes #2475CE
(0xFFCE7524), and StartColorMenu encodes #1C5CB2 (0xFFB25C1C).
DWM AccentColor and ColorizationColor retain the previous orange values.
Consequently, those DWM registry values alone are not a reliable source
for the current shell accent. Do not treat their persistence as a failure
of the automatic palette capture.

The matching registered wallpaper hash establishes a controlled
manual-to-automatic comparison. The archived resources/windows11 branch,
commit 272e06c87be0f548cebb2558392019b941df20d4, lists in verification.json
two byte-identical original wallpapers with this exact SHA-256:
Windows/img0.jpg and Spotlight/img14.jpg under original/Windows/Web/Wallpaper.
The fixture now records that reference separately from the v2 script's
null source_wallpaper_sha256. The archived index identifies the reference
image bytes without establishing which path the operator selected.
Do not copy the proprietary wallpaper into this development branch.
The automatic generation and extraction algorithms are still unverified.

### Manual palette generation research

The third-party [Windows Accent Colors analysis](https://gist.github.com/cnbluefire/7ffa04c493c57b8a67f6a8baa2c726f7)
describes a preset palette lookup and separate custom-color generation
paths. Its listed blue and orange presets match the measured seven-color
ramps exactly, but this does not validate its custom-color algorithm on
26H2. It explicitly excludes wallpaper automatic colorization.
Treat it as a research lead, not a Microsoft implementation or a
dependency.

### Manual preset lookup

The 48 preset base RGB values and their six reported Windows shades
are now recorded as reference color data in the existing sync-accent.py
module (336 RGB values total). No third-party executable code is
imported. The default blue #0078D4 and orange #FF8C00 rows match the
target build's independent UISettings captures in every role. The other
46 rows are reported values, not independently captured on 26H2.
The older Windows 10 published swatch list used #0078D7; the current
reference and our measured default use #0078D4. Do not add the older
color as an alias or generate preset shades using the custom formula.

The staged derive_manual_palette() entry point accepts an original
manual RGB input, checks exact preset identity first, and otherwise
uses the existing CIELAB/HSL dispatcher. It returns a new seven-role
mapping; the fixed reference rows are not mutated. Regression assertions
cover table shape, exact matching, the two measured preset colors and
the custom paths. The table stays in the existing installed module,
so no new packaging dependency or runtime file lookup is required.

The capture script v3 preserves the entered custom RGB value and the
observed base Accent separately, even when they differ. The previous
v2 cross-check rejected mismatches, preventing normalization analysis.
The owner supplied a v2 custom purple capture following the instruction
to enter #9F5A8C. Its observed base is #A25D8F; the v2 command omitted
ManualColor, so the exact entered value remains operator-context evidence,
not a field recorded by the capture. With that requested RGB, the
independently written CIELAB calculation reproduces all seven observed
colors (21 RGB channels), including the normalized base:

| UISettings role | Observed RGB |
| --- | --- |
| Accent | #A25D8F |
| AccentDark1 | #884976 |
| AccentDark2 | #662F56 |
| AccentDark3 | #401132 |
| AccentLight1 | #B173A1 |
| AccentLight2 | #D8ADD0 |
| AccentLight3 | #EECEEB |

The raw registry slots also match the seven API roles; the eighth is
#881798, unchanged from the preceding automatic capture. A read-only
calculation based on the requested input produces the complete ramp.
Reusing the normalized #A25D8F as input does not produce identical
Dark1 and Dark3, so input and output must remain distinct.

The existing sync-accent.py module now exposes a pure
derive_custom_lab_palette() function for the central CIELAB branch.
It uses standard-library color conversion and rounds intermediate RGB
values before saturation correction. It rejects extreme-lightness and
near-gray inputs, which belong to the separate legacy HSL branch.
Callers must not use either custom branch for Windows preset colors or
wallpaper extraction. The existing window-material regression suite
contains the conditional purple vector and branch rejection checks.

### Near-gray custom color (legacy HSL candidate)

The v2 capture following the request to enter #808482 reports that same
base color. The seven API colors are:

| UISettings role | Observed RGB |
| --- | --- |
| Accent | #808482 |
| AccentDark1 | #7F8381 |
| AccentDark2 | #7E8381 |
| AccentDark3 | #7E8280 |
| AccentLight1 | #808482 |
| AccentLight2 | #818483 |
| AccentLight3 | #818583 |

The input's HSL saturation is 0.016 and lightness is 130/255. The
research lead describes a low-saturation or extreme-lightness HSL branch.
Direct calculation with float32 offsets and truncation can differ by
one unit at integer boundaries for this sample. Using
the nominal decimal offsets in exact rational arithmetic matches all
seven measured RGB colors. The staged derive_custom_palette() function
dispatches the two custom branches using exact HSL boundaries and keeps
HSL truncation separate from CIELAB rounding. The exact rational
precision choice is a candidate based on this observation, not evidence
of Windows's actual arithmetic or universal equivalence. Further
boundary and independently recorded inputs remain unverified.

The raw palette has FF in the fourth byte of all seven API slots,
unlike the 00 seen in the saturated custom, preset orange and automatic
captures. The eighth slot stays #881798 followed by 00. Preserve these
observations without interpreting the fourth byte as alpha or the eighth
slot as a color role. The regression fixture records the original
requested input provenance and the separate byte pattern. No
third-party executable code or additional dependency is imported.

This is a staged calculation core, not a change to the installed
accent propagation: KDE's effective selection color remains authoritative
for Plasma and Kvantum. Applying the new ramp only to Kvantum or custom
QML while leaving KColorScheme unchanged would break color consistency.
Both custom calculation branches and the manual preset dispatcher are
now staged. Independent boundary validation, the remaining preset
measurements and automatic palette generation are open. The original automatic wallpaper is identified in the resource
index, so do not ask the maintainer to export the same image again.
No repeat of the existing color captures is needed.

### Automatic shade generation and extraction

An independent calculation using the existing CIELAB formula and the
observed Bloom automatic base #2475CE produces all seven captured RGB
roles exactly. The existing regression suite now includes that vector.
This is evidence that the custom shade calculation can reproduce one
automatic ramp once its base is known. It is not proof of the original
extraction input, a general automatic formula, or preset-table behavior
in automatic mode. Keep the manual input and observed output distinction.

Microsoft's [US8897552B2](https://patents.google.com/patent/US8897552B2/en)
and [US8847973B2](https://patents.google.com/patent/US8847973B2/en) describe
historical, differing image-color selection techniques. Neither establishes
which implementation, parameters or image preprocessing Windows 11 26H2
uses. Do not substitute a historical algorithm, KDE's clustering or an
image-hash lookup and label it as the native Windows extractor.

Plasma 6.8.3's
[wallpaper metadata reader](https://github.com/KDE/plasma-workspace/blob/v6.8.3/wallpapers/image/plugin/utils/mediaproxy.cpp)
supports mode-specific wallpaper accent colors but falls back to the
light metadata value when the dark value is absent. Its
[color applicator](https://github.com/KDE/plasma-workspace/blob/v6.8.3/kcms/colors/colorsapplicator.h)
also blends the supplied accent at 70% opacity over the view or button
background for those selection roles. Thus even a measured WinUI fill
placed in the metadata is not necessarily the effective KDE selection
RGB. Do not set partial Bloom metadata, overwrite the native palette
from a tray applet, or compensate with guessed inverse RGB values.
A later integration must distinguish raw input, the seven WinUI roles,
and the effective KDE renderer palette.

### Controlled wallpaper probes

The optional [wallpaper probe collector](../scripts/capture-windows-wallpaper-probes.ps1)
reuses the existing read-only accent capture script (schema 2 or newer)
to obtain several observations in one maintainer session. Run it only
in the reference Windows VM, with a single display, a static Picture
background and Automatic accent mode. It creates six uncompressed
24-bit BMP fixtures at the reported display size: solid purple, orange,
gray and blue, plus a pair of identical-color-area purple rectangles
on orange backgrounds, one centered and one in a corner. The pair
separates area-based selection from spatial weighting; the solid probes
separate color normalization from image selection. The intervening
gray image reduces ambiguity from successive equal palettes.

The opt-in script temporarily changes the wallpaper using the documented
IDesktopWallpaper API. It does not write accent settings, change display
mode, restart the shell, or import any external wallpaper. It refuses
non-automatic or changing appearance context and requires matching
UISettings/Explorer slots, two stable observations and the requested
wallpaper path. Samples with unchanged registered image or palette
evidence remain inconclusive, even if stable. The original image is
restored in a finally block when the current path is still owned by the
collection. The report distinguishes image restoration from palette
reproduction. Windows may update its recent wallpaper/theme history;
the script cannot restore that history and must not be used on a desktop
whose personalization history must remain unchanged.

In the folder containing both scripts, execute:

```powershell
.\capture-windows-wallpaper-probes.ps1 -ApplyTemporarily
```

Submit only the generated wallpaper-probes.json. Keep the local
restore-original-path.txt private; it is a recovery path if the
collection or restoration is interrupted. The report contains the
original capture, each exact synthetic image specification and SHA-256,
and the restoration observation, not the original absolute file path.
The tool is a reference collection utility, not an automated KDE
acceptance test, and is not installed into the Linux runtime theme.

### Measured controlled automatic palette results

The maintainer successfully ran the six-probe collection on 26H2 build
26300.9974 at 1280x800, with both light mode flags set. The complete
[probe report](windows11-26h2-wallpaper-probes.json) preserves the
observed colors, exact image recipes, SHA-256 values, raw registry
values, stable-capture flags and restoration result. All six samples
changed both the palette and the registered image relative to the
preceding sample. Source and registered hashes match for every image.
Restoration reproduced the baseline image and palette.

For these settled observations only, the low 24 bits of DWM
ColorizationColor provide a useful intermediate RGB to the existing
CIELAB calculation:

| Image | Intermediate RGB | UISettings Accent |
| --- | --- | --- |
| Bloom | #2475CE | #2475CE |
| Solid #9F5A8C | #B25098 | #B25098 |
| Solid #FF8C00 | #B75B00 | #B75B00 |
| Orange + centered purple (25%) | #BB5900 | #BB5900 |
| Solid #808482 | #6E7373 | #0078D4 |
| Orange + corner purple (25%) | #BB5900 | #BB5900 |
| Solid #2475CE | #0876CF | #0976CF |

The CIELAB calculation reproduces all seven roles for each of the six
chromatic observations (126 RGB channels, including the baseline and
both rectangle positions). The solid-blue intermediate differs from
the final Accent by one red unit. Feeding the final Accent back into
the calculation changes the generated shades; keep the intermediate
and final values distinct. Earlier transition captures had unchanged
DWM registry values, so do not use DWM as the sole source for current
shell color or assert that its value always equals a palette input.

The near-gray probe returns the full default blue UISettings ramp even
though its pre-shade candidate is #7E6E79. A second near-gray candidate
#8C6783 is accepted and normalizes to #8E6985. Their HSL saturations are
0.0678 and 0.1523 respectively. A provisional 0.15 fallback boundary
matches both observations and the existing custom CIELAB eligibility
rule, but the exact Windows cutoff is not established.

The Basic center/corner rectangle observations are identical despite
their different positions. The Refinement set also shows orange selected
when it occupies 25% against purple, 50% against purple, and 6.25%
against gray. These results exclude a pure largest-area-color lookup,
but do not identify the full selection or saliency algorithm. Solid
colored images also demonstrate hue/chroma changes before shade
generation: the image pixel RGB is not the intermediate RGB. No
historical patent supplies confirmed 26H2 extraction parameters.

The accent module's derive_automatic_palette() now applies the
provisional HSL saturation gate before the CIELAB shade calculation.
None and candidates below 0.15 return the default blue palette. A
candidate with adequate saturation but outside the reviewed HSL
lightness range raises an error rather than silently falling back.
The threshold is a measured candidate, not a confirmed native constant.

The refinement report is preserved in
[windows11-26h2-wallpaper-probes-refinement.json](windows11-26h2-wallpaper-probes-refinement.json).
Across its baseline and eight probes, the low 24 bits of the raw
HKCU\\Control Panel\\Desktop\\ImageColor DWORD match the low 24 bits
of DWM ColorizationColor. ColorizationAfterglow also matches
ColorizationColor in every capture. The upper ImageColor byte varies from 0x8A to 0xAF. A schema-5 native
COM diagnostic on the Bloom baseline returned 0xAF2475CE, exactly
matching ImageColor before and after the call. Its alpha is 175, and
its RGB matches DWM ColorizationColor. This confirms the native
ARGB/ImageColor relationship for this wallpaper on build 26300.9974.
The other eight probes were not individually checked through COM, so
do not generalize this result to every probe or Windows build. Together,
the matching RGB values link the native result, ImageColor and DWM
candidate used by the seven-color calculation. The runtime still does
not interpret the alpha byte.

For eight chromatic captures, passing the ImageColor low 24-bit RGB
through derive_automatic_palette() reproduces all seven UISettings
roles exactly (56 role colors, 168 RGB channel values). The low
saturation purple-muted-05 candidate is the single fallback. The
#8C6783 sample is the closest accepted sample above the provisional
threshold. The AccentPalette's first seven slots match the same API
colors in their established order. All probes had two stable captures,
and the original wallpaper path and palette were restored.

LiteStep's [reverse-engineered private wallpaper interface](https://github.com/lsdev/LiteStep/blob/master/litestep/DesktopWallpaper.cpp)
reads ImageColor in its GetWallpaperColor method, but the source itself
labels the interface private and contains a TODO about computing the DWM
colorization value. This corroborates the registry read path only. It
does not document how Windows selects ImageColor from wallpaper pixels.
Microsoft's [TS_ACCENTCOLOR protocol structure](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-rdperp/bc6975ee-c630-4414-ba10-04eecbb6fccc)
documents the DWM ColorizationColor, Afterglow and AccentPalette fields,
not the ImageColor extraction formula.

The automatic shade stage is now validated against nine settled
observations including the baseline. The wallpaper pixel-to-ImageColor
selection algorithm, exact saturation cutoff, and spatial/color
weighting remain unresolved. Keep derive_automatic_palette()
disconnected from runtime until the image extractor and global palette
ownership are resolved. An extraction error must never be converted
into a default-blue no-candidate result.

### Extraction refinement

The Basic captures constrain the image-to-intermediate stage but do not
identify its function. For example, normalizing the pure purple and
orange pixel colors through the existing custom CIELAB function yields
#A25D8F and #C15A00, not the measured automatic intermediates #B25098
and #B75B00. The pure blue pixel #2475CE is unchanged by that custom
normalization but gives #0876CF in automatic DWM colorization.
The five distinct chromatic intermediate colors (including Bloom)
have CIELAB L* values near 49, although the source pixels differ in
lightness and chroma. This constrains a candidate normalization stage,
not its precise formula. The raw area-weighted mean RGB of the
orange/quarter-purple images is about #E78023, unlike the observed
#BB5900; a subsequent nonlinear transform or clustering stage remains
possible.

A [third-party shell implementation](https://github.com/lsdev/LiteStep/blob/master/litestep/DesktopWallpaper.cpp)
uses the registry value HKCU\\Control Panel\\Desktop\\ImageColor
as its wallpaper-color readout. This is a research lead, not a
documented Windows 26H2 contract. The accent capture script schema 5 records ImageColor and DWM
ColorizationAfterglow in addition to the existing fields, preserving
missing values as null and raw DWORDs. Its opt-in native COM diagnostic
records the returned ARGB/alpha and compares them with ImageColor before
and after the call and DWM RGB. The bulk wallpaper-probe collector
remains a separate capture path and does not invoke the private method.

The existing collector accepts -ProbeSet Refinement, which requires
schema 4 and produces eight new controlled images without repeating
the Basic set. The maintainer supplied the complete report, which is
preserved in the curated fixture linked above:

| Probe | Purpose |
| --- | --- |
| #512E48 and #D1AEC7 | Change lightness at approximately the original purple's hue and saturation |
| #83767F and #8B6E83 | Low HSL saturation near 0.05 and 0.12 at the original purple's lightness |
| #C1389B | Higher saturation near 0.55 at the original lightness |
| Quarter orange on purple | Reverse the 25/75 area ratio of the Basic pair |
| Half purple on orange | Equal area competition |
| Small orange on gray | Test a colored region near 6.25% against a near-gray background |

The image recipes use exact 8-bit RGB and integer rectangle bounds.
The stated HSL coordinates and area fractions are approximate after
rounding. No threshold is inferred before the results are observed.
The Basic mode remains available for old captures; new reports use
schema 2 with a probe_set field. The refinement uses the same original
wallpaper restoration, integrity and stable-observation logic.

Run both updated scripts from the same VM folder, with Automatic accent
and a static Picture background:

```powershell
.\capture-windows-wallpaper-probes.ps1 -ApplyTemporarily -ProbeSet Refinement
```

Submit only the new wallpaper-probes.json. Do not replace or recapture
the completed Basic report. If ImageColor is absent, the report still
provides the remaining observations. Do not make a runtime extractor
or calibrate an image-specific lookup until the candidate transform
has been checked against independent samples.

### Extraction probe set

The collector now accepts `-ProbeSet Extraction`. This set separates
color selection from the already measured shade-generation stage. Its
solid red, green and blue inputs have approximately equal CIELAB L* 50
and HSL saturation 0.75. The muted-red input keeps the red hue and
approximately the same CIELAB lightness, with HSL saturation 0.15.

A 2010 Microsoft patent, [US8847973B2](https://patents.google.com/patent/US8847973B2/en),
describes a historical candidate for automatic wallpaper color selection:
filter near-black, near-white and near-gray pixels, group similar RGB
pixels into buckets, discard buckets below about 1% of the remaining
colored pixels, then select the bucket with the greatest average RGB
channel span. Its example also derives colorization alpha from average
per-pixel channel span. The patent's example alpha constants differ
from the values reported by later shell32 reverse engineering. It is a
research lead, not proof that Windows 11 26H2 uses the same algorithm.

The mixed images test orange area ratios of approximately 0.5%, 1%, 2%
and 4% against purple to examine the patent's proposed bucket cutoff.
The other images test vivid-red area ratios of 6.25%, 25%, 50% and 75%
against muted red. Two images compare 25% red with 75% green, then
reverse the ratio. A final corner-position sample repeats the 25% red
and 75% green composition away from the center. The report also
preserves ImageColor alpha for comparison with the average channel-span
model. These observations distinguish bucket eligibility, color-span
ranking, saturation/chroma preference, hue bias, area weighting and
spatial weighting without assuming any of those mechanisms is used by
Windows.

The Extraction set requires capture-windows-accent.ps1 schema 4 or newer
so the report includes ImageColor. It does not call the private native
COM diagnostic. Run it in the same disposable Windows VM with Automatic
accent and a static Picture background:

```powershell
.\capture-windows-wallpaper-probes.ps1 -ApplyTemporarily -ProbeSet Extraction
```

Submit only the new report. Preserve the Basic and Refinement fixtures.
The collector records every exact image recipe, source hash, stable
observation and restoration result. If a palette does not change, the
sample remains in the report as an ambiguous observation rather than
being discarded.

### Extraction results: Windows 11 26H2 build 26300.9974

The uploaded [Extraction report](windows11-26h2-wallpaper-probes-extraction.json)
contains 15 settled probes at 1280x800. All source and registered wallpaper
hashes match. Fourteen observations reached two stable captures; the
75%-red/25%-muted-red image reached 18 observations without changing the
palette from the preceding 50/50 image. Preserve that unchanged result as
a negative observation. The original wallpaper path and baseline palette
were both restored. In all 15 captures, the low 24 bits of ImageColor
match DWM ColorizationColor exactly. The private native COM method was
not requested in this run, so the registry alpha bytes are not yet
independently confirmed as native COM alpha.

| Controlled image | Patch area | ImageColor RGB | ImageColor alpha |
| --- | ---: | --- | ---: |
| Solid vivid red | — | #D24444 | 175 |
| Solid vivid green | — | #008700 | 175 |
| Solid vivid blue | — | #6868CC | 175 |
| Solid muted red | — | #956767 | 161 |
| Orange on purple | 0.5% | #B5518B | 175 |
| Orange on purple | 1% | #B65281 | 175 |
| Orange on purple | 2.03% | #B7527D | 175 |
| Orange on purple | 4% | #BC535C | 175 |
| Vivid red on muted red | 6.25% | #C54E4E | 169 |
| Vivid red on muted red | 25% | #D24444 | 175 |
| Vivid red on muted red | 50% | #D44343 | 175 |
| Muted red on vivid red | 25% | #D44343 | 175 |
| Red on green | 25% red / 75% green | #008700 | 175 |
| Red on green | 75% red / 25% green | #D24444 | 175 |
| Red on green, corner | 25% red / 75% green | #008700 | 175 |

The 0.5%, 1%, 2.03% and 4% orange patches move ImageColor gradually
away from the Basic solid-purple DWM candidate (#B25098) rather than
producing a clear 1% discontinuity. A 25% orange patch on purple in the
Refinement report does produce the orange-family candidate. These results
do not support a simple hard 1% cutoff as the whole selection rule.

The 25% red / 75% green sample selects green even though red has the
larger raw channel span (177 versus 118). Reversing the areas selects
red. Moving the same 25% red patch from the center to the corner does
not change the selected green-family result. This contradicts the
literal historical patent embodiment that selects the remaining bucket
with the greatest average channel span after a minimum-population filter.
The patent is a useful historical lead, not a 26H2 implementation
specification. See [US8847973B2](https://patents.google.com/patent/US8847973B2/en).

The first candidate score, `population × average channel span`, is
inconsistent with the Boundary results. For red #E13030 (span 177)
against green #148A14 (span 118), it predicts a 40% red tie, but the
37.5% red sample already selects the red candidate. For orange #FF8C00
(span 255) against purple #9F5A8C (span 69), it predicts a 21.30% orange
tie, but the 20% orange sample already returns an orange-family color.
The linear score is therefore rejected for these observations.

A nonlinear candidate is `population × average channel span²`. It
predicts a 30.77% red tie against green and a 6.82% orange tie against
purple. Both values lie inside the observed winner intervals: 25% red
loses to green while 37.5% red wins; the 4% orange sample remains a
transitional red-toned color while 20% orange produces an orange-family
color. This is a better fit, not a recovered Windows algorithm.

The original orange/purple pair has a large lightness mismatch. The
Scoring probe set adds a second pair with nearly equal CIELAB lightness:
orange #AB5E0B (L* 47.87, channel span 160) and purple #9F5A8C
(L* 47.72, channel span 69). Their predicted orange tie is 30.13% for
linear span weighting and 15.67% for squared-span weighting. The red
and green pair is also lightness-matched (L* 49.91 and 49.95). These
independent boundaries help distinguish a squared-span score from
other nonlinear exponents and from lightness bias.

The Boundary COM observations also revise the alpha conclusion. The
native API directly confirms that ImageColor's high byte is its alpha,
but the three solid-color points do not fit one constant integer offset:
RGB channel spans 37, 48 and 50 return alpha 161, 173 and 175. An
offset of 124 fits the first point but misses the latter two by one.
An offset of 125 fits the latter two but misses the first by one.
The earlier 15-sample Extraction set appeared to fit the 124 offset,
but that fit is not general enough to implement. The Scoring set adds
eight near-L*=50, near-20-degree-red samples with channel spans 12, 24,
36, 37, 47, 49, 50 and 51. Keep the alpha formula unresolved until
those points are measured through the native COM method.

### Boundary probe results

The uploaded [Boundary report](windows11-26h2-wallpaper-probes-boundary.json)
contains 12 settled probes at 1280x800. All 12 private COM calls returned
HRESULT 0x00000000. Native ARGB matched ImageColor before and after the
call, native RGB matched DWM ColorizationColor, and the call changed no
ImageColor value. All source and registered wallpaper hashes match.
The original wallpaper path and palette were restored.

| Probe | Source channel span or patch area | Native ARGB | Result |
| --- | ---: | --- | --- |
| Solid muted red | 37 | 0xA1956767 | alpha 161 |
| Solid muted red | 48 | 0xADA46161 | alpha 173 |
| Solid muted red | 50 | 0xAFA75F62 | alpha 175 |
| Red on green | 37.5% red | 0xAFD24444 | red family |
| Red on green | 40% red | 0xAFD24444 | red family, unchanged palette |
| Red on green | 42.5% red | 0xAFD24444 | red family, unchanged palette |
| Orange on purple | 20% orange | 0xAFC65113 | orange family |
| Orange on purple | 21.25% orange | 0xAFC55213 | orange family |
| Orange on purple | 22.5% orange | 0xAFC4530E | orange family |

The red-on-green results move the observed winner boundary below 37.5%,
not at the linear model's 40% prediction. The orange-on-purple result
already moves into the orange family at 20%, below the linear model's
21.30% prediction. Three captures reached 18 stable observations with
no palette change; these are retained as negative observations rather
than discarded.

### Boundary probe set

The collector accepts `-ProbeSet Boundary`. It was designed around the
earlier linear-score hypothesis and its results reject that hypothesis.
The three solid colors also supplied direct native-alpha measurements.
Use `-IncludeNativeWallpaperColor` only in the disposable Windows
reference VM. The private API is undocumented.

### Scoring probe set

The collector now accepts `-ProbeSet Scoring`. It brackets the squared
channel-span hypothesis using two hue pairs and adds an equal-lightness
orange/purple pair to avoid the brightness mismatch in the first set.
It also adds eight solid colors near CIELAB L*=50 and hue 20 degrees,
with channel spans 12, 24, 36, 37, 47, 49, 50 and 51 for the alpha study.

Run it in the same disposable Windows VM with Automatic accent and a
static Picture background. The native COM diagnostic is opt-in and is
called once per settled sample, not during the polling loop:

```powershell
.\capture-windows-wallpaper-probes.ps1 -ApplyTemporarily -ProbeSet Scoring -IncludeNativeWallpaperColor
```

The collector records the HRESULT, native ARGB/alpha, ImageColor before
and after the call, and DWM RGB. It checks that the appearance did not
change between the settled capture and the diagnostic. Submit the new
`wallpaper-probes.json` report. The original wallpaper is restored and
verified by the collector.

### Native automatic-color diagnostic

OpenGlass reverse-engineers the private
`IDesktopWallpaperPrivate::ComputeImageColorizationColor` shell32 method.
Its implementation obtains a native ARGB result, retains its alpha, then
requests the Shell's forced wallpaper transition and reads the applied
DWM RGB. The project explicitly avoids reproducing Windows' image-analysis
algorithm. See its [private interface declaration](https://github.com/ALTaleX531/OpenGlass/blob/b6dcd558ca5d842ac0b0b065cfcf2d76def9f9d7/Common/DesktopWallpaper.hpp)
and [color hook](https://github.com/ALTaleX531/OpenGlass/blob/b6dcd558ca5d842ac0b0b065cfcf2d76def9f9d7/OpenGlassThemeExtension/ColorHooks.Shell.cpp).
Its documented shell32 builds are 10.0.17763.737 and 10.0.26100.9549.
This is reverse-engineered, undocumented behavior, not a 26H2 API contract.

The baseline capture on build 26300.9974 returned 0xAF2475CE. Its full
ARGB matched ImageColor before and after the call, including alpha 175,
and its RGB matched DWM ColorizationColor. The call did not change
ImageColor in this observation. This confirms the registry/private-method
relationship for the baseline wallpaper only; it does not establish the
same result for every probe or another Windows build.

The [accent capture script](../scripts/capture-windows-accent.ps1)
has an opt-in `-IncludeNativeWallpaperColor` diagnostic. It invokes only
the private color-computation method, and only after both registry mode
values confirm Automatic. It does not send the forced Shell refresh
message, change wallpaper or explicitly write registry values. The
private method's internal side effects are undocumented, so the capture
records ImageColor both before and after the call. It also records the
HRESULT, native ARGB/alpha and comparisons against DWM RGB. Manual or
conflicting mode is skipped. An unavailable private interface is
reported without discarding the ordinary capture. This diagnostic is
not used by the bulk probe collector or the Linux runtime theme.

Run it once on the current Automatic wallpaper:

```powershell
.\capture-windows-accent.ps1 -AccentMode Automatic -IncludeNativeWallpaperColor
```

The baseline result is preserved in
[windows11-26h2-accent-captures.json](windows11-26h2-accent-captures.json).
The full match confirms both the native alpha and RGB relationship for
this sample. It does not reveal how Windows selects RGB from image pixels.

### Native colorization-strength alpha

A second OpenGlass reverse-engineering note describes the native image
analysis alpha for shell32 10.0.17763.737 and 10.0.26100.9549:

`alpha = min(175, 125 + floor(rangeSum / pixelCount))`

`rangeSum` sums `max(R,G,B) - min(R,G,B)` over nontransparent
analysis pixels. `pixelCount` uses the full analysis image area, including
skipped transparent pixels. The inspected implementation caps each
analysis dimension at 256 pixels and combines sums/counts across images.
The note distinguishes legacy unpremultiplication from the 26100
feature-41486951 weighted-RGB path. It also records a native fallback
alpha of 196 and cached `ImageColor` during initialization. See the
[reverse-engineered analysis notes](https://github.com/DreY85/OpenFluidGlass/blob/49dd5176acd3afabc03066680a2de2b59296e472/OpenGlassGUI/Configuration.design.md)
and [native implementation notes](https://github.com/DreY85/OpenFluidGlass/blob/49dd5176acd3afabc03066680a2de2b59296e472/OpenGlassThemeExtension/Design.md).

This describes colorization strength derived from image RGB statistics,
not the wallpaper file's transparency. It is a third-party reverse
engineering result for two older shell32 builds, not a guaranteed 26H2
contract. Our refinement samples support it: the small orange region on
gray predicts alpha 144 and reports 0x90; the two mixed orange/purple
images exceed the 175 cap and report 0xAF; the two muted purple samples
predict 138 and 154 and report 0x8A and 0x9A. The two solid samples with
channel range 35 report 159 rather than the simple formula's 160, so
the exact 26H2 preprocessing/rounding remains to be checked. This makes
the varying ImageColor high byte consistent with native colorization
strength, not image transparency.

The optional COM diagnostic has confirmed the baseline relationship.
That baseline alpha is at the 175 ceiling, so it does not independently
validate the alpha formula. The lower alpha values in the refinement
set remain registry observations, not separate COM checks. No alpha
formula is wired into the runtime theme. The wallpaper-to-RGB selection
algorithm remains a separate unresolved problem.

### Capture procedure

For maintainer acceptance, use a single display and a static picture in
the target Windows VM. Set Personalization > Colors > Accent color to
Automatic, select the exact original wallpaper used on KDE, and let the
wallpaper transition finish. Run the read-only
[accent capture script](../scripts/capture-windows-accent.ps1) from
Windows PowerShell 5.1:

```powershell
.\capture-windows-accent.ps1 -AccentMode Automatic -SourceWallpaper 'C:\path\wallpaper.jpg' |
    Set-Content -Encoding UTF8 accent-automatic.json
```

The script reports the Windows build, both appearance modes, wallpaper
placement, display size, all seven runtime accent colors, and raw values
from both known AutoColor registry locations. Its optional native-color
diagnostic is described above and is disabled by default. It also records the raw
Explorer AccentPalette bytes, DWM/Explorer accent DWORDs, and the base
Accent observed through UISettings when Manual is selected. It hashes the
registry-selected wallpaper file and, when supplied, the original image.
The two hashes may differ because Windows can transcode the wallpaper.
The original path is operator-supplied; it is not independently proven to
be the active image. No file paths are included in the JSON. The command
argument and registry-derived mode are separate fields. A missing or
conflicting registry value remains unknown. Two identical snapshots one
second apart reject observed changes but cannot prove the shell has
finished updating. Use the script only after the visible transition has
settled.

Capture the same original image in both modes, then repeat with warm,
green, purple and neutral images. Keep the display and wallpaper
placement fixed. Use a unique JSON filename for each capture. For manual
accent references, select a known color in Windows and run the following
command. The script records the actual base Accent from UISettings;
the optional ManualColor argument records the operator-entered RGB. The
schema 3 and later report a match or mismatch without rejecting the capture:

```powershell
.\capture-windows-accent.ps1 -AccentMode Manual -ManualColor '#9F5A8C' |
    Set-Content -Encoding UTF8 accent-manual-custom.json
```

Repeat manual captures for several distinct hues and the default blue,
in both light and dark modes. These independent references separate
wallpaper-to-base-color extraction from base-to-shade generation. Compare
Windows AccentLight2 in dark mode and AccentDark1 in light mode against
the live KDE selection role and screenshots. Do not fit a purported
native algorithm from only the default blue example. Record unseen images
and manual colors separately for eventual acceptance. Until the extraction
and custom-color generation algorithms are independently validated,
retain KDE's own extraction and do not claim equivalence.

On KDE, keep Dolphin and Konsole open during a manual accent change, a
wallpaper change, and both dark/light switches. Verify slider, checkbox,
progress, focus, selection, glow and taskbar indicator colors. Check an
existing window and a newly opened window separately. The destination
Kvantum atlas is synchronized before a mode switch, but same-style
reload is not guaranteed by Qt/Kvantum. Do not mark that condition
passed until it is observed in the target session. No application
restarts or temporary fallback-style cycling are part of this check.
