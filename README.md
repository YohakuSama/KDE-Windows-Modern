# Windows Modern for KDE Plasma 6

A Windows 11-style desktop theme for KDE Plasma 6, with light and dark
variants, native KDE services and Windows-style shell interactions.

The project targets Windows 11 visual and interaction fidelity. It is still
under development; a successful build is not proof of exact visual parity.

## Features

- Taskbar, Start, Search, Task View button, window previews and Show Desktop.
- Quick Settings, native network and Bluetooth controls, sound, brightness,
  clipboard, notifications and calendar.
- Window decorations, Kvantum Qt style, Plasma colors and popup materials.
- Alt+Tab, window snapping, keyboard shortcuts, desktop context menu and
  session lock screen.
- Icon theme, wallpaper, cursors, sounds, session splash and translations.

KDE and KWin provide the underlying functionality. Windows application
compatibility, a separate Windows desktop environment and a complete GTK
2/3/4 theme are not part of this package. The system login manager and early
boot theme are separate, optional components. System fonts are preserved
during normal installation.

## Optional application window layouts

An opt-in Konsole integrated title bar and the Dolphin Explorer layout
boundaries are documented in [application window layouts](docs/APP_WINDOW_CHROME.md).
The Konsole trial remains opt-in pending manual desktop acceptance.
For a complete NixOS desktop test including the terminal plugin, run
`bash install.sh menu --with-konsole` and choose installation or upgrade.
The isolated manual build/run commands remain available.

## NixOS

Run the installer as your normal desktop user in a running Plasma 6 session.
Extract the complete private theme ZIP first, or use a current source checkout.

```bash
bash install.sh
```

Choose:

| Option | Action |
| --- | --- |
| 1 | First installation: back up the desktop, build and install the theme |
| 2 | Incremental upgrade: build and replace changed components |
| 3 | Uninstall: restore the original desktop and remove theme-owned test files |

The default variant is dark. Use `bash install.sh --light` to open the menu
with the light variant selected. Non-interactive actions:

```bash
bash install.sh install --dark
bash install.sh upgrade
bash install.sh uninstall
# Complete testing installation, including the isolated Konsole plugin:
bash install.sh install --dark --with-konsole
# Or add the plugin to an existing test installation:
bash install.sh upgrade --with-konsole
```

The terminal test requires installed Konsole 26.08.x and the exact matching
nixpkgs package. It adds a separate Windows Modern Terminal launcher; the
stock Konsole and its launcher remain available. Later upgrades retain the
terminal test and uninstall restores/removes the test-owned launcher.
A failed build or missing plugin/glyph stops before the desktop is switched.

The installer builds the tray, taskbar and desktop context-menu plugins
against the running NixOS Plasma/Qt version. It verifies plugin identities, preserves the existing layout on
upgrade, and retains the original uninstall baseline. A failed upgrade
attempts to restore the previous runtime. It does not edit
`configuration.nix`, Home Manager or `/nix/store`, and does not replace the
system login manager. A new login may be required for KWin or Qt changes.

### Build the complete private theme ZIP

To clone and package the current source (run from the desired parent directory):

```bash
nix-shell -p git zip unzip python3 curl gnutar xz util-linux --run '
set -e
git clone --depth 1 --recurse-submodules https://github.com/YohakuSama/KDE-Windows-Modern.git
cd KDE-Windows-Modern
bash scripts/package.sh --owner
'
```

From an existing checkout, update `main`, initialize the pinned submodule
and run `bash scripts/package.sh --owner` with the same tools available.

The output is `dist/KDE-Windows-Modern-<version>-owner-<commit>.zip`.
The exact verified file path is written to `dist/.owner-manifest` only
after successful packaging.

This source-build package includes theme components, original mapped
resources, installation and rollback dependencies, and user documentation.
All full installable ZIPs exclude developer scripts, CI, development tests,
reference screenshots and build caches. The private package additionally
excludes unused fonts, complete MUN files and unused icon frames. The runtime resource
cache is reused by pin; size alone does not determine completeness.

### Packages are different

| Package | Purpose |
| --- | --- |
| Private owner ZIP (`--owner`) | Complete theme for private desktop testing, including mapped Windows resources |
| CI integration ZIP (`--integration`) | Exact checked source and ABI-specific plugin builds; no original owner resource payload |
| Public release / KDE Store components | Redistributable source and individual theme components |

The public CI ZIP is not the complete private owner package. Do not use an
older or smaller CI artifact as a replacement for a requested owner ZIP.
The private package is not added to public release manifests.

## Other Plasma 6 distributions

Use a complete source checkout or an appropriate installable package.
For a checkout with Git available:

```bash
git clone --recurse-submodules https://github.com/YohakuSama/KDE-Windows-Modern.git
cd KDE-Windows-Modern
bash install.sh
```

On conventional mutable-system distributions, the installer uses its own
component menu. It can install build dependencies and native plugins through
the supported distro tools. Matching prebuilt plugins are usable only for
the exact distro, architecture, Plasma and Qt ABI. Fedora CI builds do not
establish support on all other distributions.

