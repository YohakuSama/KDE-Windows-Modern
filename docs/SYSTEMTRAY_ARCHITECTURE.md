# System Tray — Architecture & History

## Overview

The Windows Modern system tray (`org.kde.windowsmodern.systemtray`) is a C++ `Plasma::Containment` fork of the upstream plasma-workspace system tray. It replaces the default `org.kde.plasma.systemtray` with identical Plasma containment behavior — child applets (network, volume, battery, clipboard, etc.) are managed by the containment and appear/disappear automatically.

---

## Architecture

```
┌─────────────────────────────────────────────┐
│  Panel (org.kde.panel)                      │
│  ┌───────────────────────────────────────┐  │
│  │  System Tray (CustomEmbedded)         │  │
│  │  ├─ PlasmoidItem (network)            │  │
│  │  ├─ PlasmoidItem (volume)             │  │
│  │  ├─ PlasmoidItem (battery)            │  │
│  │  ├─ PlasmoidItem (notifications)      │  │
│  │  ├─ StatusNotifierItem (Discord)      │  │
│  │  ├─ StatusNotifierItem (Steam)        │  │
│  │  └─ ...                               │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

### Key Components

| File | Purpose |
|------|---------|
| `systemtray.cpp/.h` | C++ `Plasma::Containment` — manages child applets, DBus model, XDG activation |
| `shellappearancemonitor.cpp/.h` | Corona-owned wallpaper bridge, file/config observers and debounced appearance helper |
| `shellshortcutrouter.cpp/.h` | Corona-owned Win+R/V actions, ready tray selection and native fallback |
| `panelpopupcontroller.cpp/.h` | Panel-local focus group, mutual exclusion and dismissal policy |
| `popupeffects.cpp/.h` | Native KWin slide and split blur, compositor preference observation |
| `contents/ui/main.qml` | Root `ContainmentItem` — GridView of active icons, AppletPopup, ExpanderArrow |
| `contents/ui/SystemTrayState.qml` | State machine — expanded/collapsed, active applet tracking |
| `contents/ui/ExpandedRepresentation.qml` | Popup content — heading, PlasmoidPopupsContainer, HiddenItemsView |
| `contents/ui/PlasmoidPopupsContainer.qml` | StackView for child applet FullRepresentations |
| `contents/ui/PlasmoidItem.qml` | Wrapper for each child applet icon — handles click/tooltip/context menu |
| `contents/ui/ExpanderArrow.qml` | Chevron toggle for hidden items popup |

### Data Flow

```
Plasmoid.systemTrayModel (C++ multi-source model)
  ├─ PlasmoidModel (embedded plasmoids)
  ├─ StatusNotifierModel (SNI via DBus)
  └─ BackgroundAppsModel (flatpak/background)
       │
       ▼
  KSortFilterProxyModel
  ├─ activeModel (ActiveStatus → panel icons)
  └─ hiddenModel (PassiveStatus → expander popup)
```

### Popup Mechanism

```
User clicks icon
  → PlasmoidItem.onActivated → applet.Plasmoid.activated()
  → applet.expanded = true (framework event)
  → Instantiator detects onExpandedChanged
  → SystemTrayState.setActiveApplet(applet)
  → systemTrayState.expanded = true
  → root.expanded = true (containment sync, triggers framework child-embedding)
  → dialog.visible = true (QML AppletPopup opens)
  → PlasmoidPopupsContainer shows applet.fullRepresentationItem
