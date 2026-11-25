# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
the `Version` field shared by every component's metadata.

## [Unreleased]

- Reuse the tray palette in the clock and Start menu, and check packaged copies for drift. Retain calendar delegates across same-day clock updates, avoid tracking hidden seconds, and correct notification links and time-zone formatting.

- Keep week numbers aligned with local calendar dates through daylight-saving transitions, align weekday columns, and allow keyboard activation of calendar navigation and zoom tiles.
- Keep the calendar footer visible in short work areas by fitting the grid before optional sections; use consistent notification actions, progress colors and scrolling feedback.

- Use live KDE battery time and health data, remove the UPower polling subprocess, and open the native power settings module directly.
- Correct audio device selection states and microphone icons; keep input switching from playing feedback on a sink index. Reuse the same slider for brightness details and app volume, preserve two-line captions and reduce visible tile rows on small work areas.

### Fixed tray reference baseline

- Restore the 16px tray canvas, chevron and bell while retaining original optical-normalized assets, normal hit targets and the separate wider battery cell. Avoid the previous double enlargement of imported glyphs. Guard standard sizes at 100–200% output scales.

### Original battery assets only

- Remove the project-drawn colored battery. Render the imported Microsoft Segoe Fluent Icons battery, charge and energy-saver glyphs without inventing geometry. The newer SysBatt artwork is still missing from the verified inputs.
- Keep the taskbar percentage independently configurable, off by default for new installs; expose the same preference in battery details and preserve the Quick Settings battery percentage.

### Tray optical correction and notification build fix

- Increase normal tray glyph canvases to 20px without enlarging the default cell pitch; normalize the native removable-device status glyph, use its direct renderer and widen the centered battery artwork.
- Disable SNI icon rounding, enlarge the bell and chevron, and avoid overriding the final Qt Button highlighted property in the notification center.

### Notification center and calendar polish

- Frame history and calendar separately, reduce typography and spacing, default the optional large clock off, and distinguish app headings from message cards and timestamps.
- Add a functional focus countdown and duration controls, preserving independent notification inhibition settings. Add regression tests for layout separation and focus state.

### 26H2 shell polish and integration fixes

- Synchronize the login date formatter with the shared clock/lock-screen version to fix the repository health gate.
- Add Start size and independent section settings, persistent pin expansion, identity privacy, and collapse empty home sections. Use the current Recent terminology, compact pin spacing and the existing scroll surface.
- Refine the sound-output affordance and keyboard-accessible detail controls; retain the native audio backend.

### Windows 11 26H2 Start and Quick Settings

- Use responsive category preview cards and list/grid/category selection in the inline Start home, compact the search field and pinned preview, and remove the redundant All apps shortcut.
- Restore conditional Quick Settings page dots and a single direction arrow; refine tile spacing, split controls and Fluent slider proportions without replacing the KDE backends.

### Calendar and panel optical balance

- Accumulate calendar wheel deltas, ignore horizontal and zero input, and limit touchpad swipes to one page until idle.
- Increase task and tray glyph canvases without changing the default panel height or tray cell pitch; center the project-drawn battery outline and terminal. Live Windows 11 comparison remains pending.

### Native status and power controls

- Reuse PowerDevil's manual inhibition state in both existing controls; remove shell polling and process-name termination.
- Align battery levels, unknown-state and lock-screen symbolic icons, and add five native device aliases.

### Materials and status glyphs

- Keep application bases opaque; reuse the existing wallpaper/frame generator for a bounded local active tint and KWin for popup blur/noise.
- Add 22 native icon mappings for account switching, limited networks, VPN and unknown charging.

### Combined pre-release integration

- Add native app category navigation, application-grouped notifications,
  and Quick Settings keyboard/device-state refinements.
- Constrain taskbar group previews to their panel monitor.
- Generate matching light/dark Aurorae titlebar corners and native shadows,
  including separate maximized frames; keep client-area corners safe.
- Follow locale time formatting in lock/login, and document the native
  Plasma Login Manager wallpaper import route.

### Start menu

- Separate account and power actions using the existing in-dialog popup and
  native KDE session capabilities. Restore focus after dismissal and support
  arrow, Tab and Enter navigation through enabled rows.
- Fix stale search-field references in filter and keyboard handlers, move
  focus into the selected results view, and use the All list if pins are empty.

### Lock and login