```bash
bash install.sh all --dark
bash install.sh all --light
bash install.sh --help
bash uninstall.sh all
bash uninstall.sh --restore
```

A full installation can reset the desktop layout. Existing configuration
backups are retained. Individual component commands and optional app/font
installation are listed by `--help`. These component commands are for the
conventional installer; NixOS uses the reversible actions above.

## Appearance and resources

The global color scheme follows KDE's accent settings by default. An explicit
Windows accent ramp can instead be applied through the shared appearance
switch; see the system accent propagation notes in [STYLE.md](docs/STYLE.md#system-accent-propagation).
Original Windows artwork is imported from reviewed owner resources; an unverified or missing
role keeps a compatibility fallback. The complete development reference
library remains separate from the small installable runtime input set.
See [native asset import](docs/NATIVE_ASSETS.md) and
[cursor credits](docs/CURSORS.md).

On conventional installations and complete NixOS test installations,
transparency can be changed with `bash install.sh transparency on`, `off`
or `refresh`. Omit the final argument to show the saved state. The NixOS
command uses the existing runtime and backup; it does not build, reset
the layout or modify the Nix store. The normal theme does not replace
the user's text fonts.

## Optional boot and login appearance

The session lock screen and Plasma splash are desktop theme components.
Plymouth is optional and is not configured by the desktop installer.

On NixOS, add the optional package from the unpacked checkout to your
existing declarative configuration:

```nix
{ pkgs, ... }: {
  boot.plymouth = {
    enable = true;
    theme = "windows-modern";
    themePackages = [
      (pkgs.callPackage /absolute/path/to/KDE-Windows-Modern/nix/plymouth-theme.nix {})
    ];
  };
}
```

Rebuild using your existing NixOS workflow. Keep your fallback boot
generation and disk-unlock settings. To revert, remove the optional
configuration and rebuild. Test early-boot prompts before using it on a
production system.

On other distributions, `scripts/theme/boot-frames.py` generates the
Plymouth theme for manual distribution-specific installation. The patched
Plasma Login Manager greeter is also optional; it is not installed by the
NixOS desktop workflow. See the
[greeter build guide](plasma/look-and-feel/org.kde.windowsmodern.dark/BUILD.md).

## Troubleshooting

- Run installation inside the active Plasma session, as the desktop user.
- Use the upgrade action on NixOS instead of reinstalling the entire layout.
- A mismatched native plugin or cached QML can prevent applets from loading;
  check the installer output and the running Plasma logs.
- If the shell is no longer visible, run
  `systemctl --user restart plasma-plasmashell.service`.
- Inspect errors with `journalctl --user -b -u plasma-plasmashell.service`.
- Restore using the installer/uninstaller rather than deleting KDE
  configuration or Nix store files by hand.

## Development

The source repository retains tests, current design contracts, original
reference metadata and upstream attribution. Development files do not
belong in the private installation ZIP. In a source checkout, use the
[project quality ledger](docs/PROJECT_QUALITY_LEDGER.md) for current
implementation status, remaining work, priorities and maintainer acceptance.
The [contributor guide](docs/CONTRIBUTING.md) and
[Windows 11 fidelity requirements](docs/WINDOWS11_FIDELITY.md) define the
development and technical contracts for this checkout. For packaged copies,
see the [online testing ledger](https://github.com/YohakuSama/KDE-Windows-Modern/blob/testing/docs/PROJECT_QUALITY_LEDGER.md)
and [development documentation](https://github.com/YohakuSama/KDE-Windows-Modern/tree/testing/docs).
UI acceptance requires current live desktop captures in both variants;
historical screenshots are not used as current previews.

## Credits and license

Based on Win11OS-kde by yeyushengfan258 and Windows Modern by Jeysef, with
components derived from KDE Plasma, Zren, Eleven, Fluent and other projects.
See [AUTHORS](AUTHORS), [ATTRIBUTION.md](ATTRIBUTION.md) and [LICENSE](LICENSE).
The original authors and upstream license notices are retained.

### One Windows Modern theme, two appearance modes

The full installer installs one global theme named Windows Modern. Its historical package ID is retained for greeter compatibility. Use the Dark Mode tile in Quick Settings, or run `bash scripts/theme/switch-mode.sh light` / `bash scripts/theme/switch-mode.sh dark` in the desktop session. Changing mode does not reapply the global theme or reset the desktop layout.

The dark Plasma source directory is the single shared artwork source. The materializer generates both renderer packages from it, using the existing material generators and light CSS roles, paint and opacity values in `scripts/theme/appearance-packages.py`. Both Aurorae decorations and global-theme Store exports are also derived from their shared sources. Kvantum uses one configuration template and one SVG geometry template to generate both engine modes at installation. KDE color schemes also come from one template and a shared fixed palette used by Kvantum and the Aurorae window base. Store exports retain separate mode-specific dependency IDs and preview images; historical IDs remain export and upgrade interfaces. Install or package through the provided scripts; do not copy the source directories directly into Plasma. See [appearance implementation notes](docs/NATIVE_COVERAGE.md#shared-appearance-and-mode-specific-rendering) for the remaining renderer-specific differences.
