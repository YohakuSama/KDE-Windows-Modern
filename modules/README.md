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
is complete. No service or system backend is duplicated. Both native
panel scripts use the same taskbar/layout/panel-body.js; the wrappers
preserve their distinct single-panel/all-screen behaviors.

Run `python3 -I scripts/materialize-modules.py --write` to refresh outputs,
then `--check` to compare them. Never edit generated mirrors directly.
A fully mapped source subtree includes new files automatically; otherwise
add an explicit mapping. Remove obsolete outputs deliberately. Do not run
a relocated tool directly when it expects its original runtime path.

Tracked native mirrors are transitional; keep independent native packages
self-contained. The next stage must migrate all build, install, resource
and development consumers to generated staging before deleting mirrors.
Remaining visual atlas, original resource libraries and development/test
tools retain their current locations. See the
[quality ledger](../docs/PROJECT_QUALITY_LEDGER.md).
