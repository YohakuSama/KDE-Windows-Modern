#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Exact-path transaction for the reversible NixOS desktop test install."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import shlex
import stat
import subprocess
import sys
import tempfile

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")).absolute()
DATA = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")).absolute()
APP_STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")).absolute()
DOMAINS = ["plasma_applet_org.kde.windowsmodern." + n for n in
           ("startmenu", "systemtray", "digitalclock", "icontasks", "search", "showdesktop", "taskview")]
DOMAINS.extend(("plasma_shell_org.kde.windowsmodern.lockscreen", "plasma_containmentactions_org.kde.windowsmodern.contextmenu"))
LANGUAGES = ("zh_CN", "zh_SG", "zh_Hans")
CONFIG_NAMES = (
    "kdeglobals", "kdedefaults", "kwinrc", "kscreenlockerrc", "plasmarc",
    "plasmashellrc", "plasma-org.kde.plasma.desktop-appletsrc", "kcminputrc",
    "ksplashrc", "kglobalshortcutsrc", "Kvantum/kvantum.kvconfig",
    "kvantum.kvconfig", "gtk-3.0/settings.ini", "gtk-4.0/settings.ini",
    "xsettingsd/xsettingsd.conf", "mimeapps.list", "spectaclerc", "dolphinrc", "konsolerc", "konsolestaterc", "dolphinstaterc",
    "kcmicons", "kxkbrc", "environment.d/90-windows-modern-test.conf",
    "systemd/user/plasma-plasmashell.service.d/90-windows-modern-test.conf",
)
APP_IDS = ("org.kde.windowsmodern.startmenu", "org.kde.windowsmodern.showdesktop",
           "org.kde.windowsmodern.digitalclock", "org.kde.windowsmodern.search",
           "org.kde.windowsmodern.taskview")
KONSOLE_LAUNCHER = "windowsmodern-konsole.desktop"
DOLPHIN_LAUNCHER = "windowsmodern-dolphin.desktop"

def exists(path):
    return path.exists() or path.is_symlink()

def validate(path):
    path = Path(path).absolute()
    # Only these two app-owned state files may be modified outside data/config.
    if path in (APP_STATE / "dolphinstaterc", APP_STATE / "konsolestaterc"):
        if APP_STATE.is_symlink():
            raise RuntimeError("Refusing to write through managed state directory: " + str(APP_STATE))
        return path
    for root in (CONFIG, DATA):
        if path.is_relative_to(root) and path != root:
            # Do not descend through a Home Manager or other external symlink.
            for parent in path.parents:
                if parent == root:
                    break
                if parent.is_symlink():
                    raise RuntimeError("Refusing to write through managed directory: " + str(parent))
            return path
    raise ValueError("Target outside the desktop user's data/config: " + str(path))

def make_writable(path, *, files=False):
    # Never chmod a symlink (including Nix store links in copied packages).
    if path.is_symlink() or not path.exists():
        return
    mode = path.stat().st_mode
    if stat.S_ISDIR(mode):
        path.chmod(mode | stat.S_IRUSR | stat.S_IWUSR | stat.S_IXUSR)
        for child in path.iterdir():
            if not child.is_symlink() and (files or child.is_dir()):
                make_writable(child, files=files)
    elif files and stat.S_ISREG(mode):
        path.chmod(mode | stat.S_IRUSR | stat.S_IWUSR)


def remove(path):
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        make_writable(path)
        shutil.rmtree(path)


def copy(src, dst):
    if src.is_symlink():
        dst.symlink_to(os.readlink(src))
    elif src.is_dir():
        shutil.copytree(src, dst, symlinks=True)
    else:
        shutil.copy2(src, dst)


def replace(src, dst, *, writable=False):
    dst = validate(dst)
    dst.parent.mkdir(parents=True, exist_ok=True)
    # Reserve unique names; both renames must stay within dst.parent.
    # Cross-parent directory renames require write access to the directory
    # itself on Linux, even when both parents are writable.
    reservation = Path(tempfile.mkdtemp(prefix=".wm-test-", dir=dst.parent))
    new = reservation.with_name(reservation.name + "-new")
    previous = reservation.with_name(reservation.name + "-previous")
    committed = False
    try:
        copy(src, new)
        if writable:
            make_writable(new, files=True)
        if exists(dst):
            dst.rename(previous)
        try:
            new.rename(dst)
        except BaseException:
            if exists(previous):
                previous.rename(dst)
            raise
        committed = True
    finally:
        remove(new)
        # If rollback itself fails, leave the previous directory intact.
        if committed:
            remove(previous)
        reservation.rmdir()


