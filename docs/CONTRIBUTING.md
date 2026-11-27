# Development guide

Read this guide from the repository root. It consolidates product scope
and contributor conventions. For installation and packaging, see
[README.md](../README.md).

## Scope and acceptance

Windows Modern targets the selected Windows 11 reference build, including
layout, typography, iconography, materials, animation and interaction.
Keep KDE and KWin as the platform. Use their native services, real device
states, existing accessibility mechanisms and actual system actions.
Normal installation preserves the user's system fonts.

In scope: taskbar, Start/Search, Quick Settings, notification history and
toasts, calendar, window decorations, icons, cursor, Alt+Tab, Task View,
window snapping, keyboard shortcuts, lock screen, optional login/boot
appearance and limited app-specific appearance adjustments.

Out of scope: promotional content, news feeds, advertising, tracking,
online search results in local search, AI entry points, Windows 10 live
tiles and nonfunctional controls for Windows-only services. Respect the
maintainer's explicit future scope changes.

Use verified original Windows assets for the selected UI roles. Keep
original reference files intact; select only mapped runtime inputs.
Proprietary resource payloads are for authorized local/private use, not
public release artifacts. Preserve upstream authors and licensing.

Support both light and dark variants. Reuse existing native mechanisms
where appropriate, preserve user preferences, make changes reversible,
and avoid duplicating controls or backends. Do not build as root or
overwrite Nix store paths. NixOS uses source-built ABI-matched plugins;
Fedora CI binaries do not establish NixOS support.

[Windows 11 fidelity requirements](WINDOWS11_FIDELITY.md) and
[the current panel contract](PANEL_UI_CONTRACT.md) define visual and
interaction acceptance. Actual live comparisons are required for
visual parity. Missing original artwork and unverified desktop behavior
remain open tasks.

The [project quality ledger](PROJECT_QUALITY_LEDGER.md) is the single
maintained task/status inventory. Read it before each batch and update
the affected stable IDs, evidence, scoped implementation counts and
remaining acceptance in the same testing commit. Keep underlying
reference measurements and implementation contracts in their existing
documents. Do not count diagnostic-only work or an unreviewed scope as
implemented, and do not infer visual parity from the task count.

## Repository layout

| Path | What lives there |
|------|------------------|
| `install.sh`, `uninstall.sh`, `install-nixos.sh` | User entry points and the reversible NixOS backend. Conventional component installers are in `scripts/`. |
| `scripts/install-lib.sh` | Source-only alias of packaging/install-lib.sh. Every installer sources this stable native entry. |
| [`core/`](../core/README.md) | Editable shared control, geometry, palette, animation, logic and resource sources. `source-map.json` declares native package outputs. |
| [`modules/`](../modules/README.md) | Editable feature sources: all seven applets, local flyouts, shell surfaces, window management, login/lock and app appearance. |
| [`platform/`](../platform/README.md) | Editable Qt/Plasma adapters, CMake, NixOS definitions and host tools. |
| [`packaging/`](../packaging/README.md) | Editable component installers and packaging tools. |
| `plasma/applets/` | Native KPackage/build layout, generated from the canonical map except developer tools. |
| `plasma/look-and-feel/`, `plasma/desktoptheme/` | Generated global theme and Plasma style inputs. Edit platform/plasma/globaltheme and platform/plasma/appearance/atlas; generate both renderer modes with the appearance materializer. |
| `aurorae/` | Native mirror of modules/windowmanager/decoration. Generate both mode packages with the appearance materializer. |
| `Kvantum/` | Native mirror of platform/qt/kvantum/style; generate both modes through the appearance materializer. |
| `color-schemes/`, `scripts/theme/palette.json` | Native mirrors of core/palette template and fixed color roles. |
| `plasma/layout-templates/` | Generated Add Panel wrapper and common body from modules/taskbar/layout. The global-theme entry uses the same body. |
| `plasma/windowswitcher/` | The Alt+Tab switcher (a KWin window-switcher layout). |
| `nix/`, `app-decorations/konsole/` | Unique native source locations needed by path-relative Nix builds and the existing independent Konsole syntax check; indexed from platform/nixos and modules/terminal/plugin. |
| `tests/` | Headless regression tests, previews, and separate live desktop tests. |
| `plasma/shells/` | Session lock screen (installed as a shell overlay). |
| `third_party/plasma-login-manager/` | Git submodule for the boot greeter (pinned). |
| `docs/` | Current UI contracts, architecture references, native asset and release guides. |

