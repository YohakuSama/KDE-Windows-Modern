# Native artwork coverage and NixOS testing

The owner requires original Windows 11 resources wherever an equivalent exists. Do not substitute newly drawn approximations for missing Microsoft artwork. Never fall back to KDE artwork for project-owned system controls. Preserve actual third-party application identities, and report unresolved Windows artwork instead of assigning a misleading glyph. Do not publish Microsoft binaries, extracted artwork, or proprietary fonts to this public repository.

## Inventory

Run the read-only coverage tool against the checkout and installed desktop:

```sh
python3 scripts/icon-coverage.py > icon-coverage-source.json
python3 scripts/icon-coverage.py --installed > icon-coverage-installed.json
```

The second report checks the XDG icon theme and desktop entries, including the paths exported by NixOS. It separates verified native output hashes, mapped but unverified names, bundled artwork, absent theme entries, and absolute icon paths. Static QML literal candidates include some non-icon references. The separate `source_references` inventory also lists QML icon bindings, private role paths, C++ theme lookups, Konsole caption roles and direct artwork. The scan is heuristic; dynamic providers and native widget internals still require runtime review. Explicit Breeze inheritance is removed. A missing theme entry can still trigger implicit toolkit fallbacks or resolve via hicolor; treat project-owned controls using those fallbacks as unresolved coverage, not verified Windows artwork. Dynamic QML names, native widget SVGs, scale selection and actual pixmaps need desktop checks. Review the report before sharing. No files are uploaded.

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
mapping has 269 source entries: 61 MUN group references and 208 Segoe
Fluent Icons glyph references (910 target paths). These are source mappings, not 269 distinct
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

## Windows 11 26H2 shell assets

