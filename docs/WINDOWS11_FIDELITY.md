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
Retain Breeze/hicolor as a compatibility fallback for unknown applications,
not as the intended source of the Windows shell's own glyphs.

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

For a standard 48 logical-pixel panel, the current project uses a 28 px task/Start canvas, a 16 px tray glyph box, 32 px normal tray cells and 24 px grouped network/volume/battery cells. The notification bell uses a 16 px glyph box in a 24 px cell. The 32 px native compact representation host is only a fallback, scaled into the smaller tray box. Preserve the source aspect ratio, state-dependent battery and network artwork, input-language text, user-selectable spacing and mirrored layouts. Qt applies the display scale. At 150%, the task canvas is 42 physical pixels, its 87.5% painted extent is 36.75 physical pixels, and the tray box is 24 physical pixels. These are current implementation targets, not measured Windows shell specifications. Imported artwork and native fallback delegates still require matched live comparison. Default order: overflow, application items, language, network, volume, battery, clock and notification bell, then the 6 px Show Desktop sliver. See [Windows taskbar styling measurements](https://github.com/ramensoftware/windows-11-taskbar-styling-guide#tray-icons-size) and [Microsoft Quick Settings](https://support.microsoft.com/en-us/windows/experience/personalization/customize-the-taskbar-in-windows).

### PR 21 desktop acceptance

The panel measurements in this branch are in logical pixels. The 28 px task icon canvas and 16 px tray glyph box are provisional project settings. There is no measured 26H2 screenshot in this checkout that establishes it as the Windows default. Leave output scaling to Qt and KWin. Record the Windows build, native resolution, scale, language, theme and input method with each comparison.

| Surface | Runtime and regression coverage | Outstanding desktop evidence |
| --- | --- | --- |
| Taskbar and tray | Native applet status and user pin/hide preferences decide visibility. Application artwork retains its aspect ratio. The tray reports effective-status changes to its proxy models. | Measure active glyph bounds, badge placement, drag ordering and context menus on matched displays. |
| Win+A and devices | Bluetooth uses BluezQt and the Bluedevil device page. Removable storage uses KDE's Disks & Devices applet. Per-display sliders use PowerDevil model roles. Cast launches an installed GNOME Network Displays service. Accessibility opens the installed KDE module. | Exercise pairing, failure, disconnection, USB busy/eject, external display hotplug, wireless projection and audio route changes. |
| Start, notification history, calendar, clock and OSD | Qt interaction tests cover the Start view, calendar and scrolling. The packaged live tests drive the shell through real input. | Compare Chinese and English in each theme at 150%. Check focus, touchpad movement, text clipping and notification delivery in a running session. |
| Alt+Tab, Task View, snap, lock screen and window frames | The switcher suite loads the KWin layout. Window material tests exercise light and dark frame generation. | Compare window lifecycle, snap placement, gestures, lock-screen focus, shadows, animations and GPU blur in KWin. |
| NixOS lifecycle | Source builds target the installed Plasma version. The owner ZIP includes the runtime resources and desktop test suites. The uninstall dispatcher has an isolated routing test. | Install, upgrade and restore on the target generation. Verify the running plugin identity after each change. |

No matched native screenshot set or target hardware session was supplied for this review. The live rows remain open. The owner ZIP contains the tests under `tests/`. The lock-screen test uses a separate testing greeter.

Implementation references: [KDE Bluedevil](https://github.com/KDE/bluedevil/tree/Plasma/6.8/src/applet), [KDE Disks & Devices](https://github.com/KDE/plasma-workspace/tree/Plasma/6.8/applets/devicenotifier), [PowerDevil display controls](https://github.com/KDE/powerdevil/tree/Plasma/6.8/applets/brightness), [GNOME Network Displays](https://gitlab.gnome.org/GNOME/gnome-network-displays).

### Modern battery and grouped hover follow-up

Compare the project-drawn colored battery and optional percentage against KB5067036 and the owner's screenshot at 150%. Verify charging, charge limits, unplugged power saver, critical and unavailable battery states. The shared highlight must have no seams between adjacent network, audio and battery cells, including when percentage is enabled. Test AM/PM across midnight/noon, with the numeric date unchanged. The visual asset is recreated, not extracted from Windows.


## Start letter index and Run dialog

The alphabetical All Apps headings open an animated letter index. Available letters are highlighted, unavailable letters remain dimmed, and selecting one scrolls to its first application. Win+R opens the separate Windows Modern Run dialog. The dialog submits the typed command through the existing system tray's KIO command launcher and respects KDE's `run_command` authorization. The Windows keyboard shortcut installer removes Meta+R from KRunner before the hidden applet registers it. The hidden zero-size applet is loaded on the primary panel only for the global shortcut.
