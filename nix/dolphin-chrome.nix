# SPDX-License-Identifier: GPL-3.0-or-later
# Explicit isolated Dolphin trial; never replace the system package.
{ nixpkgsPath, dolphinVersion }:
let
  pkgs = import (builtins.toPath nixpkgsPath) { };
  lib = pkgs.lib;
  dolphin = pkgs.kdePackages.dolphin;
  patchDirectory = if builtins.pathExists ../core/source-map.json
    then ../modules/explorer/patches
    else ../app-decorations/dolphin;
in
assert lib.assertMsg (dolphin.version == dolphinVersion)
  "The pinned nixpkgs Dolphin version must match the installed version.";
assert lib.assertMsg (lib.hasPrefix "26.08." dolphinVersion)
  "The status-bar backport targets Dolphin 26.08.x; review newer source before reuse.";
dolphin.overrideAttrs (old: {
  pname = "windows-modern-dolphin";
  patches = (old.patches or [ ]) ++ [
    (patchDirectory + "/statusbar-margins.patch")
    (patchDirectory + "/tab-controls.patch")
    (patchDirectory + "/explorer-chrome.patch")
    (patchDirectory + "/compact-contextmenu.patch")
  ];
  cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DBUILD_TESTING=OFF" ];
  doCheck = false;
  doInstallCheck = false;
})