The private `scripts/import-shell-assets.py` importer extracts 38 SysBatt
outline/fill SVGs, original Search state PNGs (dark idle is optional), and
both Task View SVGs from the Settings PRI. It checks glyph coverage, preserves
Search image bytes, selects the highest available source scale, and records
source and output hashes. The files remain under the user's private data
directory; no Microsoft font or artwork is added to the public repository.
See [native asset import instructions](NATIVE_ASSETS.md#local-shell-artwork-import).

The source paths are identified, but the reference branch does not contain
these files or establish their exact build. A source mapping does not prove
that a glyph exists in the staged font. Remaining gaps include confirming the Hibernate glyph on the exact 26H2 build and obtaining a clean original default account portrait.

The official Fluent Person 48 Filled SVG path already exists in the Start menu fallback; it is distinct from an actual Windows default account picture. Microsoft documents the default picture location under `%ProgramData%/Microsoft/User Account Pictures` ([policy reference](https://learn.microsoft.com/windows/client-management/mdm/policy-csp-admx-cpls)). The shell importer supports that location on a clean local image.

## Owner audit: 26H2 build 26300.9974 and Plasma 6.8.3

The metadata-only [resource audit snapshot](windows11-26h2-resource-audit.json)
records the owner's extracted Professional image (offline registry build
26300.9974), seven original input hashes and 45 successful shell artwork
outputs: 38 battery SVGs, all four Search states, both Task View variants
and the default account portrait. This is evidence from the owner's local
manifest, not independent verification of the binary contents or desktop
acceptance. The older reference/runtime resource pins are unchanged.

The extraction output used a separate staging directory; to activate the
already-supported shell artwork, reimport the complete local image as the
desktop user into the default XDG destination:

```sh
python3 scripts/import-shell-assets.py /path/to/extracted/image --build 26300.9974
```

The coverage report now includes a separate private shell manifest check.
With an existing Qt metadata log, also include KCM plugin declarations:

```sh
python3 scripts/icon-coverage.py --installed --kcm-metadata /path/to/KDE-KCM-Metadata.txt
```

The reviewed log lists 98 distinct KCM modules and 84 distinct icon names.
The earlier installed-theme report verified mapped files for 41 modules,
listed three more as bundled without verified provenance, and did not list
54 modules. That last count is an audit gap, not proof that 54 icons are
absent. Nine names are shared by 23 modules. Preserve separate module
semantics (e.g. clock vs. recent files and language vs. renderer); do not
globally overwrite a shared name until every consumer has been reviewed.
KCM category icons, internal controls, and Qt's resolved icon paths still
need review. Third-party and platform identities remain distinct.

To inspect the exact Settings Fluent Icons, AXP Fluent Icons and Segoe
Fluent Icons from that build, use the existing shell inspector's private
font-review mode. It scans the live component paths under Fonts,
SystemApps and SystemResources, deduplicates by SHA-256, and generates
labeled review sheets and a glyph catalog without copying font files.
It requires Pillow and fontTools. The review images remain local/private;
the repository records source paths, hashes and approved semantic mappings,
not proprietary artwork or fonts. The recorded audit identifies four
different Settings font hashes and three AXP font hashes, so do not treat
identically named fonts as interchangeable.

```sh
python3 scripts/inspect-shell-resources.py /path/to/extracted/image/Windows /path/to/new/private/font-review --font-review
```

The review sheets and glyph names are candidates, not proof of the
role used by a particular Windows component. Confirm the relevant
PRI/XBF or live Windows UI before mapping. Settings page icons, tray
states, Hibernate, Start animation and newer context-menu resources
remain unverified. Do not add guessed glyph IDs.

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

## Taskbar and Quick Settings icon audit

The existing runtime `SegoeIcons.ttf` contains E7C2 (Move) and E744
(ResizeMouseMedium), documented by Microsoft. Both are mapped as optional
original-font roles for the taskbar's advanced Move and Resize actions.
They are original glyph candidates for the operation, not evidence of a
particular 26H2 menu resource. The runtime resource pin is unchanged.
The six other unmapped literal roles (Activities, menu editor, Keep Above,
Keep Below, exclusion from capture, and grouping) retain their text and
operations without unverified icons. The show-desktop sliver retains its
edit-mode marker rather than reusing the Move glyph.

Taskbar system menu actions, including generated media actions, request
private imported SVGs rendered as palette-tinted QIcons. KDE-specific
activity actions are text-only; application, file and media identities
remain separate. Quick Settings tiles, slider icons, network/device rows
and list entries use the existing private glyph resolver. Bluetooth and
removable hardware may use a mapped generic icon for that same device
category; unknown network states must not be assigned a fake strength.
Missing private glyphs leave artwork empty instead of resolving through
Breeze. Text and interaction geometry remain available.

Start context-menu actions, view selector/checkmark and search-section
chevrons now request private mapped Windows artwork. Missing action icons
leave a reserved empty slot; application/result identity icons are unchanged.
Notification and calendar flyout buttons use private SVG sources rather
than global icon names, including the DND banner and reply action.
Search uses only the original E721 mask when a build-specific state image
is missing; the old colored compatibility path is no longer requested.

The optional Konsole integrated chrome's owned stylesheet now uses mapped
E8BB tab-close and E76B/E76C scroll glyphs on the native QTabBar buttons.
Qt still owns the actions and geometry; the original paint behavior returns
when the custom chrome is disabled. Arbitrary user styles remain untouched.
These are reviewed original font roles, not a claim of exact Terminal or
26H2 shell artwork. Desktop acceptance is pending.

Remaining review includes profile icons in Konsole, third-party application
icons, native applet configuration pages, remaining theme lookups, dynamic
pixmaps, and the 26H2-specific shell assets listed above. The two recent-file compatibility
SVGs have had invalid editor-only attributes removed, but their provenance
is still unverified. Do not count them as Microsoft originals.

## System action review

Use Microsoft's [Segoe Fluent Icons reference](https://learn.microsoft.com/windows/apps/design/iconography/segoe-fluent-icons-font) to distinguish semantic roles. PowerButton E7E8, Restart3 F305, Lock E72E, SwitchUser E748, SignOut F3B1 and the moon-shaped QuietHours E708 used for Sleep are existing mapped roles. The original SignOut mapping was present; same-name status aliases were not. Synchronize power aliases in the status and actions directories so a stale status icon cannot win. The round clock used for Hibernate is visible in a [June 2026 Windows 11 screenshot](https://www.atera.com/blog/how-to-disable-and-enable-hibernate-in-windows-11/) and [earlier Windows 11 screenshots](https://www.guidingtech.com/how-to-enable-and-use-hibernate-mode-on-windows-11/). The [Windhawk Start Menu Buttons project](https://github.com/ramensoftware/windhawk-mods/blob/main/mods/windows-11-start-menu-buttons.wh.cpp) selects E823 for Hibernate; Microsoft names E823 Recent. The official E823 preview is a matching round clock. Map E823 as an optional original-font candidate, not as proof of the 26H2 shell resource ID. Confirm on the exact target build before claiming full coverage. Keep its real `canHibernate`/`hibernate()` action independent of artwork. Never use the E708 Sleep crescent or a KDE icon for Hibernate. Keep third-party application logos; the missing Store app artwork is not a test blocker.

Public visual references: [Windows Icon Archive](https://github.com/limehawk/windows-icon-archive) (Windows artwork remains Microsoft's; reference only), [Fluent System Icons](https://github.com/microsoft/fluentui-system-icons) (MIT-licensed separate design system), [Win11 Icon Theme](https://github.com/yeyushengfan258/Win11-icon-theme) (GPL-3.0, already credited). None establishes exact 26H2 equivalence or grants a new license to Microsoft proprietary artwork.
