# SPDX-License-Identifier: GPL-3.0-or-later
# Explicit, isolated prototype. Do not add this to the default desktop runtime.
{ nixpkgsPath, konsoleVersion }:
let
  pkgs = import (builtins.toPath nixpkgsPath) { };
  k = pkgs.kdePackages;
  lib = pkgs.lib;
  konsole = k.konsole;
in
assert lib.assertMsg (konsole.version == konsoleVersion)
  "The pinned nixpkgs Konsole version must match the installed version.";
assert lib.assertMsg (lib.hasPrefix "26.08." konsoleVersion)
  "The experimental plugin has only been source-reviewed for Konsole 26.08.";
konsole.overrideAttrs (old: {
  pname = "windows-modern-konsole";
  buildInputs = (old.buildInputs or [ ]) ++ [ k.qtsvg k.kwindowsystem ];
  postPatch = (old.postPatch or "") + ''
    cp -R -- ${../app-decorations/konsole} src/plugins/WindowsModernChrome
    printf '\n%s\n' 'add_subdirectory(WindowsModernChrome)' >> src/plugins/CMakeLists.txt
  '';
  cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DBUILD_TESTING=OFF" ];
  doCheck = false;
  doInstallCheck = false;
})