def atomic_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as out:
        json.dump(data, out, indent=2, ensure_ascii=False)
        out.write("\n")
        name = out.name
    os.replace(name, path)

def plan(root, state, profile):
    native = state / "native"
    result = {}
    def packages(source, destination):
        for path in sorted(source.iterdir()):
            if path.is_dir() or path.suffix == ".colors":
                result[destination / path.name] = path
    appearance = state / "staged-appearance"
    packages(appearance / "color-schemes", DATA / "color-schemes")
    packages(appearance / "Kvantum", CONFIG / "Kvantum")
    packages(appearance / "aurorae", DATA / "aurorae/themes")
    packages(appearance / "desktoptheme", DATA / "plasma/desktoptheme")
    packages(appearance / "look-and-feel", DATA / "plasma/look-and-feel")
    for kind, dest in (("layout-templates", "plasma/layout-templates"),
                       ("windowswitcher", "kwin/tabbox"),
                       ("kwinscripts", "kwin/scripts")):
        packages(root / "plasma" / kind, DATA / dest)
    for name in APP_IDS:
        result[DATA / "plasma/plasmoids" / name] = root / "plasma/applets" / name
    packages(native / "wallpapers", DATA / "wallpapers")
    result[DATA / "windows-modern/native-assets"] = native
    result[DATA / "sounds/windows-modern"] = native / "sounds/windows-modern"
    result[DATA / "icons/windows-modern"] = state / "staged-icons"
    result[DATA / "icons/windows-modern-light"] = state / "staged-icons-light"
    result[DATA / "icons/Bibata-Modern-Ice"] = (profile / "share/icons/Bibata-Modern-Ice").resolve()
    if (state / "cursors/Windows-Modern-26H2/index.theme").is_file():
        result[DATA / "icons/Windows-Modern-26H2"] = state / "cursors/Windows-Modern-26H2"
    if (state / "shell-assets/manifest.json").is_file():
        result[DATA / "windows-modern/shell-assets"] = state / "shell-assets"
    result[DATA / "plasma/shells/org.kde.plasma.desktop"] = state / "staged-shell"
    result[DATA / "applications/windowsmodern-screenshot.desktop"] = root / "config/applications/windowsmodern-screenshot.desktop"
    for name in ("org.kde.haruna.desktop", "org.kde.kwrite.desktop", "io.missioncenter.MissionCenter.desktop"):
        desktop = profile / "share/applications" / name
        if not desktop.is_file():
            raise RuntimeError("Built application launcher missing: " + name)
        # The profile is deliberately not a global system package. Bind the
        # copied launchers to its actual binaries rather than session PATH.
        launcher = state / "staged-launchers" / name
        launcher.parent.mkdir(parents=True, exist_ok=True)
        lines = []
        for line in desktop.read_text(encoding="utf-8").splitlines():
            if line.startswith(("Exec=", "TryExec=")):
                key, command = line.split("=", 1)
                args = shlex.split(command)
                if args and not args[0].startswith("/"):
                    binary = profile / "bin" / args[0]
                    if binary.is_file():
                        token = args[0]
                        command = str(binary.resolve()) + command[len(token):]
                line = key + "=" + command
            elif line == "DBusActivatable=true":
                line = "DBusActivatable=false"
            lines.append(line)
        launcher.write_text("\n".join(lines) + "\n", encoding="utf-8")
        result[DATA / "applications" / name] = launcher
    if (profile / "wm-konsole-package").is_file():
        binary = profile / "bin/windows-modern-konsole"
        if not binary.is_file() or not os.access(binary, os.X_OK):
            raise RuntimeError("Built Windows Modern terminal launcher missing")
        launcher = state / "staged-launchers" / KONSOLE_LAUNCHER
        launcher.parent.mkdir(parents=True, exist_ok=True)
        command = str(binary.resolve())
        launcher.write_text(
            "[Desktop Entry]\n"
            "Type=Application\n"
            "Name=Windows Modern Terminal\n"
            "Name[zh_CN]=Windows Modern 终端\n"
            "Name[zh_TW]=Windows Modern 終端機\n"
            "Icon=utilities-terminal\n"
            f"Exec={command}\n"
            f"TryExec={command}\n"
            "Terminal=false\n"
            "DBusActivatable=false\n"
            "Categories=System;TerminalEmulator;\n",
            encoding="utf-8",
        )
        # The regular snapshot/restore transaction owns this exact new entry.
        result[DATA / "applications" / KONSOLE_LAUNCHER] = launcher
    if (profile / "wm-dolphin-package").is_file():
        binary = profile / "bin/windows-modern-dolphin"
        if not binary.is_file() or not os.access(binary, os.X_OK):
            raise RuntimeError("Built Windows Modern Explorer launcher missing")
        launcher = state / "staged-launchers" / DOLPHIN_LAUNCHER
        launcher.parent.mkdir(parents=True, exist_ok=True)
        command = str(binary.resolve())
        launcher.write_text(
            "[Desktop Entry]\n"
            "Type=Application\n"
            "Name=Windows Modern Explorer\n"
            "Name[zh_CN]=Windows Modern 文件资源管理器\n"
            "Name[zh_TW]=Windows Modern 檔案總管\n"
            "Icon=system-file-manager\n"
            f"Exec={command} %u\n"
            f"TryExec={command}\n"
            "Terminal=false\n"
            "DBusActivatable=false\n"
            "MimeType=inode/directory;\n"
            "Categories=Qt;KDE;System;FileTools;FileManager;\n",
            encoding="utf-8",
        )
        result[DATA / "applications" / DOLPHIN_LAUNCHER] = launcher
    return result

