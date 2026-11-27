# AGENTS.md

- Read [the project quality ledger](docs/PROJECT_QUALITY_LEDGER.md) first.
  Use its stable task IDs, dependency order and scoped source/desktop
  statuses. Update affected rows, evidence, totals and outstanding
  acceptance in the same batched development commit; do not estimate
  fidelity from commit count or treat partial rows as complete. Keep
  research records in the existing technical documents.
- Follow the ledger's architecture review (A14, D20, V07, V08): prefer
  explicit inputs/actions and one editable source for true shared logic.
  Keep independent applet/greeter packages self-contained, native service
  backends and existing transactions. Address confirmed coupling alongside
  related functional work; do not refactor only to reduce file count or
  introduce a new mandatory runtime service. State the audit scope.
- In the modular source migration, read [modules/README.md](modules/README.md)
  and [core/README.md](core/README.md). Edit only the canonical source for
  paths owned by core/source-map.json; native package mirrors are generated.
  Refresh the mirrors with scripts/materialize-modules.py --write and review
  the complete diff, then check with --check. The existing QML parser and
  packaging entry point reject stale mirrors. Do not add runtime imports
  between independently installed applets or greeter packages.
- Read [the development guide](docs/CONTRIBUTING.md) for product scope,
  architecture, safety requirements and contribution conventions.
- Read [the current UI contract](docs/PANEL_UI_CONTRACT.md) and
  [fidelity requirements](docs/WINDOWS11_FIDELITY.md) before visual changes.
- Keep the full reference library separate from the mapped runtime
  resources. Do not remove original reference art or label compatibility
  drawings as verified Windows originals.
- Review the complete diff and perform relevant static checks only. The
  developer may install missing static-analysis dependencies in an isolated
  development environment, and use syntax, type, interface and lint checks
  without building or running the software. Report missing tools and
  unverified results explicitly.
- Do not run `./verify-all.sh` (it includes automated tests),
  `scripts/ci-build.sh`, builds, automated tests, CI or live desktop checks
  without explicit maintainer authorization. The maintainer performs manual
  compilation, installation and desktop acceptance. Never treat a static
  check or compile pass as visual acceptance.
- Batch related changes on `testing`. Do not create pull requests, merge
  into `main`, dispatch CI, publish releases or change the CI trigger
  policy without explicit maintainer approval. The separate Static Check
  workflow is authorized for explicit static-analysis requests only; it
  never authorizes the formal CI, a build, tests or a release. Change
  `.github/static-check.request` only when a check is requested.
- NixOS uses the reversible installer and ABI-matched native plugins.
  Never modify the Nix store or substitute Fedora builds for NixOS.

## Maintainer desktop acceptance

Static checks and headless tests are not proof for anything KWin or Plasma
loads. The following live-session procedures are reference material for the
maintainer or a separately authorized acceptance session, not instructions
to run them during routine development:

- Drive real input with uinput virtual devices (`python3-evdev`; the
  logged-in user can open `/dev/uinput`) and capture with
  `spectacle -b -n -f -o <file>`, then look at the image.
  `tests/panel/e2e.py` (panel) and `tests/windowswitcher/e2e.py`
  (Alt+Tab) do all of this; shared helpers live in `tests/e2e/`. Extend
  their scenarios rather than writing one-off scripts.
- Find UI by accessible name (`tests/e2e/a11y.py`), never by guessed
  coordinates: tray icons move as icons appear and hide. Use the AT-SPI
  *showing* state for popups — closed popups keep their old extents.
- Wiggle the pointer before driving input (`VirtualInput.announce()`) so
  the person at the machine keeps off the mouse; retry once on failure.
- Read `journalctl --user -b --since …` for QML errors from `kwin_wayland`
  and `plasmashell`.
- Use `pkexec` for anything that needs root. Never build as root.

## Traps

- **KWin caches compiled QML by file path for the whole session.**
  Reinstalling a switcher, effect or script at the same path changes nothing
  until logout. Test the current code with `tests/windowswitcher/e2e.py`,
  which installs under a fresh ID.
- **`dbus-send` defaults to sending a signal**, which KWin ignores. Reload
  KWin through `kwin_reconfigure` in `scripts/install-lib.sh`
  (`--type=method_call`).
- **QML name shadowing across components**: inside a delegate, `foo: foo`
  binds to the object's own `foo` property, not an outer `id: foo`. Give ids
  names that no property uses.
- **Hover over interactive children**: a `MouseArea`'s `containsMouse`
  drops when the pointer moves onto a child `MouseArea` stacked above it, so
  anything bound to it flickers. Track hover with a `HoverHandler`, and test
  hover in the live session; QtTest's synthetic hover hides the flicker.
