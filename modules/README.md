# Feature modules / 功能模块

Edit feature-specific implementation here. Shared controls and algorithms
belong to [core](../core/README.md). Native adapters belong to
[platform](../platform/README.md).

| Directory | Feature source ownership | Native host / integration |
| --- | --- | --- |
| startmenu/ | Start UI, Kicker model/actions and config | Start applet |
| search/ | Standalone Search UI and Start-hosted search pages | Search applet + Start package |
| taskbar/ | Icon Tasks UI, previews, task layout and local logic | Icon Tasks applet + panel/global-theme layouts |
| systemtray/ | Tray shell, overflow, popup composition and routing | System Tray applet |
| quicksettings/ | Quick Settings tiles, device pages, media and tile ordering | System Tray composition host |
| clipboard/ | Klipper history and emoji presentation | System Tray composition host |
| run/ | Run dialog presentation | System Tray composition host |
| taskview/ | Task View entry | Task View applet |
| showdesktop/ | Show Desktop UI/controller | Show Desktop applet |
| calendar/ | Clock, time zones and combined popup composition | Digital Clock applet |
| notifications/ | Notification history, focus session and notification presentation | Digital Clock composition host |
| windowmanager/ | Snap layouts/keys, Alt+Tab, OSD and Aurorae decoration | KWin scripts, switcher and Aurorae |
| desktopmenu/ | Desktop context-menu layout | Containment-action plugin |
| lockscreen/ | Session lock UI/config | Lock-screen shell overlay |
| login/ | Greeter UI | Global theme / login-manager host |
| boot/ | Session splash, Plymouth and boot appearance | Global theme / Plymouth |
| explorer/ | Dolphin configuration and versioned presentation patches | Dolphin / isolated patch adapter |
| terminal/ | Konsole UI configuration and native menu definitions | Konsole / private ABI adapter in platform/qt/konsole |
| browser/ | Optional Firefox appearance | Firefox app-decoration |

## Runtime composition boundaries

A native Plasma applet can compose several feature-owned source trees.
The source map materializes those trees into one self-contained package.
This is an intentional runtime boundary, not shared source ownership or
a reason to create extra applet IDs. The materializer rejects duplicate
destination paths.

| Native host | Composed feature sources | Integration contract |
| --- | --- | --- |
| `org.kde.windowsmodern.systemtray` | `systemtray`, `quicksettings`, `clipboard`, `run` | System Tray owns the shell, overflow, popup container and global routing. Quick Settings owns its tiles/pages, Clipboard owns Klipper history/emoji presentation, and Run owns RunDialog. The host dispatches Win+V, lazily loads RunDialog for Win+R, and injects its command runner and work area. |
| `org.kde.windowsmodern.digitalclock` | `calendar`, `notifications` | Calendar owns the clock/time-zone shell and combined popup. Notifications owns history presentation, focus-session logic and bell policy. The clock host creates one native notification settings/model pair and passes it to the notification views. |
| `org.kde.windowsmodern.startmenu` | `startmenu`, `search/startmenu` | Start owns the Kicker model and root search actions. Search contributes the Start-hosted search field/pages and consumes Start-owned helpers. Search also has its own separate taskbar applet. |

The Search pages use Start's `tools.js` and `theme.js` from the composed
Start package. Start remains the owner of the launcher model and native
search actions; Search observes those actions and does not start a second
runner/model. Calendar's compact representation consumes
`notifications/ui/code/notificationPresentation.js` for bell visibility
and icon selection. NotificationHistory receives the existing native
notification model/settings and does not create another notification
service.

Quick Settings and Clipboard consume shared palette/flyout resources from
`core/` that are materialized into the System Tray package. RunDialog
receives `commandRunner` and `workArea` from its host. These dependencies
preserve native KDE backends and keep feature UI in its owning module.

Shared controls used by Calendar and Notifications are canonically owned
under `core/controls/`; their existing Digital Clock package paths are
materialized by `core/source-map.json`. Do not add feature-local copies.

The greeter and lock-screen shell likewise share `AccountAvatar.qml` and
`VirtualKeyboardButton.qml` from `core/controls/`. The keyboard control keeps
the greeter's hidden-when-unavailable behavior and the lock screen's
visible-but-disabled Accessibility entry through `lockScreenPresentation`.
Both hosts retain their loaders so a missing optional keyboard module cannot
break the rest of the shell.

