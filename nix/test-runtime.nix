# SPDX-License-Identifier: GPL-3.0-or-later
# Build against the desktop's own nixpkgs revision, not a global system overlay.
{ nixpkgsPath, plasmaVersion, buildToken, konsoleVersion ? "", dolphinVersion ? "" }:
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
  makeApplet = { name, src, id, rename ? false, namespace ? "applets" }:
    let
      source = lib.cleanSourceWith {
        inherit src;
        filter = path: type:
          let n = baseNameOf path; in
          !(n == "build" || lib.hasPrefix "build-" n || n == "wm-build" || n == ".git"
            || builtins.elem n [ "dev.sh" "verify.sh" "Messages.sh" "BUILD.md" "tests" ]);
      };
      # Nix itself hashes the filtered source path. The identity also changes
      # if the build recipe, pinned package set or ABI changes. Unchanged
      # applets get identical derivations across upgrades.
      identity = builtins.hashString "sha256" (builtins.toJSON {
        source = toString source;
        inherit nixpkgsPath plasmaVersion id namespace;
        recipe = builtins.hashFile "sha256" ./test-runtime.nix;
      });
    in pkgs.stdenv.mkDerivation {
    pname = "windows-modern-test-" + name;
    version = plasmaVersion + "-" + builtins.substring 0 16 identity;
    wmBuildToken = identity;
    src = source;
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
    '' + ''
      # A distinct token in the actual ELF, not merely the output symlink.
      # The token changes only when this applet's build inputs change.
      # A changed plugin cannot pass verification with an older ELF.
      cat > wm_build_identity.cpp <<EOF
      extern "C" __attribute__((visibility("default"))) const char *windowsmodern_nixos_build_token() {
          return "$wmBuildToken";
      }
      EOF
      printf '\n%s\n' 'target_sources(${id} PRIVATE wm_build_identity.cpp)' >> CMakeLists.txt
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
      install -Dm755 wm-build/lib/plasma/${namespace}/${id}.so "$out/${prefix}/plasma/${namespace}/${id}.so"
      printf '%s\n' "$src" > "$out/wm-source-${name}"
      printf '%s\n' "$wmBuildToken" > "$out/wm-token-${name}"
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
  contextmenu = makeApplet {
    name = "contextmenu";
    src = ../plasma/containmentactions/org.kde.windowsmodern.contextmenu;
    id = "org.kde.windowsmodern.contextmenu";
    namespace = "containmentactions";
  };
  python = pkgs.python3.withPackages (p: [ p.pillow p.fonttools p.pygobject3 ]);
  stockKvantum = pkgs.qt6Packages.qtstyleplugin-kvantum;
  # Same Qt ABI and plugin key. Apply only to the reviewed upstream tag.
  kvantumLiveReload = stockKvantum.version == "1.1.9";
  kvantum = if kvantumLiveReload then stockKvantum.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../app-decorations/kvantum/live-reload-1.1.9.patch ];
  }) else stockKvantum;
  # Only the explicit full test includes Konsole. Never put its private
  # libraries or the stock command name in the shared Plasma runtime.
  konsole = import ./konsole-chrome.nix { inherit nixpkgsPath konsoleVersion; };
  konsoleLauncher = pkgs.writeShellScriptBin "windows-modern-konsole" ''
    export WM_KONSOLE_CHROME=1
    exec ${konsole}/bin/konsole --separate --hide-menubar --hide-toolbars --show-tabbar "$@"
  '';
  dolphin = import ./dolphin-chrome.nix { inherit nixpkgsPath dolphinVersion; };
  dolphinLauncher = pkgs.writeShellScriptBin "windows-modern-dolphin" ''
    exec ${dolphin}/bin/dolphin --new-window "$@"
  '';
in
assert lib.assertMsg (builtins.match "[a-zA-Z0-9.-]+" buildToken != null) "Invalid test build token";
assert lib.assertMsg (k.plasma-workspace.version == plasmaVersion)
  "Nixpkgs Plasma version does not match the running desktop; refusing an ABI-mismatched test build.";
pkgs.symlinkJoin {
  name = "windows-modern-nixos-test-runtime-" + plasmaVersion + "-" + buildToken;
  paths = [
    tasks tray contextmenu kvantum pkgs.bibata-cursors
    python pkgs.git pkgs.curl pkgs.gnutar pkgs.zip pkgs.unzip pkgs.dbus
    pkgs.xdg-utils pkgs.haruna k.kate pkgs.mission-center
  ] ++ lib.optional (konsoleVersion != "") konsoleLauncher
    ++ lib.optional (dolphinVersion != "") dolphinLauncher;
  postBuild = ''
    printf '%s\n' '${buildToken}' > "$out/wm-build-token"
    printf '%s\n' '${prefix}' > "$out/wm-qt-plugin-prefix"
    printf '%s\n' '${if kvantumLiveReload then "live-reload:" + stockKvantum.version else "stock:" + stockKvantum.version}' > "$out/wm-kvantum-reload"
    printf '%s\n' '${lib.getLib pkgs.glib}/lib/girepository-1.0:${pkgs.gobject-introspection}/lib/girepository-1.0' > "$out/wm-gi-typelib-path"
  '' + lib.optionalString (konsoleVersion != "") ''
    printf '%s\n' '${konsole}' > "$out/wm-konsole-package"
  '' + lib.optionalString (dolphinVersion != "") ''
    printf '%s\n' '${dolphin}' > "$out/wm-dolphin-package"
  '';
}