## Modular source ownership

For mapped files, edit the canonical source in core/, modules/, platform/
or packaging/, not the generated native destination or a source-only alias.
Use `python3 -I scripts/materialize-modules.py --prepare` to refresh generated
outputs and validate source aliases; `--write` is equivalent. Review the
resulting diff, then use `--check` for a read-only consistency check.
The original 436 mapped deployment positions now have one editable
implementation each: 382 generated files, 43 source-only aliases, and 11
native files retained as unique source locations outside the map.
The shared Plasma atlas adds 166 generated native files to the map,
the shared taskbar geometry helper adds four native outputs, and the
shell-session controllers and panel capability helper add six more.
The map now has 558 generated files and 43 aliases.

All mapped Plasma native outputs are ignored by Git, including the
seven applets, C++ backends, native metadata, desktop context-menu
plugin, window scripts, Alt+Tab, panel layouts, lockscreen and greeter
payloads and the Plasma desktoptheme atlas. Existing developer entry
points, tests and preview artwork remain tracked. Frame and switch
generators target the editable atlas by default. The Store dependency
editor writes to platform/plasma/globaltheme and platform/plasma/appearance,
and the login-manager updater reads canonical patches. Existing installers,
QML parsing, icon coverage, native build and QML test entry points
prepare their native inputs. Direct low-level CMake/Nix commands,
generators and individual Python tests should be preceded by `--prepare`.
NixOS uses an existing Python, its previous test runtime or temporary
nix-shell Python before checking build inputs. For privileged conventional
installs, prepare as the desktop user first. Full bundles reconstruct
generated native files from the exact archived commit, excluding development
trees. Mapped Aurorae, Kvantum and color-scheme templates, Plymouth source,
application configuration/patches (except the independently checked Konsole
plugin), component installers and selected frame tools are generated-only.
Use the root install.sh component driver for a fresh checkout; run
--prepare before directly invoking generated low-level scripts. The direct
Dolphin and Plymouth paths read canonical inputs in a source checkout.
Keep rollback available without requiring generated files. The 43 independent
script/data entry paths are tracked relative symlinks validated against
the explicit source map. They are only for a Linux source checkout, not
installed modules. Full archives exclude these links and restore the
canonical bytes and executable modes as regular files; installed
appearance packages also copy real files. Invoke scripts through scripts/
rather than their relocated source paths, and do not download a Git
symlink as a standalone raw script. The seven Konsole native plugin files
and four Nix expressions retain their existing native source locations
to avoid changing the independent static workflow or build identity.
The duplicate module/platform copies have been removed. Do not re-add
generated files or replace an alias with a second implementation.

A complete module can add files within a mapped source tree. Delete obsolete
generated files deliberately when removing their sources; the generator
rejects unmapped files in a fully owned output tree rather than deleting
untracked work. Shared controls use explicit output mappings. Keep separate
hosts self-contained, with no new runtime dependency between applets.
The materializer checks content and executable mode, rejects unowned source
and duplicate outputs, and renders the shared taskbar body into both native
scripts. Keep tools with relative dependencies at their existing execution
paths. A source-generating developer tool that
still targets a mapped native file must be migrated before use; do not
silently edit or overwrite its canonical source.

## Branch and merge flow

- Keep `main` unchanged as the stable branch and `testing` as the modular
  redevelopment and user-acceptance branch. The maintainer intends to
  create a separate repository only after all tasks and manual acceptance
  are complete. Do not create that repository, merge or publish prematurely.
- Push development changes to `testing`. Ordinary branch pushes and
  pull-request events do not start CI. An explicit change to
  `.github/static-check.request` on `testing` requests the separate static
  workflow, without starting the formal CI.
- Complete the relevant local static checks, then have the maintainer install
  and manually verify the `testing` branch in the target Plasma session.
- Keep manual desktop acceptance and explicit maintainer approval as
  prerequisites for opening a pull request, merging `testing` into
  `main`, or dispatching CI. Do not create extra development branches
  or make per-file commits for a related change.
- Only the maintainer or an explicitly authorized operator may start final
  CI through Actions > CI > Run workflow after acceptance, with
  `manual_test_completed` confirmed, or through the separately approved
  `v*` release-tag flow in `scripts/release.sh`.
- A manually dispatched run without the acceptance confirmation fails at
  the gate before health checks or builds start.
- A newer run cancels an older run of the same workflow and ref. Different
  refs remain independent, so a separate release tag is not cancelled.

