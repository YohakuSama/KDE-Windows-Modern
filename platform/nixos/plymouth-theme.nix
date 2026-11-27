# Optional package, intentionally separate from user-level install-nixos.sh.
{ stdenvNoCC, python3 }:
stdenvNoCC.mkDerivation {
  pname = "windows-modern-plymouth";
  version = "1.0";
  src = ../.;
  nativeBuildInputs = [ (python3.withPackages (ps: [ ps.pillow ])) ];
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    python3 scripts/theme/boot-frames.py "$out/share/plymouth/themes/windows-modern"
    runHook postInstall
  '';
}
