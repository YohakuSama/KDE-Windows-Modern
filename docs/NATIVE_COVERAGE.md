# Native artwork coverage and NixOS testing

The owner requires original Windows 11 resources wherever an equivalent exists. Do not substitute newly drawn approximations for missing Microsoft artwork. Never fall back to KDE artwork for project-owned system controls. Preserve actual third-party application identities, and report unresolved Windows artwork instead of assigning a misleading glyph. Do not publish Microsoft binaries, extracted artwork, or proprietary fonts to this public repository.

## Inventory

Run the read-only coverage tool against the checkout and installed desktop:

```sh
python3 scripts/icon-coverage.py > icon-coverage-source.json
python3 scripts/icon-coverage.py --installed > icon-coverage-installed.json
```

The second report checks the XDG icon theme and desktop entries, including the paths exported by NixOS. It separates verified native output hashes, mapped but unverified names, bundled artwork, absent theme entries, and absolute icon paths. Static QML literal candidates include some non-icon references. Explicit Breeze inheritance is removed. A missing theme entry can still trigger implicit toolkit fallbacks or resolve via hicolor; treat project-owned controls using those fallbacks as unresolved coverage, not verified Windows artwork. Dynamic QML names, native widget SVGs, scale selection and actual pixmaps need desktop checks. Review the report before sharing. No files are uploaded.

Use the generated report and current mapping to count target paths. These are mapped names, not a claim of complete native artwork coverage. Count paths separately from unique original Windows resources. Do not label an icon native merely because its name is present in the bundled pack.

If the local source was already imported, the existing importer can export resource IDs and hashes without uploading binaries:

```sh
python3 scripts/import-windows-assets.py --reuse --catalog windows-resource-catalog.json
```

Verify exact source artwork before adding mappings. Account pictures and Microsoft Store packaged app assets may be outside the three MUN libraries. Check the actual archive first. If absent, request the precise original assets (and their originating Windows build), not a substitute SVG.

## Reviewed reference-branch coverage

The `resources/windows11` branch is the existing source of truth. Do not
download a second copy of these MUN resources or copy the entire reference
branch into the runtime package.

| Module | Indexed groups | Currently mapped groups | Not yet mapped |
| --- | ---: | ---: | ---: |
| `imageres.dll.mun` | 369 | 56 | 313 |
| `shell32.dll.mun` | 335 | 4 | 331 |
| `imagesp1.dll.mun` | 9 | 1 | 8 |
| **Total** | **713** | **61** | **652** |

The reviewed reference commit `272e06c87be0f548cebb2558392019b941df20d4`
contains 5,405 original icon frames and 467 original files. The current
mapping has 263 source entries: 61 MUN group references and 202 Segoe
Fluent Icons glyph references. These are source mappings, not 263 distinct
visuals or a claim that all 713 groups are relevant to the current desktop.
The runtime branch deliberately stages only the selected mapped previews,
not the complete archive.

The reference snapshot contains the three MUN modules above and the
`SegoeIcons.ttf` extraction font. It does not contain a `SystemApps`
tree, a PRI resource index, `Sysbatt.ttf`, `AXPIcons.ttf`, the
`StartMenu/Assets/SearchIcons` state PNGs, or the
`Windows.UI.SettingsAppThreshold.pri` Task View SVGs. Its manifest also
does not record a Windows build number. Do not label this snapshot as a
verified Windows 11 26H2 resource set.

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

Use Microsoft's [Segoe Fluent Icons reference](https://learn.microsoft.com/windows/apps/design/iconography/segoe-fluent-icons-font) to distinguish semantic roles. PowerButton E7E8, Restart3 F305, Lock E72E, SwitchUser E748, SignOut F3B1 and the moon-shaped QuietHours E708 used for Sleep are existing mapped roles. The original SignOut mapping was present; same-name status aliases were not. Synchronize power aliases in the status and actions directories so a stale status icon cannot win. Hibernate still has an unresolved legacy compatibility icon; audit its actual Windows equivalent before claiming complete native coverage. Keep its real `canHibernate`/`hibernate()` action independent of artwork; never reuse an unrelated glyph or draw one. Keep third-party application logos; the missing Store app artwork is not a test blocker.

Public visual references: [Windows Icon Archive](https://github.com/limehawk/windows-icon-archive) (Windows artwork remains Microsoft's; reference only), [Fluent System Icons](https://github.com/microsoft/fluentui-system-icons) (MIT-licensed separate design system), [Win11 Icon Theme](https://github.com/yeyushengfan258/Win11-icon-theme) (GPL-3.0, already credited). None establishes exact 26H2 equivalence or grants a new license to Microsoft proprietary artwork.