def snapshot(backup, targets):
    manifest_path = backup / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.is_file() else {
        "entries": {}, "absent_parents": []}
    entries = manifest["entries"]
    for path in sorted(set(targets), key=str):
        path = validate(path)
        key = str(path)
        if key in entries:
            continue
        for parent in path.parents:
            if parent in (CONFIG, DATA, APP_STATE):
                break
            if not exists(parent) and str(parent) not in manifest["absent_parents"]:
                manifest["absent_parents"].append(str(parent))
        if exists(path):
            label = str(len(entries))
            dst = backup / "files" / label
            dst.parent.mkdir(parents=True, exist_ok=True)
            if exists(dst):
                remove(dst)
            copy(path, dst)
            entries[key] = label
        else:
            entries[key] = None
    atomic_json(manifest_path, manifest)

def restore(backup):
    manifest = json.loads((backup / "manifest.json").read_text())
    for key, label in reversed(list(manifest["entries"].items())):
        path = validate(key)
        if label is None:
            remove(path)
        else:
            if not label.isdigit():
                raise ValueError("Invalid backup entry")
            replace(backup / "files" / label, path)
    for name in sorted(manifest["absent_parents"], key=lambda s: len(Path(s).parts), reverse=True):
        path = validate(name)
        if path.is_dir() and not path.is_symlink():
            try:
                path.rmdir()
            except OSError:
                pass

def make_staging(root, state):
    appearance = state / "staged-appearance"
    remove(appearance)
    subprocess.run([sys.executable, str(root / "scripts/theme/appearance-packages.py"),
                    str(appearance)], check=True)
    native = state / "native"
    icons = state / "staged-icons"
    remove(icons)
    shutil.copytree(root / "icons/windows-modern", icons, symlinks=True)
    make_writable(icons, files=True)
    for asset in (native / "icons").rglob("*.svg"):
        relative = asset.relative_to(native / "icons")
        dst = icons / relative
        for suffix in (".png", ".svgz", ".xpm", ".svg"):
            remove(dst.with_suffix(suffix))
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(asset, dst)
    light_icons = state / "staged-icons-light"
    remove(light_icons)
    subprocess.run([sys.executable, str(root / "scripts/store-artwork.py"), "apply",
                    str(state / "store-artwork"), str(icons), str(light_icons)], check=True)

    shell = state / "staged-shell"
    remove(shell)
    shell.mkdir()
    # Use the running system profile's actual stock shell as the base.
    candidates = [Path("/run/current-system/sw/share")] + [
        Path(p) for p in os.environ.get("XDG_DATA_DIRS", "/usr/share").split(":") if p
    ]
    stock = next((p / "plasma/shells/org.kde.plasma.desktop" for p in candidates
                  if (p / "plasma/shells/org.kde.plasma.desktop/metadata.json").is_file()
                  and (p / "plasma/shells/org.kde.plasma.desktop/contents/lockscreen").is_dir()), None)
    if stock is None:
        raise RuntimeError("Active Plasma shell package not found")
    # Resolve the profile symlink so an updated system profile cannot change
    # the lockscreen package while a test is running.
    stock = stock.resolve()
    shutil.copy2(stock / "metadata.json", shell / "metadata.json")
    (shell / "contents").mkdir()
    for src in (stock / "contents").iterdir():
        if src.name == "lockscreen":
            continue
        dst = shell / "contents" / src.name
        if src.name == "defaults":
            # A layout reset discards ActionPlugins entries. Make the custom
            # desktop menu the shell's default as well as the active binding.
            subprocess.run([sys.executable, str(root / "scripts/desktop-contextmenu.py"),
                            "--patch-defaults", str(src), str(dst)], check=True)
        elif src.name == "logout":
            # KPackage refuses symlinks outside the logout package.
            shutil.copytree(src, dst, symlinks=False)
            make_writable(dst, files=True)
        else:
            dst.symlink_to(src.resolve())
    lock = shell / "contents/lockscreen"
    shutil.copytree(root / "plasma/shells/org.kde.windowsmodern.lockscreen/contents/lockscreen", lock)
    make_writable(lock, files=True)
    # Keep the shipped sign-in portrait, not the unrelated account-control icon.

