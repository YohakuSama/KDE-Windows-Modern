# Native Windows 11 visual fidelity

This fork replaces the upstream Windows 10/11 hybrid target. KDE and KWin remain the platform; do not fork backends or introduce a second renderer just to change appearance. Pixel-level parity is an acceptance target, not a claim about current code.

## Reference

Record Windows edition, build, locale, display resolution, scaling, accent, transparency, light/dark mode and Start settings from the owner's Windows 11 image/running VM. Until the build is identified, do not hard-code a build-specific Start menu structure as the final reference: Microsoft has changed Start between servicing releases. Compare the same configuration on KDE. Windows-specific assets are for local reference/import; source control carries original or redistributable assets.

## Material roles

Use Microsoft's [material guidance](https://learn.microsoft.com/windows/apps/design/signature-experiences/materials) and [Mica guidance](https://learn.microsoft.com/windows/apps/design/style/mica), then check the actual reference shell. Acrylic is live background blur/tint on temporary flyouts, menus and transient panels. Mica is an opaque wallpaper-tinted base for long-lived window surfaces, with active/inactive states. Smoke dims underlying UI for modal interaction. Do not call a transparent SVG Mica; do not apply Mica to all flyouts. Taskbar material and sub-surfaces must match the chosen shell build, with solid fallback when transparency is off. Use KWin/Plasma mechanisms first; implement real wallpaper sampling only where Mica needs it.

## Typography and layout

Follow the current KDE system UI font and Qt language fallback; never change font settings during a normal installation. Use regular body text and semibold section headers, scale relative to the system UI metrics and the chosen Windows 11 reference. Honor accessibility text sizing and fractional DPI. Preserve symbol glyphs independently of the text font. Pre-login UI follows the greeter session's font.

Keep theme frames in the Plasma style; share geometry, colors, typography roles and icons where components have the same visual semantics. Keep Start, clock, tray and window behavior modular. Use existing model/activation/keyboard/accessibility paths. Keep both color variants synchronized. Avoid duplicate generated files without a generator or parity check.

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

Test at 100%, 125%, 150%, 200%; light/dark, zh-CN and en-US, different wallpaper and system fonts, transparency on/off, at least two monitor arrangements. Run repository health checks, Qt tests, C++ builds and live screenshot/e2e checks. Unverified work stays draft; don't label it a release or pixel-identical.
