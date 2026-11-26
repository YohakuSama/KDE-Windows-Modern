# Experimental application window layouts

## Konsole: Windows Terminal-style integrated tab strip

The optional plugin in `app-decorations/konsole` is source-reviewed against
[Konsole release/26.08](https://github.com/KDE/konsole/tree/release/26.08/src).
It uses Konsole's actual IKonsolePlugin and native QTabWidget, including its
original session, profile menu, tab drag, detach and close behavior. The
window caption buttons are sourced from the existing private Windows
glyph import (E921, E922, E923, E8BB). If any glyph or the native tab
corner is unavailable, do not remove the native decoration.

This is an opt-in prototype, not part of the normal theme installation,
and not proof of Windows Terminal parity. It adds minimize, maximize/restore,
close and a dedicated drag region to the native right corner. The stock
new-tab/profile button remains in its upstream left corner for now.
Window moves and eight edge/corner resize zones use QWindow's native
system move/resize requests; unsupported requests turn off the prototype.
The normal Konsole close confirmation remains in charge. The standard
Windows Modern Campbell stylesheet remains dark; other palettes inherit
the native tab colors. Native KWin decoration shadows, snap flyout on
maximize hover and titlebar system menu are not reproduced by this prototype.

It only activates with a visible top tab bar, hidden menu/toolbars, no
attached side docks, a supported X11/Wayland backend, and Konsole's own
frameless preference disabled. Changing these settings restores the
native titlebar. Fullscreen uses the native fullscreen mode.

### Manual NixOS trial

Use the same **absolute nixpkgs path** as the current desktop/test runtime.
Konsole's plugin loader checks the release major/minor and its private
ABI has no public SDK. The optional expression uses the exact nixpkgs
Konsole derivation, adds only the plugin subdirectory, and produces an
isolated Konsole package with its own matching libraries. It does not
replace the system package or modify Home Manager, configuration.nix,
the default launcher, or the Nix store directly. It is not a plugin
binary for an arbitrary installed Konsole. Build and install are manual
maintainer actions.

From the theme checkout, after the standard theme and native glyphs have
been installed, inspect `konsole --version` and supply that exact version:

```sh
nix-build nix/konsole-chrome.nix \
  --argstr nixpkgsPath /absolute/path/to/the/current/nixpkgs \
  --argstr konsoleVersion 26.08.3 \
  --out-link ./result-konsole-chrome
WM_KONSOLE_CHROME=1 ./result-konsole-chrome/bin/konsole \
  --separate --hide-menubar --hide-toolbars --show-tabbar
```

Replace the example version with the actual version. The expression
rejects a different package version or an unaudited release series.
For a source build on another distribution, copy the plugin directory
into the matching Konsole checkout at `src/plugins/WindowsModernChrome`,
append `add_subdirectory(WindowsModernChrome)` to
`src/plugins/CMakeLists.txt`, and build that Konsole in an isolated
prefix with the upstream dependencies plus Qt SVG. Do not install
a module compiled against a different package ABI into stock Konsole.

The plugin is disabled by default. The environment variable enables it
for this process only. Alternatively, enable/disable the checkable
entry in the native Plugins menu (show the menu bar to access it and
hide it to apply the integrated layout). Exit the isolated process and
launch ordinary Konsole to recover. The plugin writes no user settings
and does not change terminal profiles; ordinary Konsole itself still
uses the user's existing configuration and session state. Do not launch
it with irreplaceable terminal sessions during initial acceptance.

Manual acceptance (not performed by the developer): verify actual plugin
loading, single and many tabs, profile dropdown and split views, tab drag
and detach, multiple windows, normal close confirmation, minimize,
maximize/restore, fullscreen, titlebar double-click, all resize edges
and corners, compositor snapping, 100/125/150/200% scaling, moving
between differently scaled screens, light/dark palettes, keyboard
access and recovery when glyphs or a supported tab layout are absent.

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
accessibility, file operations and confirmation dialogs. No Dolphin
source patch is included in this Konsole prototype.
