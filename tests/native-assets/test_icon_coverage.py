# SPDX-License-Identifier: GPL-3.0-or-later
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "scripts/icon-coverage.py"
SPEC = importlib.util.spec_from_file_location("icon_coverage", SCRIPT)
audit = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(audit)


class CoverageTests(unittest.TestCase):
    def test_classification_and_broken_link(self):
        with tempfile.TemporaryDirectory() as tmp:
            theme = Path(tmp)
            (theme / "index.theme").write_text("[Icon Theme]\nDirectories=apps,status\n")
            (theme / "apps").mkdir()
            (theme / "status").mkdir()
            native = b"<svg/>"
            (theme / "apps/store.svg").write_bytes(native)
            (theme / "apps/other.svg").write_bytes(b"<svg/>")
            (theme / "apps/broken.svg").symlink_to("absent.svg")
            names, broken, dirs = audit.theme_inventory(theme)
            self.assertEqual(broken, ["apps/broken.svg"])
            self.assertEqual(dirs, [])
            mapping = {"icons": {"i:1": "apps/store status/missing"}}
            manifest = {"outputs": {"icons/apps/store.svg": {
                "sha256": hashlib.sha256(native).hexdigest()
            }, "icons/status/missing.svg": {"sha256": "bad"}}}
            expected, actual, mismatched = audit.native_inventory(mapping, manifest, theme, names)
            self.assertEqual(mismatched, ["status/missing.svg"])
            self.assertEqual(audit.classify("store", names, expected, actual), "native_hash_verified")
            self.assertEqual(audit.classify("missing", names, expected, actual), "native_mapping_not_verified")
            self.assertEqual(audit.classify("other", names, expected, actual), "bundled_not_native_verified")
            self.assertEqual(audit.classify("unknown", names, expected, actual), "not_in_theme")
            self.assertEqual(audit.classify("/tmp/icon.png", names, expected, actual), "path_bypasses_theme")

    def test_desktop_precedence(self):
        with tempfile.TemporaryDirectory() as tmp:
            paths = [Path(tmp) / name for name in ("first", "second")]
            for base in paths:
                (base / "applications").mkdir(parents=True)
            (paths[0] / "applications/app.desktop").write_text(
                "[Desktop Entry]\nType=Application\nHidden=true\nIcon=hidden\n")
            (paths[1] / "applications/app.desktop").write_text(
                "[Desktop Entry]\nType=Application\nIcon=shadowed\n")
            (paths[1] / "applications/other.desktop").write_text(
                "[Desktop Entry]\nType=Application\nIcon=discover\n")
            self.assertEqual(dict(audit.desktop_candidates(paths)), {"discover": ["other.desktop"]})
