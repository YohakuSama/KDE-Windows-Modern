# Native artwork coverage and NixOS testing

The owner requires original Windows 11 resources wherever an equivalent exists. Do not substitute newly drawn approximations for missing Microsoft artwork. Preserve third-party brand identities and use KDE's existing fallback only until a matching native resource is verified. Do not publish Microsoft binaries, extracted artwork, or proprietary fonts to this public repository.

## Inventory

Run the read-only coverage tool against the checkout and installed desktop:

```sh
python3 scripts/icon-coverage.py > icon-coverage-source.json
python3 scripts/icon-coverage.py --installed > icon-coverage-installed.json
```

The second report checks the XDG icon theme and desktop entries, including the paths exported by NixOS. It separates verified native output hashes, mapped but unverified names, bundled artwork, absent theme entries, and absolute icon paths. Static QML literal candidates include some non-icon references. A missing theme entry is not proof of a broken system icon because KDE may inherit Breeze or hicolor. Dynamic QML names, native widget SVGs, scale selection and actual pixmaps need desktop checks. Review the report before sharing. No files are uploaded.

Use the generated report and current mapping to count target paths. These are mapped names, not a claim of complete native artwork coverage. Count paths separately from unique original Windows resources. Do not label an icon native merely because its name is present in the bundled pack.

If the local source was already imported, the existing importer can export resource IDs and hashes without uploading binaries:

```sh
python3 scripts/import-windows-assets.py --reuse --catalog windows-resource-catalog.json
```

Verify exact source artwork before adding mappings. Account pictures and Microsoft Store packaged app assets may be outside the three MUN libraries. Check the actual archive first. If absent, request the precise original assets (and their originating Windows build), not a substitute SVG.

## Runtime assets and NixOS

NixOS uses the reversible desktop installer and builds the tray, taskbar and
desktop context-menu plugins against its own Plasma/Qt ABI. The Fedora 44/45
CI builds are ABI-specific checks, not NixOS binaries. The installer does not
modify the Nix store, configuration.nix, Home Manager or the system greeter.
See the [installation instructions](../README.md).

The complete reference branch `resources/windows11` stays available for
unmapped artwork. The pinned `resources/theme-runtime` branch is the
smaller exact input set for installation. The metadata-only snapshot is
`docs/windows11-resource-index.json`. A group ID alone does not establish
its meaning; inspect the real image, compare state families, update the map,
then review and pin the runtime selection.

Native palette, icon states and input behavior need verification on the
target desktop. Do not claim full coverage based on source checks alone.

## System action review

Use Microsoft's [Segoe Fluent Icons reference](https://learn.microsoft.com/windows/apps/design/iconography/segoe-fluent-icons-font) to distinguish semantic roles. PowerButton E7E8, Restart3 F305, Lock E72E, SwitchUser E748, SignOut F3B1 and the moon-shaped QuietHours E708 used for Sleep are existing mapped roles. The original SignOut mapping was present; same-name status aliases were not. Synchronize power aliases in the status and actions directories so a stale status icon cannot win. Hibernate uses KDE's existing distinct `system-suspend-hibernate` artwork and native `canHibernate`/`hibernate()` API until the exact Windows shell icon is confirmed; never reuse an unrelated glyph or draw one. Keep third-party application logos; the missing Store app artwork is not a test blocker.

Public visual references: [Windows Icon Archive](https://github.com/limehawk/windows-icon-archive) (Windows artwork remains Microsoft's; reference only), [Fluent System Icons](https://github.com/microsoft/fluentui-system-icons) (MIT-licensed separate design system), [Win11 Icon Theme](https://github.com/yeyushengfan258/Win11-icon-theme) (GPL-3.0, already credited). None establishes exact 26H2 equivalence or grants a new license to Microsoft proprietary artwork.
