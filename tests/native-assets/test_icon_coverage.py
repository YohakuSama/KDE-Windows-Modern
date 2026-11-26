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

    def test_private_roles_and_dynamic_sources(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "plasma").mkdir()
            (root / "app-decorations").mkdir()
            (root / "plasma/example.qml").write_text(
                'icon: menu.backend.nativeMenuIcon("actions/known")\n'
                'roleName: "missing"\n'
                'nativeIconName: "known"\n'
                'source: "local.svg"\n'
                'source: model.icon\n'
                'source: "windows-modern/shell-assets/task-view/dark.svg"\n'
            )
            (root / "app-decorations/example.cpp").write_text(
                'QIcon::fromTheme(QStringLiteral("old"));\n'
                'nativeMenuIcon(QStringLiteral("actions/absent"));\n'
            )
            (root / "app-decorations/windowsmodernchrome.cpp").write_text(
                'glyphPath(QStringLiteral("known"));\n'
            )
            result = audit.source_candidates(root, {"known": [("e710", "actions/known.svg")]}, {})
            self.assertEqual(result["private_role_mapped"][0]["value"], "actions/known")
            self.assertEqual(result["private_role_unmapped"][0]["value"], "actions/absent")
            self.assertEqual(result["private_name_unmapped"][0]["value"], "missing")
            self.assertEqual(result["private_name_mapped"][0]["value"], "known")
            self.assertTrue(any(row["file"] == "app-decorations/windowsmodernchrome.cpp"
                                and row["value"] == "actions/known"
                                for row in result["private_role_mapped"]))
            self.assertEqual(result["direct_artwork"][0]["value"], "local.svg")
            self.assertEqual(result["private_shell_asset"][0]["value"],
                             "windows-modern/shell-assets/task-view/dark.svg")
            self.assertEqual(result["cpp_theme_name"][0]["value"], "old")
            self.assertTrue(any(row["value"] == "model.icon" for row in result["dynamic_qml_candidate"]))

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
