# Native artwork coverage and NixOS testing

The owner requires original Windows 11 resources wherever an equivalent exists. Do not substitute newly drawn approximations for missing Microsoft artwork. Preserve third-party brand identities and use KDE's existing fallback only until a matching native resource is verified. Do not publish Microsoft binaries, extracted artwork, or proprietary fonts to this public repository.

## Inventory

Run the read-only coverage tool against the checkout and installed desktop:

```sh
python3 scripts/icon-coverage.py > icon-coverage-source.json
python3 scripts/icon-coverage.py --installed > icon-coverage-installed.json
```

The second report checks the XDG icon theme and desktop entries, including the paths exported by NixOS. It separates verified native output hashes, mapped but unverified names, bundled artwork, absent theme entries, and absolute icon paths. Static QML literal candidates include some non-icon references. A missing theme entry is not proof of a broken system icon because KDE may inherit Breeze or hicolor. Dynamic QML names, native widget SVGs, scale selection and actual pixmaps need desktop checks. Review the report before sharing. No files are uploaded.

The current map has 583 target paths: 260 status, 226 actions, 40 devices, 37 places, 8 MIME, 7 apps and 5 emblems. The seven app targets are not comprehensive app icon coverage. Count paths separately from unique original Windows resources. Do not label an icon native merely because its name is present in the bundled pack.

If the local source was already imported, the existing importer can export resource IDs and hashes without uploading binaries:

```sh
python3 scripts/import-windows-assets.py --reuse --catalog windows-resource-catalog.json
```

Verify exact source artwork before adding mappings. Account pictures and Microsoft Store packaged app assets may be outside the three MUN libraries. Check the actual archive first. If absent, request the precise original assets (and their originating Windows build), not a substitute SVG.

## NixOS is a separate platform

Fedora 44/45 builds are distro-specific ABI checks and prebuilt plugin packages; they are not universal Linux binaries. The existing installer assumes conventional writable /usr paths and dnf, pacman or apt. It must not overwrite the Nix store or remove a stock Plasma package on NixOS. The two C++ plugins need Nix derivations using the owner's pinned nixpkgs Plasma/Qt versions, and the login-manager replacement needs its own declarative system integration. Keep the stock lock/login configuration usable until verified. User-level theme and resource auditing is separate from these system changes. No NixOS runtime acceptance is claimed.

The indexed resource branch is now the review reference. The metadata-only
snapshot is `docs/windows11-resource-index.json`; do not equate a group ID
existing with a verified semantic match. Search/Task View now consume icon
names rather than inline drawings. Native palette and hotspot state must
reflect the actual KDE service; missing hardware does not get a dummy tile.
Default account-picture and Store artwork still require visual verification
of the actual original, not a guessed MUN ID. NixOS live tests remain open.

## System action review

Use Microsoft's [Segoe Fluent Icons reference](https://learn.microsoft.com/windows/apps/design/iconography/segoe-fluent-icons-font) to distinguish semantic roles. PowerButton E7E8, Restart3 F305, Lock E72E, SwitchUser E748, SignOut F3B1 and the moon-shaped QuietHours E708 used for Sleep are existing mapped roles. The original SignOut mapping was present; same-name status aliases were not. Synchronize power aliases in the status and actions directories so a stale status icon cannot win. Hibernate uses KDE's existing distinct `system-suspend-hibernate` artwork and native `canHibernate`/`hibernate()` API until the exact Windows shell icon is confirmed; never reuse an unrelated glyph or draw one. Keep third-party application logos; the missing Store app artwork is not a test blocker.

Public visual references: [Windows Icon Archive](https://github.com/limehawk/windows-icon-archive) (Windows artwork remains Microsoft's; reference only), [Fluent System Icons](https://github.com/microsoft/fluentui-system-icons) (MIT-licensed separate design system), [Win11 Icon Theme](https://github.com/yeyushengfan258/Win11-icon-theme) (GPL-3.0, already credited). None establishes exact 26H2 equivalence or grants a new license to Microsoft proprietary artwork.
