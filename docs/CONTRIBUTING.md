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

## Repository layout

| Path | What lives there |
|------|------------------|
| `install.sh`, `uninstall.sh`, `install-nixos.sh` | User entry points and the reversible NixOS backend. Conventional component installers are in `scripts/`. |
| `scripts/install-lib.sh` | Shared helpers (paths, logging, apply/restart). Every installer sources it. |
| `plasma/applets/` | Applets. `startmenu`, `showdesktop`, `digitalclock` and the optional `search` / `taskview` buttons are pure QML; `systemtray` and `icontasks` are C++ forks of upstream Plasma applets. |
| `plasma/look-and-feel/`, `plasma/desktoptheme/`, `aurorae/`, `Kvantum/`, `color-schemes/` | Theme assets, always in **dark and light** variants. |
| `plasma/layout-templates/` | The "Add Panel → Windows Modern Panel" template. |
| `plasma/windowswitcher/` | The Alt+Tab switcher (a KWin window-switcher layout). |
| `tests/` | Headless regression tests, previews, and separate live desktop tests. |
| `plasma/shells/` | Session lock screen (installed as a shell overlay). |
| `third_party/plasma-login-manager/` | Git submodule for the boot greeter (pinned). |
| `docs/` | Current UI contracts, architecture references, native asset and release guides. |

## Checks

Run these before opening a pull request. CI runs the same ones.

```bash
./verify-all.sh            # repository health check — must pass
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

For QML changes, also run `qmllint` (`/usr/lib64/qt6/bin/qmllint` on Fedora)
on the files you touched and don't add new warnings.

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
