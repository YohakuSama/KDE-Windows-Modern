# Windows Modern — Product Brief

This file states what the project is for and what it is not. Every new feature,
and every "should we add X?" question, is judged against it.

## Vision

**Sit down at a Windows Modern desktop and feel at home as a Windows user,
on Linux.** It should look, move, and respond like Windows 11, so your
muscle memory just works, with KDE Plasma underneath.

This fork targets **native Windows 11 visual fidelity**: layout, typography,
iconography, motion and the correct material on each surface. Preserve KDE's
existing backends and user settings wherever possible. See
[`docs/WINDOWS11_FIDELITY.md`](docs/WINDOWS11_FIDELITY.md) for the reference
and acceptance process.

## Who it is for

- People moving from Windows to Linux who want their desktop to keep working
  the way their hands expect.
- Linux users who like the Windows 11 design language and want it done
  properly, not as a skin.
- The maintainer's own daily driver: if something feels off in daily use, it's
  a bug.

## Principles

1. **Behaviour matters as much as looks.** Keyboard shortcuts, Alt+Tab,
   window snapping, notifications and flyouts count as much as colours and
   icons. A Windows user should rarely hit "that's not where it is" or "that
   key does something else".
2. **Windows 11 is the sole visual baseline.** Do not hand-draw replacement Windows system glyphs or misrepresent compatibility artwork as an original asset. Use verified locally imported originals; record unavailable assets as fidelity blockers. Replace inherited Windows 10
   layouts when they differ from the chosen Windows 11 build. Keep existing
   KDE services, minimize changes, and share visual rules only where semantics
   match. System fonts remain the default.
3. **No slop** (see the list below). If a Windows feature exists to sell,
   track, distract, or advertise, it doesn't come along.
4. **Dark and light are equal.** Every surface ships in both variants. A
   light-only or dark-only gap is a bug.
5. **Build on KDE, don't fight it.** Use KWin and Plasma's own mechanisms
   (window-switcher layouts, tiling, effects, look-and-feel packages, global
   shortcuts) wherever they exist. Theme first; customize presentation and
   interaction only where the Windows 11 reference requires it. Keep native
   KDE pages for complex operations and show only real, supported actions;
   never simulate successful backend state or add decorative dummy buttons.
   Forks of upstream code (System Tray, Icon Tasks) stay as small as possible
   so they survive Plasma updates.
6. **Never break the user's system.** Every install step is reversible, files
   owned by distro packages are moved aside and restored rather than deleted,
   nothing is built as root, and a failed install leaves the previous state
   intact.
7. **No Microsoft assets are redistributed.** Windows fonts, cursors, sounds
   and wallpapers are not shipped. Use openly licensed equivalents, and use
   the real thing only when the user already has it installed (for example
   Segoe UI).

## In scope

Windows 11 surfaces and behaviours a user reaches for without thinking:

- Taskbar, Start menu, system tray and quick settings, clock/calendar flyout,
  Show Desktop.
- Window chrome, controls, widget style, colours, icons, cursors, typography.
- Alt+Tab, Task View, window snapping and Snap Layouts.
- Notifications (toasts) and the volume/brightness OSD.
- Lock screen and login screen.
- Windows keyboard shortcuts (Win+E, Win+Tab, Win+Shift+S, Win+V, Win+.,
  Win+I, Win+D, Win+L, Win+arrows).
- Small per-app touches so common non-KDE apps match (see `app-decorations/`).

## Out of scope ("slop")

Not added, even on request, unless this brief changes:

- Widgets board / news and interests feed.
- Online suggestions, ads or promoted content in Start. Local recent items
  may be shown in the reference layout and respect privacy settings.
- Web or Bing results mixed into local search.
- Copilot or any AI/assistant entry point.
- Ads, tips, "get started", promoted apps, suggestions.
- Windows 10 live tiles.
- A Recycle Bin icon on the desktop (the Trash is in Explorer's sidebar).

## Visual target (work in progress)

- Start: search at the top, responsive pinned grid, inline Recent and All
  list, account/folder/power footer. Category/grid alternatives for All and
  the exact reference layout remain integration follow-ups.
- Tray: Windows 11 grouped Quick Settings entry, overflow placement,
  notification/calendar placement and flyout structure.
- Window decorations: rounded corners and shadow/elevation where the target
  Windows 11 build uses them.
- Lock and login: match the selected reference build, using the system font
  of the applicable session.
- Existing implementation details are not acceptance criteria. Do not mark
  parity complete without comparing screenshots and behavior against the
  reference build at equivalent scaling.

## Roadmap

| Status | Item | Notes |
|--------|------|-------|
| Done | Windows 11 Alt+Tab switcher | `plasma/windowswitcher/`, selected by both global themes. |
| Done | Windows shortcuts, cursor, everyday apps | `./install.sh shortcuts` / `apps`; Win10OS cursors (fetched from upstream, GPL-3.0). Win+X (power-user menu) is not mapped. |
| Done | OSD position, Cascadia Mono | KWin script for the OSD; Cascadia Mono via `./install.sh apps`. |
| Done | Dolphin status bar | Patched rpm (`scripts/fix-dolphin-statusbar.sh`); stock fixes itself from Dolphin 26.12. |
| Done | Window animations | KDE's defaults match Windows 11; "Everything" only turns off the corner-sliding Show Desktop effect, unless the user set it. |
| Done | Optional fonts | System font settings are preserved by default. Explicit `./install.sh fonts` offers Segoe UI or Selawik, Cascadia Mono. |
| Done | Snap Layouts | Drag-to-top layout bar (`plasma/kwinscripts/org.kde.windowsmodern.snaplayouts`). The maximize-button hover flyout is not possible with an Aurorae decoration. |
| Done | Prebuilt C++ plugins | Releases carry the tray and taskbar plugins per Fedora/Plasma/Qt version; a release checkout installs them without a compiler, anything else builds from source. |
| Done | KDE Store | Every component is its own store item; the global themes depend on them, so a Discover install brings the look. Published with `scripts/store/`. |
| Integrating | Quick Settings | Separate overflow and grouped system icons, toggles and sliders, Windows 11 footer. Live validation pending. |
| Integrating | Notifications in the clock flyout | Shared KDE notification history above the calendar, Win+N, dismiss, clear, actions and manual DND. Native tray applet retains jobs and advanced functions. Live validation and exact reference layout pending. |

## How to judge a new idea

1. Would a Windows 11 user reach for it without thinking? If not, it probably
   doesn't belong.
2. Is it on the slop list? Then no.
3. Does KDE already provide the mechanism? Then theme or configure it rather
   than rebuild it.
4. Does it ship in both dark and light, and can it be uninstalled cleanly?
