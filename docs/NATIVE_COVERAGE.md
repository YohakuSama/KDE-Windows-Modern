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
