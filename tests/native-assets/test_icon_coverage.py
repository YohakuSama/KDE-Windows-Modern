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
            expected, actual, mismatched, unindexed = audit.native_inventory(mapping, manifest, theme, names)
            self.assertEqual(mismatched, ["status/missing.svg"])
            self.assertEqual(unindexed, [])
            self.assertEqual(audit.classify("store", names, expected, actual), "native_hash_verified")
            self.assertEqual(audit.classify("missing", names, expected, actual), "native_mapping_not_verified")
            self.assertEqual(audit.classify("other", names, expected, actual), "bundled_not_native_verified")
            self.assertEqual(audit.classify("unknown", names, expected, actual), "not_in_theme")
            self.assertEqual(audit.classify("/tmp/icon.png", names, expected, actual), "path_bypasses_theme")

    def test_matching_hash_outside_index_is_not_coverage(self):
        with tempfile.TemporaryDirectory() as tmp:
            theme = Path(tmp)
            (theme / "index.theme").write_text("[Icon Theme]\nDirectories=apps\n")
            for folder in ("apps", "status"):
                (theme / folder).mkdir()
                (theme / folder / "store.svg").write_bytes(b"<svg/>")
            (theme / "status/hidden.svg").write_bytes(b"<svg/>")
            names, _, _ = audit.theme_inventory(theme)
            mapping = {"icons": {"i:1": "apps/store status/store status/hidden"}}
            digest = hashlib.sha256(b"<svg/>").hexdigest()
            manifest = {"outputs": {"icons/" + path: {"sha256": digest}
                                    for path in ("apps/store.svg", "status/store.svg", "status/hidden.svg")}}
            expected, actual, mismatched, unindexed = audit.native_inventory(mapping, manifest, theme, names)
            self.assertEqual(dict(actual), {"store": ["apps/store.svg"]})
            self.assertEqual(mismatched, [])
            self.assertEqual(unindexed, ["status/hidden.svg", "status/store.svg"])
            self.assertEqual(audit.classify("hidden", names, expected, actual), "native_mapping_not_verified")

    def test_verified_name_can_have_unverified_same_name_file(self):
        names = {"battery": ["devices/battery.svg", "status/battery.svg"],
                 "clock": ["actions/clock.svg"], "other": ["apps/other.svg"]}
        actual = {"battery": ["status/battery.svg"], "clock": ["actions/clock.svg"]}
        self.assertEqual(audit.same_name_alternates(names, actual), {
            "battery": {"verified_files": ["status/battery.svg"],
                        "unverified_files": ["devices/battery.svg"]}
        })

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

    def test_kcm_metadata_and_shared_icons(self):
        with tempfile.TemporaryDirectory() as tmp:
            log = Path(tmp) / "metadata.txt"
            prefix = "qt.core.plugin.loader: Found metadata in lib "
            one = ('/nix/store/example/lib/qt-6/plugins/plasma/kcms/kcm_one.so, metadata=\n'
                   '{"MetaData":{"KPlugin":{"Icon":"shared"},'
                   '"X-KDE-System-Settings-Parent-Category":"first"}}\n')
            two = ('/nix/store/example/lib/qt-6/plugins/plasma/kcms/systemsettings/kcm_two.so, metadata=\n'
                   '{"MetaData":{"KPlugin":{"Icon":"shared"}}}\n')
            empty = ('/nix/store/example/lib/qt-6/plugins/plasma/kcms/kcm_empty.so, metadata=\n'
                     '{"MetaData":{"KPlugin":{}}}\n')
            log.write_text(prefix + one + prefix + one + prefix + two + prefix + empty)
            modules = audit.kcm_candidates(log)
            self.assertEqual(len(modules), 3)
            report = audit.kcm_inventory(modules, {"shared": ["apps/shared.svg"]}, {}, {})
            self.assertEqual(report["unique_icon_names"], 1)
            self.assertEqual(report["shared_icon_names"], {"shared": ["kcm_one", "kcm_two"]})
            self.assertEqual(report["conflicting_metadata"], [])
            self.assertEqual(report["modules"][0]["status"], "no_icon_declared")
            self.assertEqual(report["modules"][1]["status"], "bundled_not_native_verified")

    def test_shell_manifest_verifies_private_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            manifest = root / "manifest.json"
            (root / "task-view").mkdir()
            artwork = b"<svg/>"
            (root / "task-view/light.svg").write_bytes(artwork)
            manifest.write_text(audit.json.dumps({
                "format": "windows-modern-shell-assets-v1",
                "declared_source_build": "26300.9974",
                "outputs": {
                    "task-view/light.svg": {"sha256": hashlib.sha256(artwork).hexdigest()},
                    "task-view/dark.svg": {"sha256": "bad"},
                },
            }))
            report = audit.shell_inventory(manifest)
            self.assertEqual(report["verified_outputs"], ["task-view/light.svg"])
            self.assertEqual(report["missing_or_changed_outputs"], ["task-view/dark.svg"])
            self.assertIn("battery/f8d0.svg", report["required_outputs_missing_from_manifest"])
            self.assertNotIn("search/dark-off.png", report["required_outputs_missing_from_manifest"])

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
