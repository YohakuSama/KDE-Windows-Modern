# Release and packaging guide

## Private owner test package

Use `bash scripts/package.sh --owner` from a clean current checkout with
the pinned login-manager submodule initialized. This is the complete
private theme ZIP with the mapped original Windows resource inputs.
The resource branch and archive contents are checked before
`dist/.owner-manifest` is written. Do not publish this package through
public Actions, GitHub releases or the KDE Store.

## Public integration artifacts

The existing CI workflow builds and checks native plugins for its target
Fedora ABIs, then calls `scripts/package.sh --integration`. This provides
a commit-specific integration ZIP and checksums, not the complete private
owner resource package. NixOS builds its own ABI-matched plugins.

## Public GitHub releases

A public release requires a clean main checkout, consistent component
metadata versions, the existing repository checks, actual desktop
acceptance and reviewed release notes. A CI pass alone does not establish
visual parity.


The approved `v*` tag pushed by `scripts/release.sh` is the automatic
release CI trigger. It runs the repository checks and Fedora plugin build,
then attaches the plugin archives to the release. Normal branch pushes and
pull-request events do not start CI. For a user-authorized final run, use
Actions > CI > Run workflow after manual desktop acceptance and confirm the
acceptance input.

```bash
bash scripts/release.sh --dry-run
```

This checks and packages the public artifacts without creating a tag or
uploading files. For an explicitly approved public release, authenticate
with the GitHub CLI, verify that the configured origin push destination is
`YohakuSama/KDE-Windows-Modern`, and run `bash scripts/release.sh` with the
approved metadata version. The script must not rewrite remotes or create
repositories. It uploads only files listed in `dist/.manifest`, never the
private owner manifest.

Do not publish original Windows binaries, fonts, or the owner resource
payload. Preserve source licenses and attribution.

## KDE Store

The inherited `scripts/store/` automation and product IDs are upstream
maintainer tooling, not this fork's verified publishing account. Do not
run those publication commands against another maintainer's products.
If this fork needs its own listing, first configure its own authenticated
account, product IDs and source URLs and review all publication permissions.

Review current live desktop captures before regenerating global theme
previews. Local captures go to the ignored `docs/screenshots/` directory.