COMPILED_IDS = ("org.kde.windowsmodern.systemtray", "org.kde.windowsmodern.icontasks")


def compiled_overrides():
    # Local KPackage directories can shadow the new embedded QML in the
    # compiled applets. Back up and remove these exact two paths only.
    return [DATA / "plasma/plasmoids" / name for name in COMPILED_IDS]


def retired_global_themes():
    # This exact legacy package is no longer installed separately. Keep its
    # original contents in the existing NixOS backup/rollback transaction.
    return [DATA / "plasma/look-and-feel/org.kde.windowsmodern.light"]


def all_targets(mapping):
    return list(mapping) + compiled_overrides() + retired_global_themes() + [CONFIG / name for name in CONFIG_NAMES] + [
        DATA / "kxmlgui5/dolphin/dolphinui.rc",
        DATA / "kxmlgui5/konsole/konsoleui.rc",
        DATA / "kxmlgui5/konsole/sessionui.rc",
        APP_STATE / "konsolestaterc",
        APP_STATE / "dolphinstaterc",
        DATA / "konsole/WindowsModern.profile",
        DATA / "konsole/WindowsModern-tabs.css",
        DATA / "icons/Windows-Modern-26H2",
        DATA / "windows-modern/shell-assets",
        DATA / "windows-modern/backup/app-appearance.json",
        DATA / "windows-modern/transparency-off",
    ] + [DATA / "locale" / lang / "LC_MESSAGES" / (domain + ".mo")
         for lang in LANGUAGES for domain in DOMAINS]

def package_digest(path):
    if not path.is_dir() or path.is_symlink():
        raise RuntimeError("Expected real applet directory: " + str(path))
    h = hashlib.sha256()
    for item in sorted(path.rglob("*")):
        relative = item.relative_to(path).as_posix().encode()
        if item.is_symlink():
            h.update(b"L\0" + relative + b"\0" + os.fsencode(os.readlink(item)) + b"\0")
        elif item.is_file():
            h.update(b"F\0" + relative + b"\0")
            h.update(hashlib.sha256(item.read_bytes()).digest())
        elif item.is_dir():
            h.update(b"D\0" + relative + b"\0")
    return h.hexdigest()


def same_payload(src, dst):
    if src.is_symlink():
        return dst.is_symlink() and os.readlink(src) == os.readlink(dst)
    if dst.is_symlink():
        return False
    if src.is_dir():
        return dst.is_dir() and package_digest(src) == package_digest(dst)
    return (src.is_file() and dst.is_file()
            and hashlib.sha256(src.read_bytes()).digest() == hashlib.sha256(dst.read_bytes()).digest())