- **Plasma's scripting API can crash plasmashell**: `evaluateScript`
  reading panel properties segfaults when a panel has no view (its screen
  is disconnected). Read `~/.config/plasma-org.kde.plasma.desktop-appletsrc`
  and `plasmashellrc` instead.
- **Sizes that follow content must not depend on geometry-driven
  visibility**: a view whose height tracks its content, with a scrollbar
  shown "when needed", loops (scrollbar → width → cell size → height).
  Decide such things from counts.
- **The Start button's "Shut down" is a split button**: its left part
  shuts down immediately; only the right-hand chevron opens the menu. Never
  click the left part in a test.
- **Native Qt menus close instantly under uinput input** (e.g. the
  taskbar's right-click menu); a real mouse works. Check those by hand.
- **`spectacle --output` rewrites the user's settings**: Spectacle stores
  every output path as its "last save location". Capture through
  `tests/e2e/session.py:screenshot`, which puts the old value back.
- **Shortcuts registered at runtime don't fire until marked present**:
  kglobalaccel's `setForeignShortcutKeys` stores keys for a new launcher
  (`app.desktop` / `_launch`) but the key does nothing until next login.
  Use `setShortcutKeys` with the SetPresent flag
  (`scripts/windows-shortcuts.py`).
- **dnf cancels a prepared system upgrade**: installing any package
  invalidates a pending `dnf system-upgrade`. Only call
  `install_packages` for packages that are really missing.
- **`cmd | grep -q` lies under `pipefail`** (all installer scripts set it):
  grep exits on the first match, a long-writing `cmd` gets SIGPIPE, and
  the condition comes out false. Use `grep -q pat <<< "$(cmd)"`.
- **Dolphin rewrites its toolbar file** (`dolphinui.rc`) and drops
  comments, so a marker comment cannot prove the file is ours. Record
  ownership in `~/.local/share/windows-modern/backup/`.
- **A plain QtQuick `Window` in a KWin script breaks scripting**: it never
  shows, and other scripts loaded afterwards silently do nothing. Use
  `PlasmaCore.Window` (it always draws the theme's popup frame: don't add
  a second one).
- **Removing a KWin script's package does not unload it**: call
  `org.kde.kwin.Scripting.unloadScript` too, or old and new copies run
  side by side. While iterating on QML scripts, install under fresh ids.
- **Dolphin is a locally patched rpm** (release `.wm1`, status-bar fix):
  `dnf upgrade` silently replaces it with stock — the squashed status bar
  returns until `scripts/fix-dolphin-statusbar.sh` is re-run (or Dolphin
  26.12 arrives, which has the fix). The rpms are kept in
  `~/.local/share/windows-modern/backup/dolphin-rpm/`.
- **`dnf autoremove` removes the user's own leftovers** (wine, mercurial,
  f44-backgrounds…): never run it after installing build deps; the dolphin
  build's `-devel` packages are meant to stay.
- **Headless renders use the software scene graph**: shader effects
  (`MultiEffect`) draw nothing there. Render inside the Wayland session to
  see the GPU path, and give shader-only visuals a software fallback.
- **Don't start the user's apps for a test, and never kill by name.**
  Dolphin (and most KDE apps) hand a new launch to the running instance,
  even under `dbus-run-session`: the test opened a tab in the user's
  Dolphin and `pkill -n dolphin` then closed the user's window. Apps
  started from an agent shell are also killed when the command ends; to
  give one back, use `systemd-run --user --collect <app>`. Test with
  `tests/e2e/testwindow.py` windows, and kill only PIDs you started.
- **Never test the lock screen by locking the session.** Run
  `tests/lockscreen/e2e.py` against a copy of the overlay with its own
  shell Id (`kscreenlocker_greet --testing --shell <id>` shows it in a
  window). It types wrong passwords only. Enter must be accepted whenever
  the password field is shown: the field's visibility and the accept
  guard once used different flags, and Enter was dropped silently.
- **The lock screen's shell overlay must not symlink `logout/`**: the logout
  screen resolves symlinks and refuses files outside the package ("Path
  traversal attempt detected"), so Log out silently does nothing.
  `install-sessionlock.sh` copies it; `verify-all.sh --installed` flags a
  copy that a Plasma update left stale.
- **Forks that reuse a stock plugin ID** (Icon Tasks) replace files owned by
  distro packages: move them to `/var/lib/windows-modern/backup/` and
  restore them on uninstall.