## Checks

### Developer: static checks only

Before pushing to `testing`, review the full diff, syntax, types, interfaces,
dependencies, resource references, logic and performance. Reuse existing
static-analysis tools. Installing missing analysis tools and matching
development headers in an isolated developer environment is authorized;
do not modify the maintainer's desktop. Static checks do not require a
physical KDE machine.

- Shell: `bash -n` and `shellcheck` on changed scripts.
- QML: `scripts/check-qml-syntax.sh` (Qt parser only), and `qmllint`
  with the matching import modules for changed QML.
- C++: compiler syntax/type checks (for example `clang++ -fsyntax-only`)
  with matching Qt/KDE/Konsole headers, generated declarations and compile
  flags when available. Do not link or build the application or plugin.
- Nix: `nix-instantiate --parse` on changed expressions; no derivation
  realization or build.
- JSON, XML and other declarative files: parse with existing format tools.

Report unavailable tools, missing version-specific headers or imports,
and incomplete checks. Never report a check as passed if it did not run.
If only manual review is available, report that separately. Do not add
one-off checkers merely to claim a passing result.

#### GitHub-hosted static analysis

The independent [Static Check workflow](../.github/workflows/static-check.yml)
uses Fedora 45 for Qt/KDE tools and a pinned Konsole 26.08.3 source tree.
It parses tracked formats, runs the existing QML parser and icon audit,
reports Snap Layouts qmllint diagnostics, and runs Clang `-fsyntax-only`
on the Konsole plugin and its generated Qt metadata. CMake configuration
and declaration generators are allowed; no application/plugin build,
link, automated test, packaging, publication or desktop session is run.
The C++ check covers Konsole only, not all native applets or NixOS ABI
compatibility. Missing KWin import metadata is an unresolved lint result,
not a passing semantic check. Original private resources are not uploaded.

Until the workflow is present on the default branch, GitHub's normal
`workflow_dispatch` is unavailable. On explicit maintainer authorization,
change the text of `.github/static-check.request` in one commit on
`testing` to request a run. Ordinary code commits leave it unchanged.
After the workflow reaches `main` through the approved integration flow,
Actions > Static Check > Run workflow can also select `testing`. Neither
entry point launches the separate `CI` workflow.

### Maintainer: builds, tests and desktop acceptance

The developer must not run full builds, automated tests, live desktop
tests or CI without separate explicit authorization. In particular,
`verify-all.sh` is not static-only: it also runs QML and other automated
test suites. The maintainer retains the following commands for authorized
verification. An authorized CI run executes repository health checks and
the Fedora build matrix, but does not replace manual desktop acceptance.

```bash
./verify-all.sh            # full repository health check, including tests
./scripts/ci-build.sh      # builds the native C++ plugins and checks linking
```