def verify_sources(root):
    for name in APP_IDS:
        expected = package_digest(root / "plasma/applets" / name)
        installed = package_digest(DATA / "plasma/plasmoids" / name)
        if expected != installed:
            raise RuntimeError("Installed applet differs from test source: " + name)
        print(f"Verified QML {name}: {installed}")
    for path in compiled_overrides():
        if exists(path):
            raise RuntimeError("Local package shadows compiled applet: " + str(path))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["install", "restore", "snapshot-current", "restore-upgrade", "verify-sources", "prepare-transparency"])
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--profile", type=Path, required=True)
    parser.add_argument("--upgrade-backup", type=Path)
    parser.add_argument("--before-materials", action="store_true",
                        help="verify complete staged desktop themes before local material overrides")
    args = parser.parse_args()
    if args.action == "verify-sources":
        verify_sources(args.root)
        appearance = args.state / "staged-appearance"
        # Desktop and Aurorae SVGs may be overridden by local material
        # settings. Verify their full staged contents before that step.
        destinations = {"look-and-feel": DATA / "plasma/look-and-feel"}
        if args.before_materials:
            destinations.update({"desktoptheme": DATA / "plasma/desktoptheme",
                                 "aurorae": DATA / "aurorae/themes"})
        for kind, destination in destinations.items():
            for source in (appearance / kind).iterdir():
                if not same_payload(source, destination / source.name):
                    raise RuntimeError("Installed appearance package differs from staged source: " + source.name)
        if any(exists(path) for path in retired_global_themes()):
            raise RuntimeError("Legacy global theme was not retired")
        if (args.profile / "wm-konsole-package").is_file():
            if not same_payload(args.state / "staged-launchers" / KONSOLE_LAUNCHER,
                                DATA / "applications" / KONSOLE_LAUNCHER):
                raise RuntimeError("Installed Windows Modern terminal launcher differs from test runtime")
            print("Verified Windows Modern Terminal launcher")
        if (args.profile / "wm-dolphin-package").is_file():
            if not same_payload(args.state / "staged-launchers" / DOLPHIN_LAUNCHER,
                                DATA / "applications" / DOLPHIN_LAUNCHER):
                raise RuntimeError("Installed Windows Modern Explorer launcher differs from test runtime")
            print("Verified Windows Modern Explorer launcher")
        return
    if args.action == "restore-upgrade":
        if args.upgrade_backup is None:
            raise ValueError("Missing upgrade backup")
        restore(args.upgrade_backup)
        return
    backup = args.state / "original"
    if args.action == "prepare-transparency":
        if not (backup / "manifest.json").is_file():
            raise RuntimeError("No original NixOS desktop backup")
        snapshot(backup, [DATA / "windows-modern/transparency-off"])
        return
    if args.action == "restore":
        restore(backup)
        return
    if args.action == "snapshot-current":
        manifest = json.loads((backup / "manifest.json").read_text())
        snapshot(args.state / "before-uninstall",
                 [Path(key) for key in manifest["entries"]
                  if Path(key).is_relative_to(CONFIG) or key.endswith(("/dolphinui.rc", "/konsoleui.rc",
                      "/WindowsModern.profile", "/WindowsModern-tabs.css", "/app-appearance.json",
                       "/windows-modern/transparency-off"))])
        return
    make_staging(args.root, args.state)
    mapping = plan(args.root, args.state, args.profile)
    for dst, src in mapping.items():
        validate(dst)
        if not exists(src):
            raise RuntimeError("Missing installation input: " + str(src))
    targets = all_targets(mapping)
    # Back up the currently active version before overwriting anything.
    # Preserve the original pre-test baseline independently for uninstall.
    if args.upgrade_backup is not None:
        previous = json.loads((backup / "manifest.json").read_text())
        snapshot(args.upgrade_backup, targets + [Path(key) for key in previous["entries"]])
    snapshot(backup, targets)
    for path in compiled_overrides() + retired_global_themes():
        remove(validate(path))
    # Make writable local copies of file-level configuration symlinks. The
    # original link is restored on uninstall; no Nix configuration is edited.
    for name in CONFIG_NAMES:
        path = CONFIG / name
        if path.is_symlink() and path.exists():
            replace(path.resolve(), path, writable=True)
    changed = unchanged = 0
    for dst, src in mapping.items():
        if args.upgrade_backup is not None and same_payload(src, dst):
            unchanged += 1
            continue
        replace(src, dst, writable=True)
        changed += 1
    print(f"Payload update: {changed} replaced, {unchanged} unchanged")
    # Both lock/login packages already contain their appropriate portrait assets.
    # Install the exact translated domains from the repository.
    subprocess.run([str(args.profile / "bin/python3"), str(args.root / "scripts/install-translations.py"),
                    "--locale-dir", str(DATA / "locale")], check=True)

if __name__ == "__main__":
    main()
