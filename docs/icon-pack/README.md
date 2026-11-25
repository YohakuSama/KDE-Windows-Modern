# Icon maintenance

The installed fallback icon theme lives in `icons/windows-modern/`. Its
source credits are in [ATTRIBUTION.md](../../ATTRIBUTION.md); original
Windows artwork is overlaid through the [native resource importer](../NATIVE_ASSETS.md).

- Use the [freedesktop icon naming specification](https://specifications.freedesktop.org/icon-naming-spec/latest/)
  for semantic names and context directories.
- Preserve the correct application brand, file type, device and action
  meanings. Keep distinct unavailable, disabled, warning and RTL states.
- Review battery, network, volume, Bluetooth and other state families as
  groups. Keep their optical dimensions consistent without stretching
  artwork or making weak states artificially larger.
- Verify dark/light palette behavior, symbolic SVG recoloring and the
  actual selected icon at supported DPI scales. Do not claim that an
  inherited fallback is original Windows artwork.
- Use the current mapping, the complete reference library and
  `scripts/icon-coverage.py` to inspect missing or fallback roles. Add
  only reviewed resources to the compact runtime branch.

The historical multi-pack selection pipeline, generated inventory and
comparison reports are available in Git history. They do not describe the
current native resource workflow.
