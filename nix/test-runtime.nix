# SPDX-License-Identifier: GPL-3.0-or-later
# Build against the desktop's own nixpkgs revision, not a global system overlay.
{ nixpkgsPath, plasmaVersion }:
let
  pkgs = import (builtins.toPath nixpkgsPath) { };
  k = pkgs.kdePackages;
  lib = pkgs.lib;
  prefix = k.qtbase.qtPluginPrefix;
  deps = with k; [
    qtbase qtdeclarative kconfig ki18n kio kservice kwindowsystem kxmlgui
    kglobalaccel knotifications kpackage kiconthemes kjobwidgets kitemmodels
    libplasma plasma-workspace plasma-activities plasma-activities-stats libksysguard
  ];
  makeApplet = { name, src, id, rename ? false }: pkgs.stdenv.mkDerivation {
    pname = "windows-modern-test-" + name;
    version = plasmaVersion;
    src = lib.cleanSourceWith {
      inherit src;
      filter = path: type:
        let n = baseNameOf path; in
        !(n == "build" || lib.hasPrefix "build-" n || n == ".git");
    };
    nativeBuildInputs = [ pkgs.cmake pkgs.ninja k.extra-cmake-modules k.qttools pkgs.python3 ];
    buildInputs = deps;
    dontUseCmakeConfigure = true;
    dontUseNinjaBuild = true;
    dontUseNinjaInstall = true;
    dontWrapQtApps = true;
    postPatch = lib.optionalString rename ''
      # The distribution's stock icontasks KPackage is immutable on NixOS.
      # Use our own ID in the CMake target, QRC, imports and plugin metadata.
      python3 - <<'PY'
      from pathlib import Path
      old = "org.kde.plasma.icontasks"
      new = "org.kde.windowsmodern.icontasks"
      for path in Path(".").rglob("*"):
          if path.is_file() and path.suffix in (".qml", ".js", ".txt", ".cpp", ".h", ".json", ".xml", ".cmake"):
              text = path.read_text(encoding="utf-8")
              if old in text:
                  path.write_text(text.replace(old, new), encoding="utf-8")
      PY
    '';
    configurePhase = ''
      runHook preConfigure
      cmake -S . -B wm-build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$out"
      runHook postConfigure
    '';
    buildPhase = ''
      runHook preBuild
      cmake --build wm-build --parallel "$NIX_BUILD_CORES"
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 wm-build/lib/plasma/applets/${id}.so "$out/${prefix}/plasma/applets/${id}.so"
      runHook postInstall
    '';
  };
  tasks = makeApplet {
    name = "icontasks";
    src = ../plasma/applets/org.kde.windowsmodern.icontasks;
    id = "org.kde.windowsmodern.icontasks";
    rename = true;
  };
  tray = makeApplet {
    name = "systemtray";
    src = ../plasma/applets/org.kde.windowsmodern.systemtray;
    id = "org.kde.windowsmodern.systemtray";
  };
  python = pkgs.python3.withPackages (p: [ p.pillow p.fonttools ]);
in
assert lib.assertMsg (k.plasma-workspace.version == plasmaVersion)
  "Nixpkgs Plasma version does not match the running desktop; refusing an ABI-mismatched test build.";
pkgs.symlinkJoin {
  name = "windows-modern-nixos-test-runtime-" + plasmaVersion;
  paths = [
    tasks tray pkgs.qt6Packages.qtstyleplugin-kvantum pkgs.bibata-cursors
    python pkgs.git pkgs.curl pkgs.gnutar pkgs.zip pkgs.unzip pkgs.dbus
    pkgs.xdg-utils pkgs.haruna k.kate pkgs.mission-center
  ];
  postBuild = ''
    printf '%s\n' '${prefix}' > "$out/wm-qt-plugin-prefix"
  '';
}
