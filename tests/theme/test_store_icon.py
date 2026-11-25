# SPDX-License-Identifier: GPL-3.0-or-later
from pathlib import Path
import hashlib
import importlib.util
import json
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("store_artwork", ROOT / "scripts/store-artwork.py")
store = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(store)


class StoreIconTests(unittest.TestCase):
    def test_reviewed_source_and_mode(self):
        self.assertEqual(store.SOURCES["light"][0], "Microsoft_Store_logo_dark.svg")
        self.assertEqual(store.SOURCES["dark"][0], "Microsoft_Store_logo_light.svg")
        self.assertIn("Theme=windows-modern-light\n", (ROOT / "plasma/look-and-feel/org.kde.windowsmodern.light/contents/defaults").read_text())
        self.assertIn("Theme=windows-modern\n", (ROOT / "plasma/look-and-feel/org.kde.windowsmodern.dark/contents/defaults").read_text())

    def test_unchanged_bytes_for_every_alias_and_mode(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            assets = root / "assets"
            assets.mkdir()
            dark = root / "windows-modern"
            dark.mkdir()
            (dark / "index.theme").write_text("[Icon Theme]\nName=Windows Modern\n")
            light = root / "windows-modern-light"
            manifest = {}
            originals = {}
            # Test fixtures exercise the importer, not replacement artwork.
            sources = {mode: (name, minute, None) for mode, (name, minute, _) in store.SOURCES.items()}
            for mode, (name, minute, _) in sources.items():
                data = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 2 2">'
                        '<rect width="2" height="2" fill="' + ("blue" if mode == "light" else "white") + '"/></svg>').encode()
                originals[mode] = data
                (assets / name).write_bytes(data)
                manifest[mode] = {"file": name, "timestamp": minute + ":00Z",
                                  "sha1": hashlib.sha1(data).hexdigest(), "size": len(data)}
            (assets / "manifest.json").write_text(json.dumps(manifest))
            with patch.object(store, "SOURCES", sources):
                store.apply(assets, dark, light)
                self.assertIn("Inherits=windows-modern", (light / "index.theme").read_text())
                for mode, theme in (("dark", dark), ("light", light)):
                    for alias in store.ALIASES:
                        self.assertEqual((theme / "apps" / (alias + ".svg")).read_bytes(), originals[mode])
                (assets / sources["light"][0]).write_bytes(b"wrong")
                with self.assertRaises(ValueError):
                    store.verify(assets)

    def test_no_active_or_remote_svg_content(self):
        for node in ('<script/>', '<image href="https://example.com/p.png"/>',
                     '<path fill="url(https://example.com/paint)"/>'):
            with self.assertRaises(ValueError):
                store.check_svg(('<svg xmlns="http://www.w3.org/2000/svg">' + node + '</svg>').encode())

    def test_offline_package_installer_contract(self):
        script = (ROOT / "scripts/package.sh").read_text()
        self.assertIn("bundled-store-artwork", script)
        for installer in ("install-nixos.sh", "scripts/install-icons.sh"):
            self.assertIn("store-artwork.py", (ROOT / installer).read_text())


if __name__ == "__main__":
    unittest.main()