```

The containment host connects its expanded property to
`SystemTrayState.reconcileHostExpansion(value)`; the state returns
`hostExpansionRequested(value)` instead of accessing the host's QML ID.
This preserves the native expansion contract.

### Shell-session ownership

The tray binary initializes the shared appearance monitor and shortcut
router on the Corona. All ready tray instances forward color changes to
one 350 ms debounce timer. The monitor starts only one appearance helper
at a time, retains the existing exit-75 retry limit and transaction lock,
and keeps the read-only wallpaper bridge available after tray removal.
The existing Python color/material algorithms and D-Bus contract are
unchanged.

The router retains the existing global action component names and IDs.
Only live, completed tray representations receive themed shortcut
requests; screen 0 is preferred and a ready secondary tray is eligible
if the primary disappears. If no tray is ready in the current shell
session, Win+R/V invoke native KRunner/Klipper fallbacks, subject to their
availability. The router does not reassign the user's configured keys.
The installed tray binary must still have been loaded once in that
session; a tray-free cold start is not yet covered.

Start/clock discover popup coordination separately from split blur.
The same-panel tray delegates to PanelPopupController and PopupEffects;
these do not access its applet registry or model. The controller keeps
its own guarded window registrations and 180 ms dismissal timer, while
the effects adapter owns the KWin configuration watcher and preserves
window-local logical geometry. On a provider replacement
they close a mapped popup and use the current provider when reopened.
Clock's native deactivation and opaque fallback remain available.
No separate daemon is installed. Compilation and live multi-screen,
panel rebuild, native fallback, uninstall and shutdown acceptance remain
pending.

---

## Installation

The applet is a C++ plugin loaded from a shared library (`.so`). **It must NOT be installed as a KPackage plasmoid** (see [Critical Bug below](#critical-bug-duplicate-kpackage-installation)).

```bash
# Build and deploy
./dev.sh

# What dev.sh does:
# 1. cmake --build  → compile .so with embedded QML
# 2. Stop plasmashell, fix layout config if corrupted
# 3. Install .so to /usr/lib64/qt6/plugins/plasma/applets/
# 4. Remove any stale KPackage at /usr/share/plasma/plasmoids/
# 5. Restart plasmashell
```

The QML files are embedded in the `.so` via `plasma_add_applet(QML_SOURCES ...)` — same as the stock `org.kde.plasma.systemtray`.

---

## Critical Bug: Duplicate KPackage Installation

### Symptom

A dark rectangle (following the global theme) appeared alongside the system tray popup when clicking individual icons (network, volume, battery, etc.). The expander arrow did NOT have this issue.

### Root Cause

The `CMakeLists.txt` and `install.sh` installed the applet in **two** locations:

1. **`.so` plugin** at `/usr/lib64/qt6/plugins/plasma/applets/org.kde.windowsmodern.systemtray.so`
2. **KPackage plasmoid** at `/usr/share/plasma/plasmoids/org.kde.windowsmodern.systemtray/metadata.json` + `contents/`

This created a duplicate applet registration. The framework found two instances with the same plugin ID. When a child icon was clicked, the framework's child-applet-embedding lookup matched the **KPackage instance** (which had no AppletPopup with content), creating an empty themed popup window — the dark rectangle.

The stock `org.kde.plasma.systemtray` is installed ONLY as a `.so` (no KPackage), which is why it never had this issue.

### Fix

1. **Removed `install(DIRECTORY ...)` from `CMakeLists.txt`** — eliminated KPackage QML installation at build time
2. **Modified `dev.sh`** to install only the `.so` (with embedded QML) and keep a minimal metadata-only KPackage for scripting API discovery (`addWidget()`)
3. **`.so`-only deployment** matching the stock system tray pattern exactly — QML embedded in `.so`, no duplicate applet registration

After this fix, the system tray behaves identically to the stock `org.kde.plasma.systemtray` — one popup for expander, one popup for icons, no dark rectangles.

### Note: Local Plugin Shadowing

A stale copy of the plugin at
`~/.local/lib64/qt6/plugins/plasma/applets/org.kde.windowsmodern.systemtray.so`
(or `~/.local/lib/qt6/plugins/...`) will be loaded in preference to the
system-installed `/usr/lib64/...` copy. Symptom: edits appear to have no
effect after running the install script. The install/uninstall scripts now
remove these local copies automatically.

### Note: Theme Layout Compatibility

The Plasma scripting API's `addWidget()` requires the plugin to be discoverable via KPackage. A minimal KPackage (metadata.json only, no QML) is installed at `/usr/share/plasma/plasmoids/` for this purpose. The QML remains embedded in the `.so`. Theme layout scripts fall back to the stock system tray if our fork isn't found.

The superseded pure-QML prototype remains in Git history. NixOS uses the reversible installer and rejects local KPackage overrides of compiled applets. See [README.md](../README.md).
