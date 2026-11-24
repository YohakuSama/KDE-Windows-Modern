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

Shell popup frames are generated from one geometry template (see `scripts/theme/popup-frames.py`). Normal and explicit solid variants use opaque fallback colors; the translucent selector uses a consistent Acrylic-style tint with the same 8 px mask and edges. Tooltips use a distinct 4 px solid frame. Native KWin blur remains responsible for background sampling. Exact DWM noise, tint calibration, true wallpaper-tinted Mica and live compositor validation remain outstanding.

### Native material implementation boundary

KWin 6.8's existing blur effect provides blur strength, noise and saturation settings. Do not implement a second shader or overwrite the user's compositor preferences. Both Kvantum variants now use opaque window bases. Theme installation and transparency switching reuse the frame generator to sample the installed Windows-modern wallpaper package when optional Pillow is available. Active Aurorae and Kvantum surfaces use a bounded static tint, while inactive and disabled surfaces return to neutral. This is an approximation, not spatially adaptive Mica. Changing wallpaper independently in System Settings does not refresh the sample.

For client corners, prefer KWin's supported KDecoration3 mechanism (Breeze since Plasma 6.5), including native CSD rounding where Plasma 6.8 supports it. An owner-selected compatible upstream [KDE-Rounded-Corners](https://github.com/matinlotfali/KDE-Rounded-Corners) effect can be evaluated separately; do not install or enable it automatically. Avoid duplicate outlines and shadows. Aurorae client clipping, tiling, maximized and high-DPI behavior require live acceptance.

References: [Microsoft Mica](https://learn.microsoft.com/windows/apps/design/style/mica), [KWin native blur](https://github.com/KDE/kwin/tree/v6.8.2/src/plugins/blur), [KDE native corner rounding](https://blogs.kde.org/2025/07/19/this-week-in-plasma-rounded-bottom-corners/).
