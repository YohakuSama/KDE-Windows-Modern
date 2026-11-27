# NixOS native expressions

The only editable Nix expressions are in [nix/](../../nix/). Their path-relative inputs and recipe identity are part of the existing incremental build contract. The source-side runtime and recovery tools are in tools/. Native script entry paths are source-only aliases; installation archives carry real files.
