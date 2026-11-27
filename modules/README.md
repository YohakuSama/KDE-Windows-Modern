# Feature modules / 功能模块

Edit feature-specific implementation here. Shared controls and algorithms
belong to [core](../core/README.md). Native adapters belong to
[platform](../platform/README.md).

| Directory | Ownership / native host |
| --- | --- |
| startmenu/ | Start UI, pages, actions, config / startmenu |
| search/ | Search entry, home, results and field / search + startmenu |
| taskbar/ | Tasks, preview, layout, local logic / icontasks + panel/global theme |
| systemtray/ | Tray icons, overflow, routing, config / systemtray |
| quicksettings/ | Quick settings, device pages, media and tiles / systemtray |
| clipboard/ | History and emoji page / systemtray |
| run/ | Run dialog / systemtray |
| taskview/ | Task View entry / taskview |
| showdesktop/ | Show Desktop UI/controller / showdesktop |
| calendar/ | Clock/calendar, combined popup host / digitalclock |
| notifications/ | Notification history, focus and presentation / digitalclock |
| windowmanager/ | Snap, Alt+Tab, OSD, decoration / KWin + Aurorae |
| desktopmenu/ | Desktop menu layout / containment action |
| lockscreen/ | Session lock UI/config / shell overlay |
| login/ | Greeter UI / global theme |
| boot/ | Splash, Plymouth and boot appearance |
| explorer/ | Dolphin config and limited patches |
| terminal/ | Konsole chrome/plugin/config |
| browser/ | Optional Firefox appearance |

Modules are source owners, not new installed applet IDs. The tray remains
the native composition host of its flyouts until interface/lifecycle work
is complete. No service or system backend is duplicated. All Apps and Search pages
publish activation signals rather than closing their host directly;
Search receives its mode explicitly. Tray expansion reconciliation uses
an explicit state input and host-expansion signal. Both native
panel scripts use the same taskbar/layout/panel-body.js; the wrappers
preserve their distinct single-panel/all-screen behaviors.
Icon Tasks supplies live per-instance geometry and configuration inputs to
LayoutMetrics.js; the grid, task delegates and group dialog read those
inputs without resolving foreign IDs. The drag and audio components
receive their task manager or task items explicitly. Start, Search, Task
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
