# Feature modules / 功能模块

Edit the feature source in these directories. Common controls and
algorithms belong to [core](../core/README.md). Each directory contains
actual editable source, rather than a new installed applet ID.

| Source | Ownership | Native package |
| --- | --- | --- |
| startmenu/ | Start UI, pages, menu logic, config and metadata | startmenu |
| search/ | Taskbar Search, Start Search home/results/field (startmenu/) | search and startmenu |
| taskview/ | Task View entry UI and metadata | taskview |
| showdesktop/ | Show Desktop UI, controller and config | showdesktop |
| calendar/ | Clock, calendar, common notification/calendar host, config | digitalclock |
| notifications/ | Notification history, focus and presentation helpers | digitalclock |

The native package needs all of its local imports, resources and metadata.
The source map assembles shared files and feature-owned files into those
exact paths. Search keeps the native Start search model; notifications
keep the native clock host and KDE notification model. No service or
backend is duplicated. The layout of the installed packages is unchanged.

`python3 -I scripts/materialize-modules.py --write` refreshes the
declared mirrors; `--check` verifies them without writing. Existing
static QML parsing and packaging check the mirrors before consuming them.
Do not edit the native mirror directly. For deleted files, review and
remove the corresponding obsolete native output explicitly; the
materializer refuses to delete unrelated/untracked files.

This is the first migration batch. Native tray/taskbar backend and
other packages still have their existing editable source paths except
shared files owned by core. Continue migrating by functional ownership
and native consumer dependencies. Once all consumers use staged package
outputs, remove the temporary tracked mirrors rather than maintain two
editable layouts. Keep installed native packages self-contained.

The testing branch is the redevelopment branch. The maintainer will
decide on a separate repository only after all tasks and desktop
acceptance are complete; see the [quality ledger](../docs/PROJECT_QUALITY_LEDGER.md).
