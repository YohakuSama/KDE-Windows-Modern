# Optional application window layouts

## Konsole: integrated Windows Terminal-style title bar

The optional plugin source in `platform/qt/konsole` is source-reviewed against
[Konsole release/26.08](https://github.com/KDE/konsole/tree/release/26.08/src).
The source map materializes its build input at `app-decorations/konsole`.
Its layout follows the public Windows Terminal
[TabRowControl](https://github.com/microsoft/terminal/blob/main/src/cascadia/TerminalApp/TabRowControl.xaml)
and [TitlebarControl](https://github.com/microsoft/terminal/blob/main/src/cascadia/TerminalApp/TitlebarControl.xaml).
The dimensions are provisional logical pixels; the source review does not
establish measured Windows 11 26H2 visual parity.

The plugin uses Konsole's actual IKonsolePlugin and native QTabWidget:
- Minimize, maximize/restore and close share the tab row. The plugin uses
  locally imported Windows E921, E922, E923 and E8BB glyphs.
- Separate new-tab and profile/container dropdown buttons use the original
  Windows E710 and E70D glyphs. They proxy Konsole's existing button and
  live menu, rather than duplicating the session or profile logic. They
  follow the last visible tab when space permits, and use a reserved
  corner area when the tab strip scrolls. Native buttons and styles are
  restored when the feature is disabled.
- Empty title areas use compositor-native moves, double-click maximize,
  an application window menu on right-click and eight resize zones.
  Clicks and releases belonging to the title area are not sent to
  Konsole's detachable tab bar. Actual tab drag, detach, close, keyboard
  navigation and session confirmation remain native.
- Caption Snap requests are canceled on hover exit, press, visibility,
  focus or window-state changes; the bridge rechecks the live button state
  before returning its one-shot anchor.
- The Windows Modern tab stylesheet adapts to the system light/dark
  scheme; the selected Campbell tab still joins the dark terminal.
  Native tab-close and overflow scroll buttons use the original E8BB,
  E76B and E76C imported glyphs while this owned stylesheet is active.
  The native button actions, arrow directions, enabled states and geometry
  are retained. Restoring the stylesheet removes the paint override.
  Arbitrary custom styles are not replaced. Logical-pixel dimensions
  and device-scale glyph rendering follow Qt.
- Shadows are submitted to KWindowShadow, outside the actual window
  geometry, and updated for focus, scale and native surface changes.
  They are removed on maximize, fullscreen or deactivation. A missing
  compositor shadow protocol does not block window use.
- A hover over the maximize button requests the existing KWin Snap
  Layouts script to show an anchored interactive picker, using the same
  layout definitions as drag-to-top. KWin checks the active window,
  matching client/frame geometry, pointer position, output work area,
  and size limits before placing that window. The short-lived D-Bus
  request can only be consumed by the running KWin service. No terminal
  titles, commands or session contents are exchanged.
- There is no default global shortcut for this request. A missing,
  disabled or older snap script leaves maximize/restore usable. Both the
  drag-to-top Snap Bar and the caption-button Snap Layouts picker now
  follow initial placement with KWin-backed Snap Assist (`SnapAssistPicker.qml`):
  when open zones remain in the chosen layout (skipping zones already
  occupied by snapped normal windows on the current desktop and output)
  and eligible resizeable normal windows exist on the current desktop,
  a thumbnail/icon/title picker is centered inside the next open zone to
  fill remaining zones sequentially without stealing Wayland keyboard
  focus from the newly snapped window. Persistent taskbar snap-group sets
  and coupled multi-window divider resizing across arbitrary 3/4-zone
  layouts remain a KWin compositor boundary (KWin custom tile trees are
  desktop-global rather than per-window-pair Snap Groups).

This remains an opt-in pre-acceptance implementation. It activates only
with a visible top tab bar and enabled native new-tab button, hidden
menu/toolbars, no attached side docks, X11 or Wayland, and Konsole's own
frameless preference disabled. Missing imported glyphs, unavailable
window-move/resize requests or a layout that cannot fit the controls
disable the custom chrome. The integrated controls are hidden in
fullscreen and the original tab controls are restored there.

Window rounding is deliberately left to the compositor. The plugin does
not set a hard window mask or modify terminal transparency to imitate
Windows corners; that would risk clipping at fractional scales. Actual
outer corner rounding is still unresolved for frameless Konsole.

### Manual NixOS trial

For a complete desktop test, use the reversible NixOS installer with the
explicit terminal option:

```sh
bash install.sh menu --with-konsole
```

Choose 1 for a first installation or 2 for an existing test installation.
The installer builds the version-matched isolated Konsole, verifies the
plugin file and required imported glyphs before switching the desktop, and
adds the separate Windows Modern Terminal launcher. It keeps the stock
Konsole launcher and system package untouched. Subsequent upgrades retain
this option; uninstall and failed upgrades restore the previous launcher
and desktop runtime using the existing backup transaction. No normal
installation without this option starts a new Konsole trial.

The updated Snap Layouts script is part of the normal theme; KWin
caches QML, so log out and back in after upgrading it before testing hover
snapping. If the script is disabled, enable Windows Modern: Snap Layouts
in System Settings > Window Management > KWin Scripts.

After installation, launch Windows Modern Terminal from the application
menu. For an independent trial instead of the integrated test installer,
use the following commands from the theme checkout as the desktop user:

```sh
./scripts/konsole-chrome.sh build
./scripts/konsole-chrome.sh run
```

The first command is the maintainer's explicit build action. It resolves
the running NixOS nixpkgs revision, checks the installed Konsole version
and builds an isolated Konsole package with its matching private
libraries. The source-reviewed series is 26.08.x; another version is
rejected. If the exact nixpkgs revision cannot be identified, supply
the matching absolute nixpkgs directory:

```sh
WM_KONSOLE_NIXPKGS=/absolute/path/to/nixpkgs ./scripts/konsole-chrome.sh build
```

The run action checks the recorded source digest, installed Konsole
version and Nix store output before starting a separate process. After
a plugin source update or a system upgrade, run the build action again.
Additional Konsole arguments can follow `run`.

The plugin is disabled by default in an ordinary invocation of the
isolated binary. The run action sets `WM_KONSOLE_CHROME=1` and requests
the native top-level tab UI. A checkable entry in the native Plugins menu
and in the plugin's right-click title menu allows disabling it for a
window. The right-click menu also exposes the original menu-bar action.

To stop using the plugin, close the isolated Konsole process and launch
ordinary Konsole. For the integrated test installer, use option 3 to
restore the original desktop and remove its test launcher. For the
independent manual trial only, remove the dedicated build link with:

```sh
./scripts/konsole-chrome.sh remove
```

The trial uses a private state directory and Nix GC root, without
replacing the system package, default launcher, Home Manager,
configuration.nix or Nix store contents. Removal unlinks the managed
build and manifest only. Nix garbage collection can reclaim an unused
package later. The plugin writes no preferences and does not change
terminal profiles; the isolated Konsole application itself still shares
the usual Konsole configuration and session state.

For another distribution, build inside a matching Konsole source tree
by copying `platform/qt/konsole` into `src/plugins/WindowsModernChrome`
and appending `add_subdirectory(WindowsModernChrome)` to
`src/plugins/CMakeLists.txt`. Use the upstream dependencies plus Qt SVG,
Qt DBus and KWindowSystem. Do not mix an arbitrary compiled plugin with
stock Konsole's private ABI.

### Manual desktop acceptance

No build, automatic tests or live desktop validation have been performed
by the developer. Start with disposable terminal sessions. Verify:
- Loading the plugin and returning to the stock layout.
- One tab, many tabs, very narrow windows, profile/container dropdown,
  split views, tab close, drag, detach, multiple windows and close prompts.
- Dragging empty space, right-click menu, double-click, minimize,
  maximize/restore, fullscreen, all resize edges and corners.
- Light/dark changes, 100/125/150/200% scales, different-scale monitors,
  active/inactive shadows and absence of layout or glyph clipping.
- Hover snap placement, disabled cells, output changes, focus changes,
  missing/disabled KWin script and ordinary drag-to-top snapping.
- Missing native glyphs, visible menu/toolbars, dock widgets and native
  frameless settings. The plugin must not make a window inaccessible.

Keep the terminal trial opt-in until acceptance. Do not overwrite or
replace the system Konsole.

## Dolphin: Explorer layout boundaries

The theme already uses reversible `config/kxmlgui5/dolphin/dolphinui.rc`
and `scripts/app-appearance.py` settings for the separate navigation and
command toolbars, tabs and full-width status bar. Kvantum and the Windows
icon map supply the visuals. Avoid replacing KIO's file operation backend
or duplicating its actions.

Dolphin's `KAbstractFileItemActionPlugin` interface adds file context
actions; it does not expose a supported general main-window layout hook.
In [Dolphin 26.08](https://github.com/KDE/dolphin/tree/release/26.08/src),
`DolphinMainWindow` owns a central `DolphinTabWidget`, toolbars and
dock panels; `DolphinViewContainer` owns its URL navigator and search
bar. The Windows layout needs tabs above both toolbars, a persistent
search box beside the address bar, Explorer-style navigation grouping,
and a compact primary context menu with an extended submenu.

Recommended next phase: small, version-matched presentation patches in
those existing classes and `DolphinContextMenu`, using existing QAction
objects and search/navigation models. Keep ordinary Dolphin available;
build an isolated NixOS derivation first, as with Konsole. Do not use a
file-action plugin as an undocumented global widget-injection mechanism.
Preserve multi-tab and split-view navigation, file selection, shortcuts,
accessibility, file operations and confirmation dialogs.

The first isolated Dolphin derivation now backports the upstream 26.08
status-bar spacing correction. It uses QStyle's frame metric instead of
negative layout margins, preserving the capacity control and native disk
usage menu. The same patch is reused by the explicit Fedora repair script,
which no longer treats diff's normal "files differ" exit status as a failure.

The isolated desktop build also adds a native new-tab button in the
existing QTabWidget corner, only for the Windows Modern command-toolbar
layout. It uses Dolphin's existing New Tab QAction (including the
current-location behavior and Ctrl+T shortcut); the tab count and
AlwaysShowTabBar preference control visibility. The imported tab-new icon
is resolved through the active theme. The ordinary tab model, closing,
dragging, detaching and split-view behavior are unchanged. The hamburger
menu is not migrated a second time when the command toolbar already
contains it. The phone UI and custom layouts without the Windows Modern
command toolbar retain their normal behavior.

The Nix expression is `nix/dolphin-chrome.nix`; it requires the installed
26.08.x version and matching absolute nixpkgs source path, following the
version gate used for Konsole. It is opt-in via `--with-dolphin` or `--full`
(`bash install.sh auto --full`), which builds the isolated package, verifies
required imported glyphs (`tab-new-symbolic`, `wm-show-more-options-symbolic`,
`wm-context-new-symbolic`), and installs a separate `Windows Modern Explorer`
launcher (`windows-modern-dolphin`) while keeping stock `dolphin` untouched:

- **Implemented Dolphin 26.08.x presentation patches (`E04`, opt-in isolated `nix/dolphin-chrome.nix`)**:
  1. `explorer-chrome.patch` (`DolphinMainWindow`, `DolphinTabWidget`, `DolphinNavigatorsWidgetAction`): places a non-movable `wmTabStripToolBar` (`DolphinTabBar` + trailing `+` `wmExplorerNewTabButton` immediately after the last tab) above `mainToolBar` and `wmCommandToolBar` when `wmCommandToolBar` is active, removes the leading Places-indent gap on `DolphinNavigatorsWidgetAction` for full-width Explorer breadcrumb alignment, and adds a persistent right-aligned `wmExplorerSearchField` on `mainToolBar` ("Search <Folder>") driving Dolphin's native `Search::DolphinQuery` (`Ctrl+F` and `Search::Bar` filter chips remain available). Phone UI and custom KXMLGUI layouts without `wmCommandToolBar` retain stock behavior.
  2. `PlacesPanel`: preserves native `KFilePlacesModel` groups (`Places` / Quick Access, `Recent`, `Remote` / Network, `Devices`) together with user bookmarks and Solid removable volumes.
  3. `compact-contextmenu.patch` (`DolphinContextMenu`): compacts item and viewport background menus to Windows 11's primary actions (`Open` / `Open With`, `Cut`, `Copy`, `Paste`, `Rename`, `Move to Trash` / `Delete` with live `Shift` state, `View`, `Sort`, `Refresh`, `Create New` with `wm-context-new-symbolic`, `Add to Places`, `Open Terminal`, `Properties`) and moves all remaining KIO/service/VCS/plugin actions into a trailing `Show more options` (`wm-show-more-options-symbolic` / `U+E8A7`) submenu; holding `Shift` while right-clicking opens the full classic menu directly.

## Generic KDE/Qt application and dialog consistency boundary (`E05`)

| Consumer Category | Covered Surfaces & Mechanism | Explicit Scope Boundary |
| --- | --- | --- |
| Shared `QWidget` & KIO dialogs | `Windows-modern` / `Windows-modernDark` Kvantum (`live-reload-1.1.9.patch` on NixOS) + `WindowsModern{Light,Dark}.colors` + `windows-modern` icon theme cover `QMainWindow`, `QDialog`, `KFileWidget` open/save dialogs, `KIO::RenameDialog` / `SkipDialog`, `KPropertiesDialog`, `QMenu` (`8px` corner slice, `98%` opacity, `1px` stroke), `QPushButton`/`QLineEdit`/`QComboBox`/`QSpinBox` (`4px` radius + accent focus), `QCheckBox`/`QRadioButton`/`QSlider`/`QProgressBar`, `QTabWidget`, `QScrollBar`, `QTreeView`/`QListView` and `QStatusBar` | Does not inject custom C++ widget subclasses into arbitrary third-party Qt applications |
| File Manager (`Dolphin`) | Reversible `dolphinui.rc` (`Navigation` + `Commands` toolbars, `20px` icons) and `app-appearance.py` settings (`AlwaysShowTabBar`, breadcrumb `EditableUrl=false`, `FullWidth` status bar); optional isolated `nix/dolphin-chrome.nix` (`statusbar-margins.patch`, `tab-controls.patch`) | Stock system Dolphin binary is never overwritten on NixOS; full Explorer tab-above-toolbar & compact file context menu remain opt-in (`E04`) |
| Terminal (`Konsole`) | Reversible `WindowsModern.profile` (Campbell palette, Cascadia Mono 12pt, 8px margin, beam cursor), `WindowsModern-tabs.css` (`8px` top tab & menu radius), hidden toolbars/menubar `konsoleui.rc`/`sessionui.rc`, and optional 26.08.x `WindowsModernChrome` integrated titlebar + Snap Layouts bridge (`E01`/`E02`) | Activated only via explicit `--with-konsole` / `konsole-chrome.sh`; terminal shell/PTY session behavior is untouched |
| Everyday Qt/KDE utilities (`KWrite`/`Kate`, `Haruna`, `Spectacle`) | `KWrite`/`Kate` inherit Kvantum + `.colors` + `windows-modern` icons; `Haruna` inherits `.colors` + icons + MPRIS (`MediaCard`/`MediaControls`); `Spectacle` is configured via `spectaclerc` for Snipping Tool release-capture + clipboard + save (`Win+Shift+S`, `Alt+PrtSc`, `Win+PrtSc`) | Application-internal QML/dock layouts remain upstream KDE |
| `System Settings`, `System Monitor` & `Discover` | Navigation/category/KCM icons (`86/98` declared KCM roles from 26H2 `SegoeIcons.ttf`) and 5 Light/Dark Microsoft Store icon aliases (`discover` family) + `WindowsModern{Light,Dark}.colors` | Internal Kirigami page structures are intentionally kept native KDE (not rebuilt into Windows Settings or Microsoft Store clones) |
| GTK4 / Libadwaita & Browser (`Mission Center`, `Network Displays`, `Firefox`) | Integrated via desktop launchers, global shortcuts (`Ctrl+Shift+Esc`, conditional `Win+K`), and `Windows-Modern-26H2` XCursor; `modules/browser/firefox/userChrome.css` provides an opt-in manual profile stylesheet for `46×30px` Windows 11 CSD caption buttons | Never auto-modifies GTK/Libadwaita themes or user Firefox profiles during installation |