- Replace square unlock/login text field frames with matching 4 px corners,
  36 px height and a bottom focus accent. Keep the native authentication path.
- Standalone session-lock installation selects the native lock wallpaper when
  installed; it leaves the desktop and missing-resource fallback unchanged.

### Integration refinements

- Do Not Disturb toggles now change the user's manual preference only; they
  do not revoke application inhibition or overwrite screen-mirroring state.
- Notification history uses an explicit clock binding and supports inline
  replies when the native notification advertises a reply action. Add a
  collapsible calendar while retaining the existing agenda.
- Extend the native icon map to 389 paths, covering verified power,
  bell, snooze, offline network and cellular roles.

### Materials

- Generate matching dark/light popup frames with consistent geometry, border,
  blur masks, shadow margins and opaque fallback. Use 8 px dialog and 4 px
  tooltip corner radii. Preserve native KWin blur; no new compositor plugin.
- Add a deterministic frame-generation check to the repository health gate.

### Native Windows resources

- Expand the local icon map to 407 paths, including microphone mute, touchpad,
  keyboard illumination, night light and menu/lock states. Use the power-saving
  icon for the Quick Settings battery saver tile instead of a low-battery icon.

- Accept ZIP and TAR archives or extracted resource directories; reject duplicate,
  oversized and unsafe selected members consistently. Record SHA-256 and size
  for each original input in the local manifest. Add synthetic regression tests.

- Add a local, repeatable importer for the supplied Windows resource libraries,
  Segoe Fluent Icons glyphs, original wallpapers and selected system sounds.
- Initial mapping covers 358 icon paths, 22 unique wallpaper images and 20
  sound events (verified on the reference archive). Map numeric battery,
  charging and energy-saver symbolic variants and live network names used
  by KDE, plus the common window and file action icons. Preserve source IDs and
  hashes; identical content is hard-linked and output collisions are rejected.
- Install imported icons over the existing windows-modern theme, replace the
  installed wallpaper package with the original Bloom light/dark pair, use
  the original lock-screen image separately, and provide the sound theme.
  Preserve the current system text fonts and retain open fallback assets.

### Quick Settings and taskbar refinements

- Give Quick Settings a two-row scrolling tile viewport and keep the sliders
  and footer stationary. Respect hardware availability and existing visibility
  settings; use the system UI font for tile labels.
- Correct the thumbnail popup height limit on short displays, avoid audio/count
  badge overlap in the fork and cap badge labels at 99+.
- Follow up on Start footer command scoping, grid drag cancellation and
  keyboard focus in the power menu.

### Start menu

- Replace the inherited two-column layout with top search, a responsive pinned
  grid, local Recent items and a scrollable All list. Keep Kicker favorites,
  search, sorting, drag and context actions.
- Move account, configured system shortcuts and a menu-only power button to
  the footer. Preserve system typography and existing user preferences.

### Notification center

- Combine shared KDE notification history and calendar in the clock flyout.
  Add notification cards, dismiss/clear, action buttons and manual DND.
- Route Win+N to the custom clock when present, releasing the old tray binding
  and backing up user settings. Keep the native notification applet for jobs
  and advanced interactions.
- Fit the clock flyout to the screen and scroll when space is limited.

### Icons

- Fill 11 missing application/arrow icon names with existing canonical SVGs in
  the single Windows Modern theme; remove the Start avatar's hard-coded Breeze
  file path in favor of the active icon theme.

### Tray and taskbar

- Move the overflow chevron before the tray icons; separate the compact
  icon-only overflow from Quick Settings. Network, audio and battery cells
  share the Quick Settings action while retaining live KDE status glyphs.
- Keep eligible unpinned applets reachable in overflow. Honor user-pinned
  and disabled states. Preserve right-click and wheel interactions.
- Use logical Qt font metrics for the panel clock and right-align its labels.

### Changed

- Preserve the user's existing KDE fonts when installing the full theme.
  Windows-style fonts remain an explicit optional installation. Lock/login
  text uses the session font rather than a hard-coded Segoe UI family.
- Document the fork's native Windows 11 visual fidelity target and acceptance
  criteria.

### Fixed

- Start menu: follow the Start button by default; use its actual screen position
  and clamp the flyout to the selected display, including floating and vertical
  panels. Existing explicit menu positions are preserved.
