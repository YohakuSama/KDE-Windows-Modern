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
