# Konsole native plugin

The terminal module owns the feature behavior, appearance and acceptance
criteria. Its version-specific Qt adapter is maintained in
[platform/qt/konsole](../../../platform/qt/konsole/) because it targets
Konsole's private plugin ABI.

The source map materializes that adapter at
`app-decorations/konsole` for the existing Nix build interface and
independent compiler syntax check. Those consumers prepare the generated
output from the canonical platform source. Do not edit the generated
directory or create a second implementation.
