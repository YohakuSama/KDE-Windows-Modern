#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Install project-owned KDE message domains. No gettext tools required."""
import argparse
import gettext
import io
import json
import os
from pathlib import Path
import struct
import tempfile

ROOT = Path(__file__).resolve().parents[1]
DOMAINS = tuple("plasma_applet_org.kde.windowsmodern." + name for name in (
    "startmenu", "systemtray", "digitalclock", "icontasks", "search", "showdesktop", "taskview"
)) + ("plasma_shell_org.kde.windowsmodern.lockscreen", "plasma_containmentactions_org.kde.windowsmodern.contextmenu")

def compile_mo(messages):
    catalog = dict(messages)
    catalog[""] = ("Project-Id-Version: KDE-Windows-Modern\n"
                   "Language: zh_CN\n"
                   "Content-Type: text/plain; charset=UTF-8\n"
                   "Plural-Forms: nplurals=1; plural=0;\n")
    pairs = sorted((k.encode("utf-8"), v.encode("utf-8")) for k, v in catalog.items())
    count = len(pairs)
    start = 28 + 16 * count
    originals = bytearray()
    translations = bytearray()
    offsets = []
    for key, _ in pairs:
        offsets.append((len(key), start + len(originals)))
        originals.extend(key + b"\0")
    values = []
    for _, value in pairs:
        values.append((len(value), start + len(originals) + len(translations)))
        translations.extend(value + b"\0")
    result = (struct.pack("<7I", 0x950412de, 0, count, 28, 28 + 8 * count, 0, 0)
              + b"".join(struct.pack("<2I", *pair) for pair in offsets + values)
              + originals + translations)
    # Parse using the real stdlib gettext reader before replacing any files.
    tr = gettext.GNUTranslations(io.BytesIO(result))
    for key, value in messages.items():
        context, sep, msg = key.partition("\x04")
        if not sep:
            msg, context = context, None
        singular, sep, plural = msg.partition("\0")
        if sep:
            actual = tr.npgettext(context, singular, plural, 2) if context else tr.ngettext(singular, plural, 2)
        else:
            actual = tr.pgettext(context, msg) if context else tr.gettext(msg)
        if actual != value:
            raise ValueError("Invalid compiled translation: " + repr(key))
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--locale-dir", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    messages = json.loads((ROOT / "translations/zh_CN.json").read_text(encoding="utf-8"))
    content = compile_mo(messages)
    if args.check:
        print(f"Verified {len(messages)} Simplified Chinese messages")
        return
    destination = args.locale_dir or (Path("/usr/share/locale") if os.geteuid() == 0 else
        Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "locale")
    for language in ("zh_CN", "zh_SG", "zh_Hans"):
        directory = destination / language / "LC_MESSAGES"
        directory.mkdir(parents=True, exist_ok=True)
        for domain in DOMAINS:
            path = directory / (domain + ".mo")
            if path.is_file() and not path.is_symlink() and path.read_bytes() == content:
                continue
            with tempfile.NamedTemporaryFile(dir=directory, delete=False) as tmp:
                tmp.write(content)
            os.chmod(tmp.name, 0o644)
            os.replace(tmp.name, path)
    print(f"Installed {len(messages)} Simplified Chinese messages for Windows Modern")

if __name__ == "__main__":
    main()