`verify-all.sh` checks that every component exists in both variants, that the
layout scripts have not drifted apart, that every `metadata.json` parses and
applets declare `Id`/`Name`/`Version`/`License`, and runs `bash -n` and
[shellcheck](https://www.shellcheck.net) on every tracked script. Install
shellcheck locally (`dnf install ShellCheck`, `apt install shellcheck`,
`pacman -S shellcheck`) — without it the check is skipped locally but still
enforced in CI.

On a machine with the applets installed, `./verify-all.sh --installed`
additionally inspects the installed System Tray and Icon Tasks plugins.

The Alt+Tab switcher has its own tests and a preview tool that run without
KWin (against a mock `org.kde.kwin`):

```bash
tests/run-qml-tests.sh                       # every headless QML suite (tests/*/tst_*.qml)
tests/windowswitcher/preview.sh dark 7 x.png # render a screenshot
tests/panel/e2e.py --out shots/              # the panel in your running session
tests/shortcuts/e2e.py --out shots/          # Windows shortcuts in your running session
tests/snaplayouts/e2e.py --out shots/        # Snap Layouts: drags a test window to the top
tests/windowswitcher/e2e.py --out shots/     # real Alt+Tab inside your running KWin
tests/icontasks/e2e.py --out shots/          # taskbar: hover focus, Win+1..9
tests/lockscreen/e2e.py --shell SHELL_ID     # lock screen in kscreenlocker's testing mode (never locks)
tests/windowswitcher/e2e.py --scenario close-buttons --out shots/
```

KWin caches the compiled QML of a switcher it has already shown for the
whole session, so reinstalling the switcher does not change what Alt+Tab
shows until you log out. `e2e.py` installs the current code under a one-off
ID (a fresh compile), drives a virtual keyboard and mouse through uinput,
saves screenshots, fails on any QML error KWin logs, and restores your
setting. The `close-buttons` scenario opens three disposable windows and
closes two of them from the switcher with the mouse. `--package DIR` runs a
scenario against other code (e.g. a `git archive` of an older commit) to
confirm a test fails where it should. It needs `python3-evdev`, access to
`/dev/uinput`, and Spectacle.

For QML changes, the developer's static-check phase should use `qmllint`
(`/usr/lib64/qt6/bin/qmllint` on Fedora) on touched files when the matching
modules are available. Report any new warnings and unavailable imports.

## Conventions

### Shell scripts

- `#!/bin/bash` + `set -euo pipefail`; component installers get this from
  `scripts/install-lib.sh`.
- Use the `info` / `warn` / `err` / `step` helpers from `install-lib.sh`.
- Quote every expansion. Guard `rm -rf` targets with `${var:?}` when a
  variable could ever be empty. Use `$HOME`, never a literal `~` in paths.
- **Never build as root.** Root is only for copying finished artifacts into
  `/usr`; use `pkexec bash -s <<EOF` (no temp files in `/tmp`).
- **Never delete files owned by a distro package.** Move them aside to
  `/var/lib/windows-modern/backup/` and restore them on uninstall — see the
  Icon Tasks fork, which reuses the stock `org.kde.plasma.icontasks` ID.
- Anything that replaces a user's config (e.g. the session-lock shell overlay)
  must be built in a staging location and swapped in at the end, so a failed
  run never leaves a half-built state behind.

### Themes

- Every visual change lands in **both** the dark and light variants.
- The panel layout is defined in three files: the layout template and the
  dark/light global-theme layout scripts. The dark and light copies are
  identical; the template differs only in creating one panel instead of
  replacing all panels. Keep the widget sections identical —
  `verify-all.sh` enforces it.

### C++ applets

- Keep changes to native KDE backends small and documented; see
  [the current upstream inventory](UPSTREAM.md) and
  [system tray architecture](SYSTEMTRAY_ARCHITECTURE.md).
- The QML is compiled into the `.so`. Never install a second full QML
  KPackage with the same ID. On NixOS, use the normal reversible installer;
  on conventional distributions use `./install.sh systray` or
  `./install.sh icontasks`.
- After a Plasma upgrade, rebuild and run `./scripts/ci-build.sh` — a soname
  bump or removed API shows up there first.

### Plugin IDs

Plugin IDs in docs must match `metadata.json`. If you rename one, update
`metadata.json`, `CMakeLists.txt`, the applet's `dev.sh`/`verify.sh`, the
layout scripts, `uninstall.sh`, `README.md`, and `docs/STYLE.md` in the same
commit.

### Icon pack

The fallback icon theme is tracked in `icons/windows-modern/`. Review and
stage icon changes normally. Old developer checkouts may have local
skip-worktree flags; clear those before reviewing icon edits. The flags
are not shared repository settings. Do not hide new changes from Git.

## Native resources and screenshots

Keep the complete Windows reference library separate from the mapped runtime
resources. See [native resources](NATIVE_ASSETS.md) for the selection,
pinning and verification workflow. Do not discard an unmapped original from
the reference library merely because the current theme does not use it.

Capture new desktop images with `bash scripts/capture-screenshots.sh`. They
go to the ignored `docs/screenshots/` directory. Compare real desktop
captures against the Windows reference at the same scale, and only use
reviewed current captures to regenerate installed theme previews with
`bash scripts/update-previews.sh`. Do not commit historical captures or
use them to claim current UI parity.

## Commits and pull requests

- [Conventional Commits](https://www.conventionalcommits.org):
  `fix(systemtray): …`, `feat(install): …`, `docs: …`, `chore: …`.
- One logical change per commit; add an entry under **Unreleased** in
  `CHANGELOG.md` for anything user-visible.
- Describe how you tested: which checks you ran, and for UI changes which
  Plasma version and variant (dark/light) you tried, ideally with a screenshot.

## Releases

Maintainers follow [`docs/RELEASE.md`](RELEASE.md). `scripts/release.sh`
refuses to publish unless `verify-all.sh` passes and every component version
matches the release version.

## License

By contributing you agree that your contributions are licensed under the
GNU GPL v3 (see [`LICENSE`](../LICENSE)). Code forked from KDE keeps its original
SPDX headers.