Source modules are ownership boundaries, not new installed applet IDs.
No service or system backend is duplicated. Pinned, All Apps, Recommended
and Search pages publish activation and context-menu signals rather than
closing their host or reaching into outer shell IDs directly; Search
receives its mode, app lookup callback, favorites model and sorted app
model explicitly, and MenuRepresentation receives its anchor button and
Kicker models from CompactRepresentation/main.qml. Tray expansion
reconciliation uses an explicit state input and host-expansion signal,
and tray subviews/delegates (`ExpandedRepresentation`, `HiddenItemsView`,
`PlasmoidPopupsContainer`, `ExpanderArrow`, `CurrentItemHighLight`,
`ItemLoader`, `AbstractItem`, `PlasmoidItem`, `BackgroundAppItem`) receive
`trayRoot`, `trayState`, dialog and preload hosts explicitly. Both native
panel scripts use the same taskbar/layout/panel-body.js; the wrappers
preserve their distinct single-panel/all-screen behaviors.
Icon Tasks supplies live per-instance geometry, desktop/activity, MPRIS,
drag, WindowView and tooltip delegate inputs through `tasksRoot` and
`hostDelegate`; `TaskList`, `Task`, `GroupDialog`, `ContextMenu`,
`ToolTipDelegate`, `ToolTipInstance`, `ToolTipWindowMouseArea`,
`MouseHandler`, `AudioStream`, `PulseAudio`, `PlayerController` and lazy
task/thumbnail overlays (`GroupExpanderOverlay`, `TaskBadgeOverlay`,
`TaskProgressOverlay`, `PipeWireThumbnail`) read those explicit inputs
without resolving foreign IDs. Lock screen and greeter subviews likewise
communicate through explicit host properties, methods and signals. Start, Search, Task
View and Icon Tasks use core/design/taskbarGeometry.js for their shared
logical icon canvas. The source map materializes it into each independent
applet; Icon Tasks also registers it in its native QML resources.
The window-group delegates receive the parent model index explicitly,
including while the group dialog is being constructed. Start and the
clock resolve independent optional panel capabilities through
core/logic/panelCapabilities.js. Replacing their coordinator closes an
already mapped popup; reopening uses the current provider or the native
fallback. The tray forwards palette events and registers its ready UI
with the Corona-owned controllers in platform/plasma.
Start now owns the Search actions at the applet root, independently of
its compact UI. Search watches the same-panel provider's native action
registration and readiness, keeps open/state actions paired and resolves
again on activation. The original Start model and editor remain the
single search implementation; no unrelated launcher or second model
is started when the provider is unavailable.

Run `python3 -I scripts/materialize-modules.py --prepare` to refresh
generated-only outputs and validate source-only aliases.
`--check` compares without writing. The older `--write` command is equivalent
to `--prepare`.
Never edit generated mirrors directly. A fully mapped source subtree
includes new files automatically; otherwise add an explicit mapping.
Remove obsolete outputs deliberately. Do not execute relocated tools that
depend on their native runtime paths.

All mapped Plasma native sources are generated-only, including the
seven applets' QML, configurations, metadata and C++ sources, the KWin
scripts, Alt+Tab, desktop context-menu plugin, both panel layouts and
global-theme/lockscreen/greeter/splash payloads. Git tracks their canonical
editable sources only. Existing developer launchers, test sources,
unmapped preview assets remain tracked. The shared Plasma visual atlas
is owned by platform/plasma/appearance/atlas; its native path is generated.
Standard install and developer entry points prepare generated
files; full install ZIPs reconstruct them from the archived commit.
Aurorae, Plymouth, application configuration and Dolphin patches are also
generated-only. The terminal module's version-matched Konsole adapter is maintained in
[platform/qt/konsole](../platform/qt/konsole/); its module entry
[terminal/plugin](terminal/plugin/README.md) documents the feature boundary.
The native build input at app-decorations/konsole is generated from that
platform source and must not be edited directly.
Nix build expressions likewise retain their native paths as unique sources.
The 44 script/data entry paths are source-only relative symlinks
to their canonical files. Install ZIPs and appearance packages use real
files, never these aliases. Keep packages self-contained and prepare before
direct low-level invocation. See the [quality ledger](../docs/PROJECT_QUALITY_LEDGER.md).

## Functional module ownership audit

After the shared-control consolidation on testing (2026-11-27), the complete
Git tree contains 19 feature module roots and 227 module
source/configuration/resource files. The source map accounts for all of them:
224 are direct tree/file mappings and the three taskbar layout sources feed
the two rendered layout recipes. The
module mappings have no duplicate output destinations. This is a static
ownership/source-map review, not a build or runtime validation.