- New panels default to translucent opacity for consistent acrylic-style
  Start, Quick Settings and calendar flyouts. Start follows panel opacity in
  its default mode; explicit Start opacity overrides and solid mode remain.
- Align Start section headings and power button text with the normal UI font;
  reduce the calendar clock header from bold to semibold.

## [1.2.1] - 2026-11-23

### Fixed

- Debian and Ubuntu: the System Tray and taskbar plugins were installed
  to `/usr/lib64/qt6/plugins`, a folder Plasma does not read there, so
  they did not load (#26). The installer, uninstaller and health checks
  now ask Qt for its plugin folder (`/usr/lib/<arch>-linux-gnu/qt6/plugins`
  on Debian), with Plasma's own applet folder as the fallback.

## [1.2.0] - 2026-11-18

### Added

- Settings backups (#7): `./install.sh` saves the Plasma settings it may
  change before every run; `./uninstall.sh --list-backups` and
  `--restore [ID]` put them back, and `./uninstall.sh all` offers the
  settings from before Windows Modern. A restore saves the current state
  first, so it can be undone.
- README: which Plasma version each part needs (developed on 6.8; most
  parts run on 6.6 or 6.7), and `docs/UPSTREAM.md`: where each forked
  component comes from, what we changed, how to sync with upstream (#9).
- README screenshots retaken on Plasma 6.8 after a fresh install (dark
  and light), with new ones of the window previews and the calendar.
- Clock flyout: clicking the calendar's "Month Year" title zooms out to
  the months of the year, and again to a decade of years, as on
  Windows 11; picking one zooms back in. The arrows and the mouse wheel
  page by month, year or decade. Like Windows, the flyout always opens
  on today's month.
- Clock flyout: clicking a date picks it (an accent ring, as on Windows 11)
  and lists that day's events under the calendar: public holidays out of
  the box (your locale's region; the Holidays plugin is now on by
  default) and your KDE calendars if you enable them in the clock's
  settings, like Windows 10's agenda. Day cells are circles in every
  state (hover, press, picked, today), as are the month and year tiles,
  and picking a day with up to one event does not move the calendar.
- Optional Windows 11 taskbar Search box and Task View button
  (`org.kde.windowsmodern.search`, `org.kde.windowsmodern.taskview`).
  The search box opens the Start menu ready to type, like the Windows
  key (a "Search icon only" setting turns it into an icon, as on
  Windows); Task View opens KWin's Overview, like Win+Tab. They are installed with
  the other applets (`./install.sh taskbarbuttons`) but not put on the panel:
  add them from Add Widgets.
- `./install.sh transparency off|on`, Windows' "Transparency effects"
  switch: off makes Dolphin and other Kvantum apps solid and turns off
  KWin's blur, so Plasma's popups use the theme's solid variant (#10).
  The choice survives reinstalling the theme; "on" restores your previous
  blur setting.

### Changed

- New installs pin the file manager, the browser and Discover to the
  taskbar, like Windows 11's File Explorer, Edge and Store; the taskbar
  used to start with no pinned apps at all.
- Clock flyout: today's circle uses your accent colour (System Settings →
  Colors) with black or white text, whichever reads better (black on
  Windows' light blue in dark mode, as on Windows).
- Taskbar: a hovered app's icon is no longer lightened; the hover tile
  alone shows it, as on Windows 11.
- Taskbar window preview: the preview under the pointer lights up as a
  whole card, title included, as on Windows 11, instead of a box around
  the thumbnail only. Each card takes its window's shape (one height, up
  to 16:9 wide), so a narrow window's preview is no longer letterboxed in
  a wide card, and the highlight has the same padding on all four sides
  (the title and thumbnail used to touch its edges).
- Start button: hovering it (and while the Start menu is open) shows the
  taskbar's hover tile, and the logo is no longer lightened, as on
  Windows 11.

### Fixed

- `./install.sh systray` now also replaces the stock system tray in
  panels you already have (made while the build failed, or before Windows
  Modern); before, a later successful install changed nothing on screen.
  The tray keeps its place and settings (#4).
- Uninstall no longer reports the tray or taskbar as removed when a step
  that needs root failed (for example a cancelled password dialog).
- Start menu: the first pinned app no longer looks selected every time
  the menu opens; nothing is highlighted until you hover or use the arrow
  keys, as on Windows.
- Screen readers: the Start menu's "All apps" and "Back" are buttons
  (they were plain labels and could not be pressed), and calendar days
  can be picked through accessibility, like the month and year tiles.
- Panel layout: on a new install the Show desktop sliver sat between the
  tray and the clock instead of at the screen's right edge.
- The lock screen now uses the theme's wallpaper on a new install; it
  kept the distribution's default picture (only the desktop wallpaper was
  set). Uninstalling the themes resets it.
- Firefox window buttons (`app-decorations/firefox`): invisible with a
  light Firefox theme (white glyphs on a light title bar). Light themes get
  black glyphs; the close button keeps a white cross on red, and the
  restore icon no longer has a filled square (PR #3).
- Plasma style: with an adaptive or translucent panel (Plasma's default),
  the taskbar had no background of its own, only the wallpaper with a
  slight tint: both panel-background files had been invalid XML since
  June (a duplicated attribute on the shadow pieces). They load again; in
  light mode the translucent panel was hard-coded dark grey and now uses
  the light colour scheme. Opaque panels were not affected.
- Clock flyout: the large clock's seconds did not tick (it showed :00 and
  changed once a minute); a picked date was invisible in dark mode; event
  dots appeared only if events were already loaded, and their tooltip was
  empty.
- Taskbar: hovering an open but inactive app showed the blue "active"
  bar, so it looked active; hovering a pinned app showed no tile. Each
  state now has its own hover (tile plus its own bar), as on Windows 11,
  and the bars sit inside the tile with a small gap.
- Taskbar on a top, left or right panel: bars sat on the wrong edge or on
  the tile's border, and the active app had no bar on a top panel. Those
  frames are now generated from the bottom ones
  (`scripts/theme/tasks-frames.py`); `verify-all.sh` checks they match.
- Text in Plasma had blue and orange fringes, most visible on dim text
  such as a search field's "Search..." placeholder. Fedora's KDE edition
  turns on RGB sub-pixel smoothing, and Qt Quick's text renderer does its
  own regardless of fontconfig. `./install.sh fonts` now sets greyscale
  smoothing, as Windows 11's UI uses (fontconfig, and
  `QSG_DISTANCEFIELD_ANTIALIASING=gray` for the Plasma session), unless you
  chose a sub-pixel layout; `./uninstall.sh fonts` removes both.
- Plasma style, dark: list hover and selection, text fields, scrollbar
  handles, frames, separators and keyboard-focus highlights were invisible
  (#24). 191 shapes in 10 files painted the dark background's own colour
  (#2C2C2C) where the light variant follows the colour scheme; they follow
  it in dark too now.
- Plasma style: hovering a text field drew a light-blue line along its
  bottom and darkened it. Like Windows 11, hover now only tints the field
  slightly; the accent line belongs to the focused field.
- Lock screen: Enter sometimes did nothing, leaving the typed password in
  the field. The field was shown whenever something was typed, but Enter
  was only accepted after the mouse had woken the screen and while the
  pointer stayed on it, and for 3 s after a wrong password. Enter now works
  whenever the field is shown; typing wakes the screen like the mouse; a
  wrong password is cleared and PAM asked again at once; and the password
  check is retried every second, since kscreenlocker drops the first
  requests while its PAM worker starts ("Worker not ready yet"), as stock
  Plasma does. "Unlocking failed" is announced to screen readers.
- A panel created without the custom applets (e.g. a KDE Store install,
  which cannot ship the C++ tray) got no system tray at all: the layout's
  "fall back to the stock widget" checks never fired, because
  `addWidget()` returns an error placeholder instead of nothing. The
  fallback is now chosen up front from the installed widgets (PR #22).
- Taskbar: hovering an app took keyboard focus from the window you were
  typing in (#14). Its window preview was a plain Wayland window, so KWin
  activated it; it now tells KWin it is a tooltip that takes no focus, as
  Plasma's own tooltips do. Hovering also no longer moves QML focus unless
  you navigate the taskbar with the keyboard. Tested live
  (`tests/icontasks/e2e.py focus`: KWin's active window and typed text).
- Win+1…9 (open the Nth taskbar app), Ctrl+Win+PgUp/PgDn and
  Ctrl+Shift+Win+PgUp/PgDn did nothing on Plasma 6.8, which moved them
  from plasmashell into the task manager; the fork now registers them as
  stock 6.8 does. Needs `kglobalaccel` development files to build.
- Taskbar tooltips: Chrome/Chromium's logo covered every window preview
  once a tab had played audio (an idle media player with an empty title
  matched every window). From the lofcz fork.
- Start button: the logo follows the taskbar icons' size, so it no longer
  looks too small on panels between 36 and 47 px (PR #20 raised it).
- The applets' root install step gets its paths as arguments, so a
  quote, `$` or backtick in the checkout path cannot change what runs as
  root (from PR #1).
- `./install.sh` said "Done." when the System Tray or Icon Tasks build
  failed; it now lists the failed components and exits non-zero.
- Debian/Ubuntu build dependencies named packages that do not exist
  (`plasma-activities-dev`, `libdbusmenu-qt6-dev`); they are
  `libplasmaactivities-dev` and `libplasmaactivitiesstats-dev` (from the
  michael-ruta fork). The unused `systemtray/install.sh` is gone.
- Taskbar on a top or side panel: hovered, focused and attention task
  buttons had no background fill. `tasks.svg` named the xlink namespace
  `ns3`, which Qt's SVG renderer ignores (found through PR #23).
- Boot greeter: `./install.sh greeter` failed with a CMake error after a
  clone without `--recursive` or GitHub's "Download ZIP" (#15): the login
  manager submodule was empty. A git checkout now fetches it, anything else
  explains what to download; a stale submodule is reported. The release
  bundle now includes the login manager source, so it can build the
  greeter.
- After a restart, Alt+Tab could fall back to Breeze: an interrupted
  `tests/windowswitcher/e2e.py` left a test copy of the switcher selected,
  and its cleanup removed the copy. The test now restores the real
  switcher in that case, and `verify-all.sh --installed` warns when the
  installed Windows Modern switcher is not the one KWin uses.

## [1.1.2] - 2026-11-12

### Changed

- Tray flyout: the hidden tray icons above Quick Settings are drawn as
  plain launchers (centered icon over its name, a background only on
  hover), so they no longer look like the Quick Settings toggles below.

### Fixed

- No splash screen at login, as the global themes intend: they set the
  splash theme to "none", which Plasma does not know; it is "None".
- Tray flyout: two-line names (e.g. "Display Configuration") spilled
  below the card's hover background; icon size and margins now fit two
  lines. The pages' Back button has an accessible name.
- Log out (Start menu, or anywhere else) did nothing: the lock screen's
  shell overlay symlinked Plasma's logout screen, which Plasma now refuses
  to load from outside the package. The overlay copies it instead, and
  `verify-all.sh --installed` checks the copy is current.
- Login screen: showed Breeze icons, as the greeter's user cannot read the
  icon pack in your home. `install-greeter-live.sh` now installs the pack
  to `/usr/share/icons` and sets it as the greeter's icon theme; the
  greeter uninstall removes both. It also gives the greeter the Windows
  Modern Dark colors (it had Plasma's light default, so the wallpaper
  showed its light picture under a dark desktop); uninstall puts the
  greeter's original settings back. Neither script stops `plasmalogin` any
  more (that would end the running session).

## [1.1.1] - 2026-11-12

### Added

- KDE Store: the color schemes, icons, window decorations and Plasma styles
  (dark and light), the clock, Show desktop and Alt+Tab are now their own
  store items, and the global themes depend on them. Installing a global
  theme from Discover now also installs its look, the Win10OS cursors and
  the Start menu, clock, Show desktop and Alt+Tab widgets (the tray,
  taskbar and the rest still come from `./install.sh`).
- `scripts/store/`: publishing to the KDE Store from the command line
  (`store-publish.py`, driving a Firefox with its own profile, since the
  store has no upload API), clean listing screenshots taken on a temporary
  virtual desktop (`capture.py`), and the global themes' dependencies
  written from the product list (`set-dependencies.py`).

### Fixed

- The color schemes zip unpacked into `color-schemes/color-schemes/` when
  installed from the store, where Plasma does not look: its `.colors` files
  now sit at the top of the zip.

## [1.1.0] - 2026-11-11

### Added

- Quick Settings footer, as in Windows 11: battery level on the left
  (laptops; opens the battery page) and a Settings gear on the right
  (right-click for display, sound, network, power and notification
  settings).
- Prebuilt System Tray and Icon Tasks plugins: CI builds them for each
  supported Fedora and attaches them to releases, keyed by distro, Plasma
  and Qt version. Installing from a release checkout downloads the
  matching build (checksum-verified) and skips the compiler and -devel
  packages; any other checkout, or a system without a match, builds from
  source as before.
- Snap Layouts, as in Windows 11: drag a window towards the top edge, and
  a bar with six layouts (50/50, 66/33, thirds, half + quarters, four
  quarters, 25/50/25) appears at the top centre; hovering a cell outlines
  the target area, dropping snaps the window there (KWin script, with
  `./install.sh shortcuts`).
- `./install.sh shortcuts`: Windows keyboard shortcuts. Win+Up/Down
  maximize, restore, minimize and snap to quarters as on Windows 11 (new
  KWin script), Win+Tab opens Task View, Win+R Run, Win+A Quick Settings,
  Win+N notifications, Win+M / Win+Home minimize all / others, Win+PrtSc
  saves a full screenshot silently, Alt+PrtSc captures the active window.
  Previous keys are backed up; `./uninstall.sh shortcuts` restores them.
- `./install.sh apps`: Haruna (default video player), KWrite, Mission
  Center (Flathub, per user) on Ctrl+Shift+Esc, and Snipping Tool
  behaviour for Spectacle (capture on release, copy, save), and an Up
  button in Dolphin's toolbar as in File Explorer.
- `./install.sh fonts`: Cascadia Mono (Windows 11's monospace font) as the
  fixed-width font, and, when Segoe UI is not installed, Microsoft's open
  Selawik standing in for it (downloaded, checksum-pinned, aliased so
  "Segoe UI" resolves to it). Fonts change only if still distro defaults.
- `./install.sh deps`: Kvantum, Flatpak and the C++ applets' build
  dependencies, so "Everything" works on a fresh machine.
- "Everything" now also installs dependencies, shortcuts and apps.
- `tests/shortcuts/e2e.py` presses every new shortcut in the live session
  and checks the result.
- **Windows 11-style Alt+Tab switcher** (`./install.sh alttab`, included in
  `all`): aspect-correct previews in centered rows, icon + title headers,
  close on hover, rounded focus ring, keyboard navigation across rows. Both
  global themes select it. Comes with a mock-KWin preview tool, QML tests,
  and an end-to-end test that drives a real Alt+Tab in the running KWin.
- `PRODUCT.md`: the product brief — vision, scope, and what is deliberately
  left out.
- CI (GitHub Actions): the repository health check plus a build-and-link check
  of both C++ applets against Fedora's Plasma.
- `scripts/ci-build.sh`, `CONTRIBUTING.md`, `.editorconfig`, `.shellcheckrc`.

### Changed

- Tray flyout: Bluetooth and Brightness & Color (already in Quick
  Settings below), Weather, Vaults and the X11 video bridge no longer sit
  behind the chevron. Pin one, set it to "Always hidden", or let it need
  attention and it shows again. The card grid fits without scrolling.
- Taskbar: no speaker badge on the icons of apps playing audio, as on
  Windows (mute from the tray's volume page). The option stays in the
  taskbar's settings.
- Cursor: the Win10OS cursors (GPL-3.0, Windows 10 style), fetched from
  upstream at a pinned commit by `./install.sh themes` / `lookfeel` when
  not already installed, replace Breeze Light in both global themes.
- "Everything" turns off KWin's Show Desktop effect that slides all windows
  to the screen corners (Windows doesn't), unless you set it yourself.
- Volume, brightness and keyboard-layout pop-ups appear bottom-centre just
  above the taskbar, as on Windows 11, instead of two-thirds down the
  screen (KWin script, installed with `./install.sh shortcuts`).
- Tooltips wait half a second before appearing, like Windows, instead of
  flashing up under every button the pointer crosses.
- Dark theme: selected items in file lists and sidebars (Dolphin, System
  Settings, file dialogs) are a light accent tint with white text, as in
  Windows 11 Explorer, instead of a solid light-blue bar whose white text
  was hard to read.
- Keyboard layouts are labelled by language in the tray, as on Windows
  (`ENG`, `CES`, `DEU` instead of `us`, `cz`, `de`), from XKB's own data so
  every language works. `./install.sh layout` sets it; your own labels are
  kept, and two layouts of one language keep their codes.
  The label uses the clock's text size (the stock widget scaled it to
  the icon cell, larger than the clock on a 48 px panel).
- System tray: the last icons before the clock are always input language,
  network, volume, battery, in that order, as on Windows 11. Other icons
  (apps, Bluetooth, clipboard...) come before them.
- System tray: like Windows 11, only input language, network, volume,
  battery, notifications and the camera-in-use indicator show by default.
  Everything else (apps, Bluetooth, clipboard, brightness...) waits behind
  the chevron until it needs attention or you pin it ("Always shown" in
  the tray settings).
- The Icon Tasks applet is no longer packaged for the KDE Store; like the
  System Tray it is a compiled plugin and ships only in the GitHub bundle.
- The global themes no longer reference Plasma 5's Breeze window and desktop
  switchers, which Plasma 6 no longer ships.
- `verify-all.sh` checks both theme variants, all five applets, layout drift,
  metadata, and shell scripts. `--installed` adds checks of the installed C++
  plugins; Icon Tasks has a new `verify.sh`.
- The System Tray `metadata.json` now declares its `KPlugin.Id`.

### Fixed

- Start menu search: results appearing under a resting pointer took the
  selection, so Enter ran whatever was under the mouse instead of the best
  match. The pointer now selects a result only once it actually moves.
  Result rows are also exposed to screen readers (name, selected).
- Quick Settings flyout: scrolling over the overflow cards (e.g. with a
  touchpad over "Brightness & Color") changed the brightness or volume.
  The wheel now scrolls the card grid and never reaches the applet's icon.
- "Recent Files" in Dolphin's Places panel drew a dark-gray line-art
  document that clashed with the yellow folder icons around it. The pack's
  `document-open-recent` is now a full-colour white document with a blue
  clock badge, in the style of the rest of the Places icons (the actions
  and places variants are identical, since Qt resolves the name to
  `actions/` first).
- Dolphin's status bar: the capacity bar and the "228 GiB free" text were
  squashed to a sliver with our Kvantum style (upstream bug 483172 —
  negative margins in `StatusBarSpaceInfo`). Fedora's dolphin is now
  locally rebuilt with the upstream fix (`scripts/fix-dolphin-statusbar.sh`,
  release tag `.wm1`); the next `dnf upgrade` replaces it — from Dolphin
  26.12 the stock package contains the fix, so nothing needs re-running.
- Installer conditions written as `cmd | grep -q` could come out false
  under `pipefail` when `cmd` printed a lot (`commit-icons.sh` skipped
  re-enabling tracking of the icon pack); all now read the output first.
- System tray: network, volume and (on laptops) battery always show, as on
  Windows. The battery disappeared behind the chevron when the laptop was
  full and on the charger, because Plasma marks it passive then.
- Login screen: builds and runs again on Plasma 6.8. Plasma Login Manager
  is pinned to 6.8.2 (the 6.6 build needed a libPlasmaQuick that Plasma
  6.8 no longer ships), the patch is rebased, and the theme follows 6.8's
  greeter interface (event filter, session selection, security-key
  messages). `--test` now loads your own copy of the theme.
- Login screen: live network and battery icons (the network icon was
  fixed), the date in your language, and the inert accessibility button
  is now an on-screen keyboard toggle, shown when one is available.
- Greeter uninstall could put back an outdated login greeter: it restored
  the `.orig` backup even when a package update had already replaced the
  patched greeter, and even when the backup needed libraries a Plasma
  update had removed (it would no longer start). It now does nothing when
  the greeter is the distro's own file, never restores a backup that
  doesn't link, and the installer refreshes the backup after updates.
- Lock screen: the network, volume and battery icons show the real state
  (signal strength, mute and level, charge and charging) instead of fixed
  "full" icons; the battery icon hides on machines without one.
- Lock screen: the date follows your language ("středa 11. listopadu"),
  the time is centred over it, and media controls appear again (a wrong
  config name had switched them off for good).
- Dark theme: the mouse cursor theme it set did not exist, so the cursor
  fell back (for GTK apps too). Both themes now use an installed cursor
  theme (now Win10OS, see Changed).
- `./install.sh themes` run on its own now applies the dark Plasma theme;
  it asked for a theme named `Windows-modern`, which does not exist.
- Clock: time and date now share the normal UI font size, as on Windows
  (the time used to grow with the panel and the date was shrunk to 65 %),
  and the date shows the full year (`11.11.2026`). The clock cell now
  sizes to its text; a longer date used to overflow a square cell. The
  "Compact padding" setting is gone with the old sizing.
- Switches: no more white (dark theme) or black (light theme) rim on the
  left of a switched-on switch. The off state now looks like Windows 11
  (grey outline, grey knob). Both SVGs are generated by
  `scripts/gen-switch-svg.py` and checked by `tests/theme/check-switch.py`.
- Show Desktop: the second click restores the windows again. It now uses
  KWin's show-desktop mode (the same state as Win+D) instead of minimizing
  windows one by one, which lost track of them mid-way.
- Start menu: each keystroke in the search field ran the search twice (a
  duplicate change signal) and logged a warning.
- Start menu: the Start button is exposed to screen readers and other
  accessibility tools (it was missing from the accessibility tree).
- Installing a C++ applet no longer stops Plasma Shell before asking for
  the password; cancelling the prompt used to leave the desktop without a
  shell. The plugin is installed as a new file, so the running shell is not
  disturbed, and any later failure restarts the shell.
- The C++ applets no longer set `KPlugin.Id` in their embedded metadata
  (KF6 derives it from the file name and warns about an explicit one).
- Icon Tasks: the task right-click handler matches upstream Plasma 6.8
  (no exclusive-grab gesture policy).
- Installing several applets at once (`./install.sh applets` or `all`) no
  longer leaves the desktop without Plasma Shell: the C++ applet installers
  stop it, and the final restart now also starts a stopped shell.
- System tray: the Quick Settings flyout fits its content instead of
  showing an empty band above the toggles, and the hidden-icon tiles line
  up with the toggles.
- Digital Clock: the flyout's date line uses the locale's own long date
  without the year ("středa 11. listopadu", not "středa, listopadu 11").
- Icon Tasks: the window-preview tooltip no longer logs layout warnings
  every time it opens.
- KWin settings applied by the installer (Alt+Tab switcher, border size,
  per-monitor Alt+Tab) now take effect immediately. The reload request was
  sent as a D-Bus signal, which KWin ignores, so they only applied after
  logging out.
- **Icon Tasks builds and loads on Plasma 6.8.** libplasma 6.8 dropped
  `PlasmaQuick::SharedQmlEngine` and bumped its sonames; the tooltip now loads
  its default content with a plain `QQmlComponent`.
- Uninstalling Icon Tasks no longer deletes the distro's stock icons-only task
  manager. Installing moves it aside to `/var/lib/windows-modern/backup/` and
  uninstalling restores it.
- System Tray: no crash when a plugin is unregistered twice, no duplicate or
  leaked tray entries when a status-notifier service registers twice, no
  dangling pointer when a tray icon disappears while its menu is being fetched,
  and themed tray icons no longer revert after an icon-theme-path change.
- Icon Tasks: no crash while the tooltip is still loading, and hovering no
  longer creates a tooltip window just to hide it.
- Digital Clock: time-zone offsets such as −7:30 now read "7:30 earlier"
  instead of "8:-30 earlier".
- Start Menu: right-clicking a search result always resolves the right app,
  even after the app list is re-sorted or apps are installed/removed, and app
  actions are triggered on the correct row.
- The session lock screen is built in a staging directory and swapped in
  atomically; a failed install can no longer leave a broken shell overlay.
  Old overlay backups are capped at two.
- The release bundle now contains `scripts/` (installing from a downloaded
  release previously failed immediately) and is built from the committed tree,
  so local build output is never shipped.
- Stale artifacts in `dist/` are no longer uploaded with a new release, and
  `package.sh` fails if component versions disagree with the release version.
- The panel layout scripts no longer contain a dead "fallback" that re-added
  the same task-manager ID.
- `verify-all.sh` now exits non-zero when a check fails (it previously always
  passed, so the release gate never fired).

### Security

- The boot greeter is no longer built as root: `install-greeter-live.sh`
  builds as the invoking user and only copies the finished binary into `/usr`.
  It refuses to overwrite a greeter binary that carries file capabilities and
  keeps its SELinux label.
- `install-greeter.sh` stashes local changes in the PLM submodule instead of
  running `git reset --hard`.
- `update-plm.sh` only accepts upstream release branches and tags, refuses to
  run on a dirty submodule, prints the resolved commit, and always reverts its
  patches.
- The System Tray installer no longer runs root scripts from `/tmp`.

## [1.0.0]

Initial release.
