# SPDX-License-Identifier: GPL-3.0-or-later
import base64
import configparser
import gzip
import hashlib
import json
import importlib.util
from io import BytesIO
from pathlib import Path
import re
import runpy
import struct
import tempfile
import unittest
from unittest.mock import Mock, patch
import xml.etree.ElementTree as ET
import zlib

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('window_frames', ROOT / 'scripts/theme/window-frames.py')
frames = importlib.util.module_from_spec(spec)
spec.loader.exec_module(frames)
appearance = runpy.run_path(str(ROOT / 'scripts/theme/appearance-packages.py'))
render_color_scheme = appearance['render_color_scheme']
render_kvantum_config = appearance['render_kvantum_config']
render_kvantum_svg = appearance['render_kvantum_svg']
SVG = ('<svg xmlns="http://www.w3.org/2000/svg">'
       '<path id="window-normal" fill="#ffffff" opacity=".8" d="M0 0"/>'
       '<path id="window-normal-inactive" fill="#ffffff" opacity=".8" d="M1 1"/>'
       '<path id="menu-normal" fill="#ffffff" opacity=".8" d="M2 2"/>'
       '</svg>')


def elements(svg):
    return {node.get('id'): node for node in ET.fromstring(svg).iter() if node.get('id')}


class WindowMaterialTests(unittest.TestCase):
    def test_native_accent_widgets(self):
        materialize = appearance["desktoptheme"]
        with tempfile.TemporaryDirectory() as tmp:
            for mode in ("dark", "light"):
                target = materialize(ROOT, Path(tmp), mode)
                for name in appearance["NATIVE_ACCENT_FILLS"]:
                    data = (target / "widgets" / (name + ".svg")).read_bytes()
                    root = ET.fromstring(data)
                    self.assertIn(b"ColorScheme-Highlight", data)
                    self.assertIn(b"current-color-scheme", data)
                    self.assertIsNotNone(root)
                    if name not in appearance["NATIVE_ACCENT_GRADIENTS"]:
                        continue
                    source = ET.parse(ROOT / "plasma/desktoptheme/Windows-modern-dark/widgets"
                                      / (name + ".svg")).getroot()
                    original = {node.get("id"): node for node in source.iter() if node.get("id")}
                    generated = {node.get("id"): node for node in root.iter() if node.get("id")}
                    self.assertEqual(generated.keys(), original.keys() | {"current-color-scheme"})
                    self.assertEqual(len(generated), sum(1 for node in root.iter() if node.get("id")))
                    for gradient_id, count in appearance["NATIVE_ACCENT_GRADIENTS"].get(name, {}).items():
                        gradient = generated[gradient_id]
                        parent = next(node for node in root.iter() if gradient in list(node))
                        self.assertEqual(parent.get("class"), "ColorScheme-Highlight")
                        stops = [node for node in gradient if node.tag.endswith("}stop")]
                        dynamic = [node for node in stops if node.get("stop-color") == "currentColor"
                                   or "stop-color:currentColor" in node.get("style", "")]
                        self.assertEqual(len(dynamic), count)
                        self.assertEqual(len(dynamic), len(stops))
                        original_stops = list(original[gradient_id])
                        self.assertEqual(gradient.attrib, original[gradient_id].attrib)
                        self.assertEqual([node.get("offset") for node in stops],
                                         [node.get("offset") for node in original_stops])
                        for old, new in zip(original_stops, stops):
                            self.assertEqual(old.attrib.keys(), new.attrib.keys())
                            for key in old.attrib:
                                if key not in ("style", "stop-color"):
                                    self.assertEqual(old.get(key), new.get(key))
                            self.assertEqual(
                                new.get("style", "").replace("stop-color:currentColor", "stop-color:#4CC2FF"),
                                old.get("style", ""))
                            self.assertEqual(
                                new.get("stop-color", "").replace("currentColor", "#4CC2FF"),
                                old.get("stop-color", ""))

    def test_margin_focus_uses_native_palette_role(self):
        with tempfile.TemporaryDirectory() as tmp:
            for mode in ("dark", "light"):
                target = appearance["desktoptheme"](ROOT, Path(tmp), mode)
                root = ET.parse(target / "widgets/margins-highlight.svg").getroot()
                paths = [node for node in root.iter() if node.get("class") == "ColorScheme-ButtonFocus"]
                self.assertEqual({node.get("id") for node in paths},
                                 {"fill", "path4131", "path4155", "path4131-3", "path4155-5"})
                for node in paths:
                    self.assertIn("fill:currentColor", node.get("style", ""))
                    self.assertIn("opacity:0.3", node.get("style", ""))
                    self.assertNotRegex(node.get("style", ""), r"(?<![\w-])color\s*:")

    def test_kvantum_accent_bindings_preserve_materials(self):
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        with tempfile.TemporaryDirectory() as tmp:
            target = appearance["kvantum"](ROOT, Path(tmp))
            manifest = json.loads((target / "accent-bindings.json").read_text())
            for mode, entry in manifest.items():
                custom = sync["accent_values"](mode, entry["defaults"], "190,80,130")
                for name, spec in entry["files"].items():
                    original = (target / name).read_text()
                    patched = sync["patch"](original, spec, custom)
                    self.assertIn("#BE5082", patched)
                    self.assertEqual(sync["patch"](patched, spec, entry["defaults"]), original)
                    before = original.splitlines()
                    after = patched.splitlines()
                    owned = {binding[0] for binding in spec["bindings"]}
                    self.assertTrue(all(x == y for i, (x, y) in
                                        enumerate(zip(before, after)) if i not in owned))

    def test_kvantum_independent_link_and_legacy_binding(self):
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        with tempfile.TemporaryDirectory() as tmp:
            target = appearance["kvantum"](ROOT, Path(tmp))
            manifest_path = target / "accent-bindings.json"
            manifest = json.loads(manifest_path.read_text())
            for mode, entry in manifest.items():
                name = "Windows-modernDark.kvconfig" if mode == "dark" else "Windows-modern.kvconfig"
                path = target / name
                original = path.read_text()
                spec = entry["files"][name]
                self.assertEqual(sum(role == "accent_link" for _, role, _, _ in spec["bindings"]), 1)
                for old_manifest in (False, True):
                    if old_manifest:
                        entry["defaults"].pop("accent_link")
                        for binding in spec["bindings"]:
                            if binding[1] == "accent_link":
                                binding[1] = "accent"
                    manifest_path.write_text(json.dumps(manifest))
                    prepared = sync["plan_kvantum"](target, mode, "#BE5082", "#704060")
                    updated = prepared[path][1].decode()
                    self.assertIn("highlight.color=#BE5082", updated)
                    self.assertIn("link.color=#704060", updated)
                    self.assertEqual(sync["patch"](updated, spec, entry["defaults"]), original)
                    native = sync["accent_values"](mode, entry["defaults"], "#BE5082")
                    self.assertIn("link.color=#BE5082", sync["patch"](original, spec, native))

    def test_live_wallpaper_snapshot_contract(self):
        control = runpy.run_path(str(ROOT / "scripts/theme/accent-control.py"))
        discover = control["discover_wallpapers"]
        with tempfile.TemporaryDirectory() as tmp:
            image = Path(tmp) / "wallpaper # one.jpg"
            image.write_bytes(b"image")
            snapshot = {"screens": 2, "images": [
                {"screen": 0, "path": str(image)}, {"screen": 1, "path": str(image)}]}
            with patch.dict(discover.__globals__, {
                    "active_activity": lambda: "current",
                    "live_wallpaper_snapshot": lambda activity: snapshot}):
                result = discover()
                self.assertEqual(result["activity"], "current")
                self.assertEqual(len(result["wallpapers"]), 2)
                self.assertEqual(result["wallpapers"][0], result["wallpapers"][1])
                alias = Path(tmp) / "selected.jpg"
                alias.symlink_to(image)
                snapshot["images"][1]["path"] = str(alias)
                linked = discover()["wallpapers"][1]
                self.assertEqual(linked["source_path"], str(alias))
                self.assertEqual(linked["path"], str(image.resolve()))
                replacement = Path(tmp) / "next.jpg"
                replacement.write_bytes(b"next")
                alias.unlink()
                alias.symlink_to(replacement)
                changed = discover()["wallpapers"][1]
                self.assertEqual(changed["source_path"], str(alias))
                self.assertEqual(changed["path"], str(replacement.resolve()))
                self.assertNotEqual(linked, changed)
                snapshot["images"][1]["path"] = str(image)
                snapshot["images"][1]["screen"] = 0
                with self.assertRaisesRegex(ValueError, "duplicate"):
                    discover()
                snapshot["images"][1]["screen"] = 1
                snapshot["images"][1]["path"] = "https://example.com/wallpaper.jpg"
                with self.assertRaisesRegex(ValueError, "absolute"):
                    discover()
                snapshot["images"][1]["path"] = str(image)
                snapshot["error"] = "Wallpaper preview"
                with self.assertRaisesRegex(ValueError, "preview"):
                    discover()
                del snapshot["error"]
                with patch.dict(discover.__globals__, {"active_activity": iter(("old", "new")).__next__}):
                    with self.assertRaisesRegex(ValueError, "activity changed"):
                        discover()

    def test_primary_wallpaper_snapshot_is_independent(self):
        control = runpy.run_path(str(ROOT / "scripts/theme/accent-control.py"))
        discover = control["discover_wallpapers"]
        with tempfile.TemporaryDirectory() as tmp:
            image = Path(tmp) / "primary.png"
            image.write_bytes(b"image")
            primary = {"screens": 1, "images": [{"screen": 0, "path": str(image)}]}

            def source(activity, primary_only=False):
                self.assertEqual(activity, "current")
                return primary if primary_only else {"error": "Secondary screen is not ready"}

            with patch.dict(discover.__globals__, {"active_activity": lambda: "current",
                                                    "live_wallpaper_snapshot": source}):
                state = discover(primary_only=True)
                self.assertEqual(len(state["wallpapers"]), 1)
                control["require_wallpaper_snapshot"](state, primary_only=True)
                with self.assertRaisesRegex(ValueError, "Secondary screen"):
                    discover()
                image.write_bytes(b"replacement")
                with self.assertRaises(control["WallpaperChangedError"]):
                    control["require_wallpaper_snapshot"](state, primary_only=True)
                primary["screens"] = 2
                primary["images"].append({"screen": 1, "path": str(image)})
                with self.assertRaisesRegex(ValueError, "primary-only"):
                    discover(primary_only=True)

    def test_automatic_wallpaper_cache_and_discovery(self):
        control = runpy.run_path(str(ROOT / "scripts/theme/accent-control.py"))
        discover = control["discover_wallpapers"]
        automatic = control["automatic_state"]
        with tempfile.TemporaryDirectory() as tmp:
            image = Path(tmp) / "wallpaper.png"
            image.write_bytes(b"first")
            snapshot = {"screens": 2, "images": [
                {"screen": 0, "path": str(image)}, {"screen": 1, "path": str(image)}]}
            palette = control["SYNC"]["derive_manual_palette"]("#FF8C00")
            with patch.dict(discover.__globals__, {
                    "active_activity": lambda: "current",
                    "live_wallpaper_snapshot": lambda activity: snapshot}), \
                 patch.dict(control["SYNC"], {"analyze_wallpapers": lambda paths: {"palette": palette}}):
                state = automatic(None)
                self.assertEqual(control["decode_state"](json.dumps(state)), palette)
                control["require_wallpaper_snapshot"](state)
                with patch.dict(control["SYNC"], {"analyze_wallpapers": lambda paths: self.fail("decoded cached images")}):
                    self.assertIs(automatic(state), state)
                legacy = dict(state)
                del legacy["analysis_revision"]
                self.assertEqual(automatic(legacy), state)
                self.assertEqual(state["analysis_revision"], control["SYNC"]["WALLPAPER_ANALYSIS_REVISION"])
                with patch.dict(control["SYNC"], {"icc_reference_identity": lambda: "new-reference"}):
                    with self.assertRaises(control["WallpaperChangedError"]):
                        control["require_wallpaper_snapshot"](state)
                    self.assertEqual(automatic(state)["icc_reference"], "new-reference")
                image.write_bytes(b"replacement image")
                with self.assertRaises(control["WallpaperChangedError"]):
                    control["require_wallpaper_snapshot"](state)
                self.assertNotEqual(automatic(state)["wallpapers"], state["wallpapers"])
                # A native package or slideshow selects a new actual file.
                next_image = Path(tmp) / "next slide.png"
                next_image.write_bytes(b"next")
                snapshot["images"][1]["path"] = str(next_image)
                self.assertEqual(automatic(state)["wallpapers"][1]["path"], str(next_image))
                # A scheduled crossfade has no accepted single-file source.
                # Do not decode a guessed endpoint or mutate the saved ramp.
                snapshot["error"] = "Scheduled wallpaper is between stable images"
                before = json.dumps(state, sort_keys=True)
                with patch.dict(control["SYNC"], {"analyze_wallpapers": lambda paths: self.fail("decoded a crossfade")}):
                    with self.assertRaisesRegex(ValueError, "between stable images"):
                        automatic(state)
                self.assertEqual(json.dumps(state, sort_keys=True), before)
                del snapshot["error"]
                self.assertEqual(automatic(state)["wallpapers"][1]["path"], str(next_image))

    def test_repeated_wallpaper_path_reuses_statistics(self):
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        analyze = sync["analyze_wallpapers"]
        calls = []
        def decode(path):
            calls.append(path)
            return (1, 1, bytes((88, 88, 188, 255)))
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "wallpaper.png"
            path.write_bytes(b"source")
            with patch.dict(analyze.__globals__, {"decode_wallpaper_bitmap": decode}):
                single = analyze([path])
                repeated = analyze([path, path])
            self.assertEqual(calls, [path, path])
            self.assertEqual(single, repeated)

    def test_wallpaper_analysis_rejects_changed_input_batch(self):
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        analyze = sync["analyze_wallpapers"]
        with tempfile.TemporaryDirectory() as tmp:
            first = Path(tmp) / "first.png"
            second = Path(tmp) / "second.png"
            first.write_bytes(b"original")
            second.write_bytes(b"second")

            def decode(path):
                if path == second:
                    replacement = first.with_suffix(".new")
                    replacement.write_bytes(b"replacement")
                    replacement.replace(first)
                return (1, 1, bytes((88, 88, 188, 255)))

            with patch.dict(analyze.__globals__, {"decode_wallpaper_bitmap": decode}):
                with self.assertRaises(sync["WallpaperFileChangedError"]):
                    analyze([first, second, first])

    def test_wallpaper_analysis_rejects_early_replacement_and_failed_decode(self):
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        analyze = sync["analyze_wallpapers"]
        with tempfile.TemporaryDirectory() as tmp:
            first = Path(tmp) / "first.png"
            second = Path(tmp) / "second.png"
            first.write_bytes(b"first")
            second.write_bytes(b"second")

            def replace_later(path):
                if path == first:
                    second.write_bytes(b"new second")
                return (1, 1, bytes((88, 88, 188, 255)))

            with patch.dict(analyze.__globals__, {"decode_wallpaper_bitmap": replace_later}):
                with self.assertRaises(sync["WallpaperFileChangedError"]):
                    analyze([first, second])

            def failed_decode(path):
                path.write_bytes(b"truncated replacement")
                raise OSError("decoder failed")

            with patch.dict(analyze.__globals__, {"decode_wallpaper_bitmap": failed_decode}):
                with self.assertRaises(sync["WallpaperFileChangedError"]):
                    analyze([first, second])
            with patch.dict(analyze.__globals__, {"decode_wallpaper_bitmap": Mock(side_effect=ValueError("unsupported"))}):
                with self.assertRaisesRegex(ValueError, "unsupported") as caught:
                    analyze([first, second])
                self.assertNotIsInstance(caught.exception, sync["WallpaperFileChangedError"])

    def test_windows_accent_state_validation(self):
        control = runpy.run_path(str(ROOT / "scripts/theme/accent-control.py"))
        palette = control["SYNC"]["derive_manual_palette"]("#FF8C00")
        state = {"schema_version": 1, "source": "manual", "palette": palette}
        self.assertEqual(control["decode_state"](json.dumps(state)), palette)
        self.assertEqual(control["decode_state"](json.dumps({**state, "manual_color": "#FF8C00"})),
                         palette)
        for invalid_input in (None, 42, "invalid"):
            with self.assertRaises(ValueError):
                control["decode_state"](json.dumps({**state, "manual_color": invalid_input}))
        self.assertIsNone(control["decode_state"](None))
        for invalid in ([], None, {"schema_version": True, "source": "manual", "palette": palette},
                        {"schema_version": 1, "source": "manual", "palette": []},
                        {"schema_version": 1, "source": "manual",
                         "palette": {**palette, "AccentDark1": None}}):
            with self.assertRaises(ValueError):
                control["decode_state"](json.dumps(invalid))
        state["palette"] = {**palette, "AccentDark1": "invalid"}
        with self.assertRaises(ValueError):
            control["decode_state"](json.dumps(state))
        state["palette"] = {"Accent": "#FF8C00"}
        with self.assertRaisesRegex(ValueError, "Incomplete"):
            control["decode_state"](json.dumps(state))

    def test_kvantum_reload_receipt_contains_both_complete_pairs(self):
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        publish = sync["publish_kvantum_reload"]
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp) / "Windows-modern"
            directory.mkdir()
            (directory / "accent-bindings.json").write_text("{}")
            names = [name + suffix for name in ("Windows-modern", "Windows-modernDark")
                     for suffix in (".kvconfig", ".svg")]
            for name in names:
                (directory / name).write_text(name)
            with patch.object(publish.__globals__["os"], "geteuid", return_value=1000):
                self.assertTrue(publish(directory))
                receipt = directory / "live-reload.json"
                old = receipt.read_bytes()
                self.assertEqual(json.loads(old), {"schema_version": 1, "files": {
                    name: hashlib.sha256(name.encode()).hexdigest() for name in names}})
                self.assertFalse(publish(directory))
                (directory / names[0]).unlink()
                with self.assertRaises(ValueError):
                    publish(directory)
                self.assertEqual(receipt.read_bytes(), old)
                (directory / names[0]).write_text("updated")
                self.assertTrue(publish(directory))
                self.assertNotEqual(receipt.read_bytes(), old)

    def test_pending_automatic_request_is_not_a_sample(self):
        control = runpy.run_path(str(ROOT / "scripts/theme/accent-control.py"))
        pending = control["pending_automatic_state"]()
        self.assertTrue(pending["pending"])
        self.assertNotIn("wallpapers", pending)
        self.assertNotIn("analysis_revision", pending)
        self.assertEqual(control["decode_state"](json.dumps(pending)),
                         control["SYNC"]["derive_manual_palette"]("#0078D4"))
        for invalid in ({**pending, "pending": False}, {**pending, "pending": 1},
                        {**pending, "wallpapers": []}, {**pending, "source": "manual"}):
            with self.assertRaises(ValueError):
                control["decode_state"](json.dumps(invalid))

    def test_initialize_preserves_existing_accent_choices(self):
        control = runpy.run_path(str(ROOT / "scripts/theme/accent-control.py"))
        sync = control["SYNC"]
        raw = json.dumps(control["pending_automatic_state"]())
        for stored, native, wallpaper in ((raw, (False, None), None),
                                          (None, (True, None), "true"),
                                          (None, (False, "#FF0000"), None),
                                          (None, (False, None), "false")):
            def read(group, key):
                if group == control["GROUP"]:
                    return stored
                return wallpaper if key == "accentColorFromWallpaper" else None
            with patch.dict(control["synchronize"].__globals__, {
                    "active_mode": lambda mode: True,
                    "read": read, "native_accent": lambda: native,
                    "automatic_state": Mock(side_effect=AssertionError("must not analyze"))}), \
                 patch.dict(sync, {"write_pending": Mock(side_effect=AssertionError("must not write"))}):
                self.assertEqual(control["synchronize"]("dark", "initialize", []),
                                 False if stored is not None else None)

    def test_manual_accent_refresh_preserves_original_input(self):
        control = runpy.run_path(str(ROOT / "scripts/theme/accent-control.py"))
        sync = control["SYNC"]
        original = "#9F5A8C"
        current = sync["derive_manual_palette"](original)
        self.assertNotEqual(current["Accent"], original)
        previous = {**current, "AccentDark1": "#000001"}
        state = {"schema_version": 1, "source": "manual",
                 "manual_color": original, "palette": previous}
        for action in ("sync", "reapply"):
            with self.subTest(action=action), tempfile.TemporaryDirectory() as tmp:
                config = Path(tmp)
                (config / "Kvantum/Windows-modern").mkdir(parents=True)
                scheme = config / "color-schemes/WindowsModernDark.colors"
                stored = [json.dumps(state)]
                pending = {scheme: (b"previous", b"next")}
                plan = Mock(return_value=pending)
                derive = Mock(wraps=sync["derive_manual_palette"])
                write = Mock(return_value=[scheme])
                publish = Mock(side_effect=lambda value: stored.__setitem__(0, value))

                def read(group, key):
                    return stored[0] if (group, key) == (control["GROUP"], control["KEY"]) else None

                with patch.dict(control["synchronize"].__globals__, {
                        "CONFIG": config, "DATA": config,
                        "active_mode": lambda mode: True,
                        "native_accent": lambda: (False, None),
                        "read": read, "write_state": publish,
                        "scheme_inputs": lambda: ("", {}),
                        "plan_schemes": plan, "apply_current": Mock(),
                        "live_matches": lambda *args: True, "notify_palette": Mock()}), \
                     patch.dict(sync, {"derive_manual_palette": derive,
                                       "owned_file": lambda path: path,
                                       "plan_kvantum": lambda *args: {},
                                       "write_pending": write}):
                    self.assertTrue(control["synchronize"]("dark", action, []))
                    derive.assert_called_once_with(original)
                    plan.assert_called_once_with(config / "color-schemes", "", {},
                                                 previous, current)
                    write.assert_called_once_with(pending)
                    publish.assert_called_once()
                    self.assertEqual(json.loads(stored[0]),
                                     {**state, "palette": current})
                    # Once updated, a matching renderer/state is a no-op.
                    plan.return_value = {}
                    publish.reset_mock()
                    write.reset_mock()
                    self.assertFalse(control["synchronize"]("dark", action, []))
                    publish.assert_not_called()
                    write.assert_not_called()

    def test_automatic_accent_stale_transaction(self):
        control = runpy.run_path(str(ROOT / "scripts/theme/accent-control.py"))
        sync = control["SYNC"]
        palette = sync["derive_manual_palette"]("#FF8C00")
        raw = json.dumps({"schema_version": 1, "source": "manual", "palette": palette})
        state = {"schema_version": 1, "source": "automatic", "activity": "active",
                 "analysis_revision": sync["WALLPAPER_ANALYSIS_REVISION"],
                 "wallpapers": [{"path": "/wallpaper.png"}], "palette": palette}
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp)
            (config / "Kvantum/Windows-modern").mkdir(parents=True)
            path = config / "color-schemes/WindowsModernDark.colors"
            pending = {path: (b"previous", b"next")}
            for late in (False, True):
                stale = control["WallpaperChangedError"]("stale wallpaper")
                verify = Mock(side_effect=[None, stale] if late else [stale])
                write = Mock(return_value=[path])
                restore = Mock()
                publish = Mock()
                apply = Mock()
                notify = Mock()
                with patch.dict(control["synchronize"].__globals__, {
                        "CONFIG": config, "DATA": config, "active_mode": lambda mode: True,
                        "native_accent": lambda: (False, None), "read": lambda group, key: raw,
                        "automatic_state": lambda previous: state,
                        "require_wallpaper_snapshot": verify, "write_state": publish,
                        "scheme_inputs": lambda: ("", {}),
                        "plan_schemes": lambda *args: pending,
                        "apply_current": apply, "live_matches": lambda *args: True,
                        "notify_palette": notify}), \
                     patch.dict(sync, {"owned_file": lambda p: p, "plan_kvantum": lambda *args: {},
                                       "write_pending": write, "restore_pending": restore}):
                    with self.assertRaises(control["WallpaperChangedError"]):
                        control["synchronize"]("dark", "automatic", [])
                publish.assert_not_called()
                if late:
                    write.assert_called_once_with(pending)
                    restore.assert_any_call(pending, [path])
                    self.assertEqual(apply.call_count, 2)
                    notify.assert_called_once()
                else:
                    write.assert_not_called()
                    restore.assert_not_called()
                    apply.assert_not_called()

    def test_windows_accent_scheme_transaction(self):
        control = runpy.run_path(str(ROOT / "scripts/theme/accent-control.py"))
        sync = control["SYNC"]
        template, fixed = control["scheme_inputs"]()
        palette = sync["derive_manual_palette"]("#FF8C00")
        for mode, shade in (("dark", "#FFB634"), ("light", "#E37700")):
            rendered = control["render"](template, fixed, mode, palette)
            scheme = configparser.ConfigParser(interpolation=None)
            scheme.read_string(rendered.decode("utf-8"))
            rgb = lambda value: ",".join(str(int(value[i:i + 2], 16)) for i in (1, 3, 5))
            self.assertEqual(scheme["Colors:Selection"]["BackgroundNormal"], rgb(shade))
            link = "#FFD155" if mode == "dark" else "#A14600"
            for group in ("Button", "Complementary", "Tooltip", "View", "Window"):
                self.assertEqual(scheme["Colors:" + group]["ForegroundLink"], rgb(link))
            self.assertEqual(scheme["Colors:Selection"]["ForegroundLink"],
                             rgb(fixed[mode]["selection_link"]))
            legacy = control["render"](template, fixed, mode, palette, legacy=True)
            self.assertNotEqual(rendered, legacy)
            self.assertEqual(legacy, rendered.replace(
                ("ForegroundLink=" + rgb(link) + "\n").encode(),
                ("ForegroundLink=" + rgb(shade) + "\n").encode()))
            self.assertEqual(scheme["Colors:Window"]["DecorationFocus"], rgb(shade))
            self.assertEqual(scheme["Colors:Selection"]["ForegroundNormal"],
                             rgb(sync["contrast_ink"](shade)))
            self.assertEqual(scheme["Colors:Window"]["BackgroundNormal"], rgb(fixed[mode]["window"]))
            self.assertEqual(scheme["Colors:Button"]["ForegroundActive"],
                             rgb(shade if mode == "light" else fixed[mode]["button_active_text"]))
            self.assertEqual(control["render"](template, fixed, mode, None).decode("utf-8"),
                             render_color_scheme(ROOT, mode))
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp) / "color-schemes"
            appearance["color_schemes"](ROOT, directory)
            changes = control["plan_schemes"](directory, template, fixed, None, palette)
            self.assertEqual(len(changes), 2)
            for path, (old, new) in changes.items():
                self.assertEqual(path.read_bytes(), old)
                path.write_bytes(new)
            self.assertEqual(control["plan_schemes"](directory, template, fixed, palette, palette), {})
            for mode in ("dark", "light"):
                path = directory / (control["scheme_name"](mode) + ".colors")
                path.write_bytes(control["render"](template, fixed, mode, palette, legacy=True))
            migrated = control["plan_schemes"](directory, template, fixed, palette, palette)
            self.assertEqual(set(migrated), set(changes))
            for path, (old, new) in migrated.items():
                self.assertEqual(path.read_bytes(), old)
                self.assertEqual(new, changes[path][1])
                path.write_bytes(new)
            reset = control["plan_schemes"](directory, template, fixed, palette, None)
            self.assertEqual(reset, {path: (new, old) for path, (old, new) in changes.items()})
            path = next(iter(changes))
            path.write_bytes(path.read_bytes() + b"\n# local edit\n")
            with self.assertRaisesRegex(ValueError, "Color scheme differs"):
                control["plan_schemes"](directory, template, fixed, palette, None)

    def test_manual_preset_accent_reference(self):
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        derive = sync["derive_manual_palette"]
        presets = sync["PRESET_SHADES"]
        roles = sync["PRESET_SHADE_ROLES"]
        self.assertEqual(len(presets), 48)
        self.assertEqual(len(roles), 6)
        self.assertEqual(set(roles), {
            "AccentLight3", "AccentLight2", "AccentLight1",
            "AccentDark1", "AccentDark2", "AccentDark3"})
        for base, shades in presets.items():
            with self.subTest(base=base):
                self.assertRegex(base, r"^#[0-9A-F]{6}$")
                self.assertEqual(len(shades), len(roles))
                for shade in shades:
                    self.assertRegex(shade, r"^#[0-9A-F]{6}$")
                self.assertEqual(derive(base.lower()),
                                 {"Accent": base, **dict(zip(roles, shades))})

        reference = json.loads((ROOT / "docs/windows11-26h2-accent-captures.json").read_text(
            encoding="utf-8"))
        captured = reference["captures"]
        for name in ("manual_blue_dark", "manual_blue_light",
                     "manual_orange_light", "manual_orange_light_registry"):
            with self.subTest(capture=name):
                observed = captured[name]["appearance"]["colors_argb"]
                expected = {role: "#" + observed[role][3:]
                            for role in ("Accent", *roles)}
                self.assertEqual(derive(expected["Accent"]), expected)
                self.assertNotEqual(sync["derive_custom_palette"](expected["Accent"]),
                                    expected)
        # Known custom references must continue through the non-preset path.
        for name in ("manual_custom_light_registry",
                     "manual_custom_low_saturation_light_registry"):
            with self.subTest(capture=name):
                sample = captured[name]
                selection = sample["requested_manual_color"]
                self.assertNotIn(selection, presets)
                self.assertEqual(derive(selection),
                                 sync["derive_custom_palette"](selection))

    def test_compare_manual_palette_partial_reports(self):
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        compare = sync["compare_manual_palette_reports"]
        selection = "#FF8C00"
        missing = "#0078D4"
        captured = json.loads((ROOT / "docs/windows11-26h2-accent-captures.json").read_text(
            encoding="utf-8"))["captures"]["manual_orange_light_registry"]
        # Wrap an existing measured ramp and registry bytes as a
        # synthetic batch fixture, not a new target-build capture.
        captured.update(schema_version=5, accent_mode_argument="Manual",
                        manual_color_argument=selection, manual_color_matches_observed=True)
        batch = {"schema_version": 1, "windows_build": "26300.9974",
                 "probe_set": "ManualPaletteBatch", "requested_colors": [selection, missing],
                 "completed": False, "skipped_colors": [missing], "samples": [
                     {"requested_color": selection, "input_kind": "preset",
                      "input_confirmed_by_operator": True, "capture": captured}]}
        captured["windows_build"] = batch["windows_build"]
        with tempfile.TemporaryDirectory() as tmp:
            first = Path(tmp) / "first.json"
            second = Path(tmp) / "second.json"
            first.write_text(json.dumps(batch), encoding="utf-8")
            second.write_text(json.dumps(batch), encoding="utf-8")
            result = compare([first, second])
            self.assertEqual(result["observed_count"], 1)
            self.assertEqual(result["matched_count"], 1)
            self.assertEqual(result["remaining_requested_colors"], [missing])
            self.assertEqual(result["samples"][selection]["differences"], {})
            batch["completed"] = True
            second.write_text(json.dumps(batch), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Incomplete"):
                compare([second])
            batch["completed"] = False
            captured["appearance"]["colors_argb"]["AccentLight3"] = "#FF000000"
            second.write_text(json.dumps(batch), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "registry disagreement"):
                compare([second])

    def test_custom_lab_accent_reference(self):
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        derive = sync["derive_custom_lab_palette"]
        reference = json.loads((ROOT / "docs/windows11-26h2-accent-captures.json").read_text(
            encoding="utf-8"))
        sample = reference["captures"]["manual_custom_light_registry"]
        observed = sample["appearance"]["colors_argb"]
        registry = sample["appearance"]["registry"]
        self.assertEqual(sample["accent_mode_registry"], "Manual")
        self.assertEqual(registry["control_panel_auto_colorization_raw"], 0)
        self.assertEqual(registry["themes_history_auto_color_raw"], 0)
        # The requested input was supplied in the preceding instructions,
        # not captured by the v2 script; this is a conditional reference.
        self.assertEqual(sample["manual_color_argument"], "")
        candidate = derive(sample["requested_manual_color"])
        expected = {role: "#" + observed[role][3:] for role in (
            "Accent", "AccentLight1", "AccentLight2", "AccentLight3",
            "AccentDark1", "AccentDark2", "AccentDark3")}
        self.assertEqual(candidate, expected)
        self.assertEqual(sync["derive_custom_palette"](sample["requested_manual_color"]),
                         expected)
        self.assertNotEqual(candidate["Accent"], sample["requested_manual_color"])
        # The normalized Accent is not interchangeable with the original input.
        self.assertNotEqual(derive(candidate["Accent"]), candidate)
        raw = bytes.fromhex(registry["accent_palette_hex"])
        self.assertEqual(len(raw), registry["accent_palette_length_bytes"])
        self.assertEqual(len(raw), 32)
        observation = reference["registry_palette_observation"]
        for i, role in enumerate(observation["ui_settings_roles_in_slot_order"]):
            slot = raw[i * 4:i * 4 + 4]
            self.assertEqual("#" + slot[:3].hex().upper(), expected[role])
            self.assertEqual(slot[3], 0)
        self.assertEqual("#" + raw[28:31].hex().upper(),
                         observation["custom_unassigned_slot_rgb"])
        self.assertEqual(raw[31], 0)
        # Do not silently apply this branch to unreviewed extreme/gray colors.
        for unsupported in ("#000000", "#FFFFFF", "#808080", "#080020", "#F8ECF8"):
            with self.subTest(color=unsupported):
                with self.assertRaises(ValueError):
                    derive(unsupported)

    def test_lab_shade_byte_boundaries(self):
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        mix = sync["_mix_lab_shade"]
        # Formula-level checks, not new native reference observations.
        # 25 * 58 / 100 = 14.5; binary float formerly rounded it to 14.
        self.assertEqual(mix((0, 0, 0), (25, 25, 25), 58), (15, 15, 15))
        # Restore saturation while preserving the mixed hue and lightness.
        self.assertEqual(mix((200, 100, 100), (100, 200, 100), 50), (185, 185, 65))
        # The old HLS hue-zero convention still applies to an achromatic mix.
        self.assertEqual(mix((200, 100, 100), (100, 200, 200), 50), (200, 100, 100))
        self.assertEqual(mix((255, 0, 0), (0, 0, 0), 100), (0, 0, 0))
        self.assertEqual(mix((255, 0, 0), (255, 255, 255), 100), (255, 255, 255))
        # The provisional branch thresholds remain unchanged.
        uses_lab = sync["uses_custom_lab"]
        self.assertFalse(uses_lab((127, 0, 0)))
        self.assertTrue(uses_lab((128, 0, 0)))
        self.assertTrue(uses_lab((255, 127, 127)))
        self.assertFalse(uses_lab((255, 128, 128)))
        below, exact, above = (137, 103, 103), (138, 102, 102), (139, 101, 101)
        self.assertFalse(uses_lab(below))
        self.assertTrue(uses_lab(exact))
        self.assertTrue(uses_lab(above))
        derive = sync["derive_automatic_palette"]
        self.assertEqual(derive("#896767"), sync["derive_manual_palette"]("#0078D4"))
        self.assertEqual(derive("#8A6666"), sync["derive_custom_lab_palette"]("#8A6666"))

    def test_custom_hsl_accent_reference(self):
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        reference = json.loads((ROOT / "docs/windows11-26h2-accent-captures.json").read_text(
            encoding="utf-8"))
        observation = reference["registry_palette_observation"]
        sample = reference["captures"][observation["low_saturation_capture"]]
        observed = sample["appearance"]["colors_argb"]
        registry = sample["appearance"]["registry"]
        order = observation["ui_settings_roles_in_slot_order"]
        expected = {role: "#" + observed[role][3:] for role in order}
        self.assertEqual(sample["accent_mode_registry"], "Manual")
        self.assertEqual(registry["control_panel_auto_colorization_raw"], 0)
        self.assertEqual(registry["themes_history_auto_color_raw"], 0)
        self.assertEqual(sample["manual_color_argument"], "")
        self.assertEqual(expected["Accent"], sample["requested_manual_color"])
        self.assertEqual(sync["derive_custom_palette"](sample["requested_manual_color"]),
                         expected)
        with self.assertRaises(ValueError):
            sync["derive_custom_lab_palette"](sample["requested_manual_color"])
        raw = bytes.fromhex(registry["accent_palette_hex"])
        self.assertEqual(len(raw), registry["accent_palette_length_bytes"])
        self.assertEqual(len(raw), 32)
        for i, role in enumerate(order):
            slot = raw[i * 4:i * 4 + 4]
            self.assertEqual("#" + slot[:3].hex().upper(), expected[role])
            self.assertEqual(slot[3], 255)
        self.assertEqual("#" + raw[28:31].hex().upper(),
                         observation["low_saturation_unassigned_slot_rgb"])
        self.assertEqual(raw[31], 0)
        # Formula invariants, not measured Windows boundary vectors.
        for source, base in (("#000000", "#3F3F3F"), ("#FFFFFF", "#BFBFBF")):
            with self.subTest(source=source):
                ramp = sync["derive_custom_palette"](source)
                self.assertEqual(ramp["Accent"], base)
                self.assertEqual(set(ramp), set(order))
        self.assertEqual(set(sync["derive_custom_palette"]("#808080")),
                         set(order))

    def test_automatic_wallpaper_shade_reference(self):
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        reference = json.loads((ROOT / "docs/windows11-26h2-accent-captures.json").read_text(
            encoding="utf-8"))
        name = "automatic_blue_light_registry"
        sample = reference["captures"][name]
        self.assertEqual(sample["accent_mode_registry"], "Automatic")
        observed = sample["appearance"]["colors_argb"]
        expected = {role: "#" + observed[role][3:] for role in (
            "Accent", *sync["PRESET_SHADE_ROLES"])}
        # This observed base reproduces the automatic Bloom ramp via the
        # custom calculation. The unobserved extraction input is not proven.
        self.assertEqual(sync["derive_custom_palette"](expected["Accent"]), expected)
        self.assertNotIn(expected["Accent"], sync["PRESET_SHADES"])
        self.assertEqual(reference["wallpaper_reference_matches"][name][
            "registered_wallpaper_sha256"],
            sample["appearance"]["registered_wallpaper_sha256"])

    def test_controlled_automatic_wallpaper_references(self):
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        derive = sync["derive_automatic_palette"]
        report = json.loads((ROOT / "docs/windows11-26h2-wallpaper-probes.json").read_text(
            encoding="utf-8"))
        self.assertTrue(report["restoration"]["wallpaper_path_verified"])
        self.assertTrue(report["restoration"]["palette_matches_baseline"])
        self.assertEqual(report["restoration"]["observation"]["capture"],
                         report["baseline"])
        baseline = report["baseline"]
        probes = {sample["image"]["name"]: sample for sample in report["samples"]}
        self.assertEqual(set(probes), {"solid-purple", "solid-orange", "center-purple",
                                      "solid-gray", "corner-purple", "solid-blue"})
        slot_roles = ("AccentLight3", "AccentLight2", "AccentLight1", "Accent",
                      "AccentDark1", "AccentDark2", "AccentDark3")
        expected_by_name = {}
        seeds = {}
        for name, capture in [("baseline", baseline)] + [
                (name, probe["observation"]["capture"])
                for name, probe in probes.items()]:
            with self.subTest(name=name):
                appearance = capture["appearance"]
                colors = appearance["colors_argb"]
                registry = appearance["registry"]
                self.assertEqual(capture["windows_build"], "26300.9974")
                self.assertEqual(capture["accent_mode_registry"], "Automatic")
                self.assertFalse(capture["accent_mode_registry_conflict"])
                self.assertEqual(registry["control_panel_auto_colorization_raw"], 1)
                self.assertEqual(registry["themes_history_auto_color_raw"], 1)
                self.assertEqual(appearance["source_wallpaper_sha256"],
                                 appearance["registered_wallpaper_sha256"])
                self.assertRegex(appearance["source_wallpaper_sha256"], r"^[0-9A-F]{64}$")
                for key in ("apps_use_light_theme", "system_uses_light_theme",
                            "transparency_raw", "wallpaper_style_raw", "tile_wallpaper_raw",
                            "reported_display_width", "reported_display_height"):
                    self.assertEqual(appearance[key], baseline["appearance"][key])
                expected = {role: "#" + colors[role][3:] for role in slot_roles}
                expected_by_name[name] = expected
                raw = bytes.fromhex(registry["accent_palette_hex"])
                self.assertEqual(len(raw), registry["accent_palette_length_bytes"])
                self.assertEqual(len(raw), 32)
                for i, role in enumerate(slot_roles):
                    self.assertEqual("#FF" + raw[4*i:4*i+3].hex().upper(), colors[role])
                # These settled automatic observations contain a useful
                # intermediate RGB in the low 24 bits of DWM ColorizationColor.
                # Earlier manual-to-automatic captures had stale DWM values.
                seed = "#{:06X}".format(registry["dwm_colorization_color_raw"] & 0xFFFFFF)
                seeds[name] = seed
                if name == "solid-gray":
                    self.assertEqual(seed, "#6E7373")
                    self.assertEqual(expected["Accent"], "#0078D4")
                    # Measured low-saturation candidate selects default blue.
                    self.assertEqual(derive(seed), expected)
                    self.assertEqual(derive(None), expected)
                else:
                    self.assertEqual(derive(seed), expected)
        for probe in probes.values():
            self.assertEqual((probe["width"], probe["height"]), (1280, 800))
            self.assertGreaterEqual(probe["observation"]["stable_captures"], 2)
            self.assertTrue(probe["observation"]["palette_changed_since_previous"])
            self.assertTrue(probe["observation"]["registered_wallpaper_changed_since_previous"])

        self.assertEqual(seeds["solid-blue"], "#0876CF")
        self.assertEqual(expected_by_name["solid-blue"]["Accent"], "#0976CF")
        self.assertNotEqual(derive(expected_by_name["solid-blue"]["Accent"]),
                            expected_by_name["solid-blue"])
        self.assertNotEqual(derive(probes["solid-orange"]["image"]["background"]),
                            expected_by_name["solid-orange"])
        self.assertEqual(expected_by_name["center-purple"], expected_by_name["corner-purple"])
        self.assertNotEqual(expected_by_name["center-purple"], expected_by_name["solid-orange"])
        center, corner = (probes[name] for name in ("center-purple", "corner-purple"))
        for probe in (center, corner):
            rect = probe["image"]["rectangle"]
            self.assertEqual(rect["width"] * rect["height"] * 4,
                             probe["width"] * probe["height"])
            self.assertEqual(probe["image"]["background"], "#FF8C00")
            self.assertEqual(rect["color"], "#9F5A8C")
        self.assertEqual((center["image"]["rectangle"]["x"], center["image"]["rectangle"]["y"]),
                         (320, 200))
        self.assertEqual((corner["image"]["rectangle"]["x"], corner["image"]["rectangle"]["y"]),
                         (0, 0))
        self.assertNotEqual(center["observation"]["capture"]["appearance"]["source_wallpaper_sha256"],
                            corner["observation"]["capture"]["appearance"]["source_wallpaper_sha256"])

    def test_refinement_automatic_wallpaper_candidates(self):
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        derive = sync["derive_automatic_palette"]
        reference = json.loads((ROOT / "docs/windows11-26h2-wallpaper-probes-refinement.json").read_text(
            encoding="utf-8"))
        self.assertEqual(reference["windows_build"], "26300.9974")
        self.assertTrue(reference["restoration"]["wallpaper_path_verified"])
        self.assertTrue(reference["restoration"]["palette_matches_baseline"])
        slot_roles = ("AccentLight3", "AccentLight2", "AccentLight1", "Accent",
                      "AccentDark1", "AccentDark2", "AccentDark3")
        captures = [("baseline", reference["baseline"])] + [
            (sample["name"], sample) for sample in reference["samples"]]
        default = sync["derive_manual_palette"]("#0078D4")
        accepted = []
        fallback = []
        for name, sample in captures:
            with self.subTest(name=name):
                self.assertEqual(sample["source_wallpaper_sha256"],
                                 sample["registered_wallpaper_sha256"])
                # The archived baseline has no preceding-probe fields.
                if name != "baseline":
                    self.assertGreaterEqual(sample["stable_captures"], 2)
                    self.assertTrue(sample["palette_changed_since_previous"])
                    self.assertTrue(sample["registered_wallpaper_changed_since_previous"])
                image_color = int(sample["image_color_dword"], 16)
                colorization = int(sample["dwm_colorization_dword"], 16)
                afterglow = int(sample["dwm_colorization_afterglow_dword"], 16)
                # The upper ImageColor byte is intentionally uninterpreted.
                self.assertEqual(image_color & 0xFFFFFF, colorization & 0xFFFFFF)
                self.assertEqual(colorization, afterglow)
                candidate = "#{:06X}".format(image_color & 0xFFFFFF)
                channels = tuple(bytes.fromhex(candidate[1:]))
                _, saturation = sync["custom_hsl_coordinates"](channels)
                # This compact reference stores six hex digits without '#'.
                palette = {role: sync["rgb"]("#" + value)
                           for role, value in sample["palette"].items()}
                self.assertEqual(set(palette), {"Accent", *slot_roles})
                if saturation < sync["CUSTOM_LAB_MIN_SATURATION"]:
                    self.assertEqual(derive(candidate), default)
                    self.assertEqual(palette, default)
                    fallback.append((name, float(saturation)))
                else:
                    self.assertEqual(derive(candidate), palette)
                    accepted.append((name, float(saturation)))
                raw = bytes.fromhex(sample["accent_palette_hex"])
                self.assertEqual(len(raw), 32)
                for index, role in enumerate(slot_roles):
                    self.assertEqual("#" + raw[index * 4:index * 4 + 3].hex().upper(),
                                     palette[role])
                    self.assertEqual(raw[index * 4 + 3], 0)
        self.assertEqual([name for name, _ in fallback], ["purple-muted-05"])
        self.assertEqual(len(accepted), 8)
        self.assertLess(fallback[0][1], 0.15)
        accepted_low = min(value for _, value in accepted)
        self.assertGreater(accepted_low, 0.15)
        self.assertEqual(derive(None), default)

        by_name = {sample["name"]: sample for sample in reference["samples"]}
        self.assertEqual(by_name["quarter-orange"]["palette"]["Accent"], "C7510A")
        self.assertEqual(by_name["half-purple"]["palette"]["Accent"], "BB5900")
        self.assertEqual(by_name["small-orange-on-gray"]["palette"]["Accent"], "B75B00")
        self.assertEqual(by_name["purple-muted-12"]["palette"]["Accent"], "8E6985")
        quarter = by_name["quarter-orange"]["image"]["rectangle"]
        half = by_name["half-purple"]["image"]["rectangle"]
        small = by_name["small-orange-on-gray"]["image"]["rectangle"]
        self.assertEqual(quarter["width"] * quarter["height"], 1280 * 800 // 4)
        self.assertEqual(half["width"] * half["height"], 1280 * 800 // 2)
        self.assertEqual(small["width"] * small["height"], 1280 * 800 // 16)

    def test_cache_isolation_automatic_palette_and_alpha(self):
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        report = json.loads((ROOT / "docs/windows11-26h2-wallpaper-probes-cache-isolation.json").read_text(
            encoding="utf-8"))
        self.assertEqual(report["probe_set"], "CacheIsolation")
        self.assertEqual(len(report["samples"]), 16)
        self.assertTrue(report["restoration"]["wallpaper_path_verified"])
        self.assertTrue(report["restoration"]["palette_matches_baseline"])
        baseline = report["baseline"]
        roles = ("Accent", *sync["PRESET_SHADE_ROLES"])
        native_base = baseline["native_wallpaper_color_api"]["argb"]
        by_name = {}
        solid_count = 0
        for sample in report["samples"]:
            image = sample["image"]
            observation = sample["observation"]
            capture = observation["capture"]
            native = capture["native_wallpaper_color_api"]
            appearance = capture["appearance"]
            registry = appearance["registry"]
            reference = observation["isolation_reference"]
            cache = observation["cache_observation"]["transcoded"]
            with self.subTest(name=image["name"]):
                self.assertEqual(capture["windows_build"], "26300.9974")
                self.assertEqual(capture["accent_mode_registry"], "Automatic")
                self.assertFalse(capture["accent_mode_registry_conflict"])
                self.assertEqual((sample["width"], sample["height"]), (1280, 800))
                self.assertEqual(observation["stable_captures"], 2)
                self.assertTrue(observation["native_argb_changed_from_reference"])
                self.assertEqual(reference["native_argb"], native_base)
                self.assertEqual(reference["wallpaper_sha256"],
                                 baseline["appearance"]["registered_wallpaper_sha256"])
                self.assertNotEqual(native["argb"], native_base)
                self.assertEqual(appearance["source_wallpaper_sha256"],
                                 appearance["registered_wallpaper_sha256"])
                self.assertEqual(native["status"], "ok")
                self.assertEqual(native["hresult"], "0x00000000")
                self.assertEqual(native["argb"], native["image_color_argb"])
                self.assertEqual(native["argb"], native["image_color_after_api_argb"])
                self.assertFalse(native["image_color_changed_by_api"])
                argb = int(native["argb"], 16)
                self.assertEqual(argb, registry["desktop_image_color_raw"] & 0xFFFFFFFF)
                self.assertEqual(argb & 0xFFFFFF, registry["dwm_colorization_color_raw"] & 0xFFFFFF)
                self.assertEqual(argb >> 24, native["alpha"])
                candidate = "#{:06X}".format(argb & 0xFFFFFF)
                expected = {role: "#" + appearance["colors_argb"][role][3:] for role in roles}
                self.assertEqual(sync["derive_automatic_palette"](candidate), expected)
                self.assertEqual(cache["status"], "ok")
                self.assertTrue(cache["is_jpeg"])
                self.assertNotEqual(cache["sha256"], reference["caches"]["transcoded"]["sha256"])
                if image["rectangle"] is None:
                    solid_count += 1
                    pixels = cache["sampled_solid_rgb"]
                    self.assertEqual(len(pixels), 9)
                    self.assertEqual(set(pixels), {cache["background_rgb"]})
                    self.assertTrue(cache["sampled_uniform"])
                    channels = tuple(bytes.fromhex(cache["background_rgb"][1:]))
                    span = max(channels) - min(channels)
                    # Only the sampled uniform solids identify this statistic.
                    self.assertEqual(sync["derive_wallpaper_alpha"](span * len(pixels), len(pixels)),
                                     native["alpha"])
                    self.assertEqual(cache["alpha_from_sampled_span"], native["alpha"])
                by_name[image["name"]] = (candidate, cache["sha256"])
        self.assertEqual(solid_count, 7)
        self.assertEqual(len(by_name), 16)
        # Keep the counterexamples visible without treating them as a
        # general extraction formula or a position-dependent lookup.
        self.assertEqual(by_name["isolated-red-high-left"][0], "#D24444")
        for name in ("isolated-red-high-right", "isolated-red-high-top",
                     "isolated-red-low-left", "isolated-red-low-right"):
            self.assertEqual(by_name[name][0], "#008700")
        for name in ("isolated-cyan-60-left", "isolated-cyan-60-right", "isolated-cyan-60-top"):
            self.assertEqual(by_name[name][0], "#D44343")
        self.assertEqual(by_name["isolated-cyan-75-left"][0], "#008181")
        self.assertEqual(by_name["isolated-alpha-span-48"], by_name["isolated-alpha-span-49"])

    def test_wallpaper_alpha_statistics_contract(self):
        derive = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))["derive_wallpaper_alpha"]
        for range_sum, count, expected in ((0, 1, 125), (99, 2, 174),
                                           (100, 2, 175), (255, 1, 175)):
            with self.subTest(range_sum=range_sum, count=count):
                self.assertEqual(derive(range_sum, count), expected)
        for range_sum, count in ((-1, 1), (0, 0), (256, 1), (1.0, 1), (1, True)):
            with self.subTest(range_sum=range_sum, count=count):
                with self.assertRaises(ValueError):
                    derive(range_sum, count)

    def test_weighted_wallpaper_uniform_cache_reference(self):
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        report = json.loads((ROOT / "docs/windows11-26h2-wallpaper-probes-cache-isolation.json").read_text(
            encoding="utf-8"))
        count = 0
        for sample in report["samples"]:
            if sample["image"]["rectangle"] is not None:
                continue
            observation = sample["observation"]
            cache = observation["cache_observation"]["transcoded"]
            native = observation["capture"]["native_wallpaper_color_api"]
            pixel = tuple(bytes.fromhex(cache["background_rgb"][1:]))
            # A synthetic uniform analysis buffer tests the color math.
            # It does not establish the native decoder or resampling path.
            with self.subTest(name=sample["image"]["name"]):
                seed, alpha = sync["derive_weighted_wallpaper_seed"]([pixel], 1, 1)
                candidate = sync["normalize_weighted_wallpaper_seed"](seed)
                self.assertEqual(candidate, "#" + native["argb"][-6:])
                self.assertEqual(alpha, native["alpha"])
            count += 1
        self.assertEqual(count, 7)

    def test_weighted_wallpaper_buffer_order_and_contract(self):
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        derive = sync["derive_weighted_wallpaper_seed"]
        normalize = sync["normalize_weighted_wallpaper_seed"]
        red, cyan = (188, 88, 88), (32, 132, 132)
        self.assertEqual(normalize(derive([red] * 40 + [cyan] * 60, 10, 10)[0]),
                         "#D44343")
        self.assertEqual(normalize(derive([red] * 25 + [cyan] * 75, 10, 10)[0]),
                         "#008181")
        # At 2,000 pixels the native stride is eight. These patterns
        # distinguish it from the incorrectly reconstructed stride two.
        # Unsampled pixels still contribute to Alpha.
        first, first_alpha = derive(([red] + [cyan] * 7) * 250, 40, 50)
        second, second_alpha = derive(([cyan] + [red] * 7) * 250, 40, 50)
        self.assertEqual(normalize(first), "#D44343")
        self.assertEqual(normalize(second), "#008181")
        self.assertEqual(first_alpha, second_alpha)
        self.assertEqual(first_alpha, 175)
        for pixels, width, height in (([], 1, 1), ([red], 257, 1),
                                      ([(256, 0, 0)], 1, 1), ([(1, 2, 3, 4)], 1, 1)):
            with self.subTest(pixels=pixels, width=width, height=height):
                with self.assertRaises(ValueError):
                    derive(pixels, width, height)

    def test_weighted_wallpaper_bitmap_contract(self):
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        opaque = sync["derive_weighted_wallpaper_seed"]
        derive = sync["derive_weighted_wallpaper_bitmaps"]
        # Stored B/G/R/marker, not source RGBA. A nonzero marker does not
        # scale the stored RGB; zero skips a pixel without changing count.
        red = bytes((88, 88, 188, 255))
        red_partial = bytes((88, 88, 188, 1))
        cyan = bytes((132, 132, 32, 255))
        absent = bytes((255, 255, 0, 0))
        seed, _ = opaque([(188, 88, 88)], 1, 1)
        self.assertEqual(derive([(4, 1, red_partial + absent * 3)]),
                         (seed, 150))
        self.assertEqual(derive([(1, 1, red), (3, 1, absent * 3)]),
                         (seed, 150))
        self.assertIsNone(derive([(1, 1, absent)]))
        # Positions still advance for skipped pixels. Only the odd
        # positions contain RGB here, while stride eight samples even ones.
        self.assertIsNone(derive([(40, 50, (absent + red) * 1000)]))
        # Group weights are pooled before the winner is selected.
        for red_count, cyan_count in ((40, 60), (25, 75)):
            with self.subTest(red_count=red_count, cyan_count=cyan_count):
                separate = [(red_count, 1, red * red_count),
                            (cyan_count, 1, cyan * cyan_count)]
                together = [(100, 1, red * red_count + cyan * cyan_count)]
                self.assertEqual(derive(separate), derive(together))
        # Restart stride for each bitmap instead of flattening the list.
        # The first buffer has an odd count and stride eight, so the first
        # sample in the second buffer must still be at its own position 0.
        first = (43, 47, absent * (43 * 47))
        second = (40, 50, (red + absent) * 1000)
        self.assertEqual(derive([first, second]), (seed, 149))
        for buffers in ([], [(1, 1, b"")], [(257, 1, red * 257)],
                        [(1, 1, [88, 88, 188, 255])]):
            with self.subTest(buffers=buffers):
                with self.assertRaises(ValueError):
                    derive(buffers)

    def test_opaque_wallpaper_bitmap_preparation(self):
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        prepare = sync["prepare_opaque_wallpaper_bitmap"]
        self.assertEqual(prepare(bytes((1, 2, 3, 4, 5, 6)), 2, 1),
                         (2, 1, bytes((3, 2, 1, 255, 6, 5, 4, 255))))
        for pixels, width, height in ((b"", 1, 1), (b"", 0, 1),
                                      (b"123", True, 1), (bytearray(3), 1, 1)):
            with self.subTest(width=width, height=height):
                with self.assertRaises(ValueError):
                    prepare(pixels, width, height)

    def test_wic_bitmap_boundary_reference(self):
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        prepare = sync["prepare_opaque_wallpaper_bitmap"]
        report = json.loads((ROOT / "docs/windows11-26h2-wallpaper-probes-bitmap-boundary.json").read_text(
            encoding="utf-8"))
        self.assertEqual(report["probe_set"], "BitmapBoundary")
        self.assertTrue(report["restoration"]["wallpaper_path_verified"])
        self.assertTrue(report["restoration"]["palette_matches_baseline"])
        native_results = {}
        for sample in report["samples"]:
            image = sample["image"]
            observation = sample["observation"]
            capture = observation["capture"]
            native = capture["native_wallpaper_color_api"]
            with self.subTest(name=image["name"]):
                self.assertEqual((sample["width"], sample["height"]), (1280, 800))
                self.assertEqual(observation["stable_captures"], 2)
                self.assertTrue(observation["native_argb_changed_from_reference"])
                self.assertEqual(native["hresult"], "0x00000000")
                self.assertEqual(native["argb"], native["image_color_argb"])
                self.assertEqual(native["argb"], native["image_color_after_api_argb"])
                self.assertFalse(native["image_color_changed_by_api"])
                self.assertTrue(native["rgb_matches_dwm_colorization"])
                buffers = {}
                for kind, item in observation["wic_boundary"].items():
                    self.assertEqual((item["width"], item["height"]), (256, 256))
                    self.assertEqual(item["interpolation_mode"], 1)
                    self.assertEqual(item["pixel_format"], "32bppBGR")
                    self.assertEqual(item["order"], "top-down BGRX")
                    raw = gzip.decompress(base64.b64decode(item["gzip_base64"], validate=True))
                    self.assertEqual(len(raw), 256 * 256 * 4)
                    self.assertEqual(hashlib.sha256(raw).hexdigest().upper(), item["bitmap_sha256"])
                    self.assertEqual(set(raw[3::4]), {255})
                    buffers[kind] = raw
                self.assertEqual(set(buffers), {"source", "transcoded"})
                self.assertEqual(observation["wic_boundary"]["source"]["source_sha256"],
                                 capture["appearance"]["source_wallpaper_sha256"])
                self.assertEqual(observation["wic_boundary"]["transcoded"]["source_sha256"],
                                 observation["cache_observation"]["transcoded"]["sha256"])
                # Rebuild the authored opaque RGB image, not the Windows JPEG.
                width, height = sample["width"], sample["height"]
                rect = image["rectangle"]
                bg = bytes.fromhex(image["background"][1:])
                fg = bytes.fromhex(rect["color"][1:])
                row = bg * width
                patch = (bg * rect["x"] + fg * rect["width"]
                         + bg * (width - rect["x"] - rect["width"]))
                source = (row * rect["y"] + patch * rect["height"]
                          + row * (height - rect["y"] - rect["height"]))
                self.assertEqual(prepare(source, width, height), (256, 256, buffers["source"]))
                # Both independently recreated WIC inputs reproduce the
                # native ARGB with the corrected 250-pixel sampling divisor.
                # This does not prove which stream the renderer selected.
                for kind, raw in buffers.items():
                    with self.subTest(input_kind=kind):
                        seed, alpha = sync["derive_weighted_wallpaper_bitmaps"]([(256, 256, raw)])
                        normalized = sync["normalize_weighted_wallpaper_seed"](seed)
                        self.assertEqual("0x{:02X}{}".format(alpha, normalized[1:]),
                                         native["argb"])
                roles = ("Accent", *sync["PRESET_SHADE_ROLES"])
                expected = {role: "#" + capture["appearance"]["colors_argb"][role][3:]
                            for role in roles}
                self.assertEqual(sync["derive_automatic_palette"]("#" + native["argb"][-6:]), expected)
                native_results[image["name"]] = native["argb"]
        self.assertEqual(len(report["samples"]), 3)
        self.assertEqual(native_results, {
            "isolated-red-high-left": "0xAFD24444",
            "isolated-red-high-right": "0xAF008700",
            "isolated-red-high-top": "0xAF008700",
        })

    def test_decode_wallpaper_orientation_and_alpha(self):
        try:
            from PIL import Image
        except ImportError:
            self.skipTest("optional Pillow unavailable")
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        decode = sync["decode_wallpaper_bitmap"]
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / "oriented.png"
            # EXIF 6 rotates the 2x3 image clockwise to 3x2.
            pixels = [(10, 20, 30), (40, 50, 60), (70, 80, 90),
                      (100, 110, 120), (130, 140, 150), (160, 170, 180)]
            with Image.new("RGB", (2, 3)) as image:
                image.putdata(pixels)
                exif = Image.Exif()
                exif[274] = 6
                image.save(path, exif=exif)
            original = path.read_bytes()
            expected = bytes(channel for r, g, b in
                             (pixels[4], pixels[2], pixels[0], pixels[5], pixels[3], pixels[1])
                             for channel in (b, g, r, 255))
            self.assertEqual(decode(path), (3, 2, expected))
            self.assertEqual(path.read_bytes(), original)
            with patch.dict(decode.__globals__, {"WALLPAPER_DECODE_PIXEL_LIMIT": 5}):
                with self.assertRaisesRegex(ValueError, "decode limit"):
                    decode(path)
            rgba = root / "rgba.png"
            with Image.new("RGBA", (1, 1), (10, 20, 30, 255)) as image:
                image.save(rgba)
                self.assertEqual(decode(rgba), (1, 1, bytes((30, 20, 10, 255))))
                image.putpixel((0, 0), (10, 20, 30, 128))
                image.save(rgba)
            # This is the candidate premultiply/unpremultiply contract,
            # not a measurement of WIC's no-resize path.
            self.assertEqual(decode(rgba), (1, 1, bytes((29, 19, 9, 128))))
            # RGB PNG can also carry a transparent-color key.
            with Image.new("RGB", (1, 1), (10, 20, 30)) as image:
                image.save(rgba, transparency=(10, 20, 30))
            self.assertEqual(decode(rgba), (1, 1, bytes(4)))
            with Image.new("RGBA", (1, 1), (10, 20, 30, 128)) as image:
                image.save(rgba, icc_profile=b"unreviewed")
            with self.assertRaisesRegex(ValueError, "reviewed RGB8 ICC transform"):
                decode(rgba)
            with Image.new("RGBA", (1, 1), (10, 20, 30, 128)) as image:
                webp = root / "transparent.webp"
                try:
                    image.save(webp, lossless=True)
                except OSError:
                    pass  # Pillow builds without a WebP encoder.
                else:
                    with self.assertRaisesRegex(ValueError, "reviewed PNG contract"):
                        decode(webp)
            with self.assertRaises(ValueError):
                decode(root)
            with self.assertRaises(ValueError):
                decode(root / "missing.jpg")

    def test_windows_icc_alpha_boundary(self):
        try:
            from PIL import Image, ImageCms
        except ImportError:
            self.skipTest("optional Pillow/ImageCms unavailable")
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        diagnostic = runpy.run_path(str(ROOT / "scripts/theme/analyze-wallpaper-icc.py"))
        decode = sync["decode_wallpaper_bitmap"]
        # DecodeAlphaProfile, build 26300.9974. Keep only observed hashes
        # and the five RGB probe mappings, not the private native links.
        source_colors = ("E13030", "3030E1", "148A14", "A03CD0", "FF00FF")
        mappings = {
            "none": source_colors,
            "srgb": ("E12F2F", "2F2FE1", "138A13", "A03CD0", "FF00FF"),
            "linear-srgb": ("F27878", "7878F2", "4FC34F", "D085EA", "FF00FF"),
        }
        references = {
            "none": (
                "B680F4F8DE0864BE46402D9BD5CB49242CDBB49DA6304202F43FA680A3648C60",
                "8B1C73D05DF30B5F6F8E50210FEDAC0A74806E07203D3EAF9164FAC9509C76F0"),
            "srgb": (
                "8C14697FA78CED9ACC23931474A221FA0D8B214F393EA8DC9B26D0D8938D8201",
                "FB33CAC0B86A24DF8C5D995C60EE99E17758D0AC3B42F961D0A4A7CBBBC9D930"),
            "linear-srgb": (
                "C69D82958AD2352F2E436E000B1E00B6EE199424489F7406CA3FF6E8A85A000E",
                "75D9D57184D101C41D0FEFEEE06909516FA911125AE5AA51E39B1B2863EFD778"),
        }
        source_hashes = {
            128: "2AF67953C10E628B9A2E7161FACED2D903082AE245AA64C9B91C0C8218F54701",
            1: "E75E23430D2A0C0DCBC8AA6BBB416D297C1ABE7C44B5BDE81CFFE9E7895D8B9C",
        }
        with tempfile.TemporaryDirectory() as tmp:
            for name, colors in mappings.items():
                mapping = {bytes.fromhex(a): tuple(bytes.fromhex(b))
                           for a, b in zip(source_colors, colors)}
                transform = lambda r, g, b: mapping[bytes((r, g, b))]
                # Stub only the private replay lookup; the actual decoder,
                # pointwise conversion, resampler and reducer are exercised.
                profile = None if name == "none" else b"synthetic-alpha-probe"
                native = {"transform_for_profile":
                          lambda data: transform if data == profile else None}
                for alpha, expected in zip((128, 1), references[name]):
                    with self.subTest(profile=name, alpha=alpha):
                        pixels = diagnostic["alpha_probe_rgba"](alpha)
                        self.assertEqual(diagnostic["alpha_decoded_hash"](pixels), source_hashes[alpha])
                        path = Path(tmp) / f"{name}-{alpha}.png"
                        with Image.frombytes("RGBA", (1280, 800), pixels) as image:
                            image.save(path, **({"icc_profile": profile} if profile else {}))
                        original = path.read_bytes()
                        with patch.dict(decode.__globals__, {"_native_icc_module": lambda: native}):
                            w, h, bitmap = decode(path)
                        self.assertEqual((w, h), (256, 256))
                        self.assertEqual(hashlib.sha256(bitmap).hexdigest().upper(), expected)
                        self.assertEqual(path.read_bytes(), original)
                        seed, marker = sync["derive_weighted_wallpaper_bitmaps"](((w, h, bitmap),))
                        normalized = sync["normalize_weighted_wallpaper_seed"](seed)
                        self.assertEqual(f"0x{marker:02X}{normalized[1:]}", "0xAFD24444")

    def test_windows_png_decoder_boundary(self):
        try:
            from PIL import Image
        except ImportError:
            self.skipTest("optional Pillow unavailable")
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        report = json.loads((ROOT / "docs/windows11-26h2-wallpaper-probes-decode-boundary.json").read_text(
            encoding="utf-8-sig"))
        self.assertEqual(report["probe_set"], "DecodeBoundary")
        self.assertEqual(report["baseline"]["windows_build"], "26300.9974")
        self.assertTrue(report["restoration"]["wallpaper_path_verified"])
        self.assertTrue(report["restoration"]["palette_matches_baseline"])
        references = {}
        with tempfile.TemporaryDirectory() as tmp:
            for sample in report["samples"]:
                probe, observation = sample["image"], sample["observation"]
                capture = observation["capture"]
                source = observation["wic_boundary"]["source"]
                raw = gzip.decompress(base64.b64decode(source["gzip_base64"]))
                with self.subTest(probe=probe["name"]):
                    self.assertEqual(len(raw), 256 * 256 * 4)
                    self.assertEqual(hashlib.sha256(raw).hexdigest().upper(), source["bitmap_sha256"])
                    self.assertEqual(source["source_sha256"], capture["appearance"]["registered_wallpaper_sha256"])
                    self.assertTrue(probe["pixel_validation"]["decoded_bgra_matches"])
                    self.assertTrue(observation["native_argb_changed_from_reference"])
                    native = capture["native_wallpaper_color_api"]
                    self.assertTrue(native["argb_matches_image_color"])
                    self.assertTrue(native["rgb_matches_dwm_colorization"])
                    references[probe["name"]] = (raw, native["argb"])
                    if probe["icc_profile"] != "none":
                        continue  # Raw source WIC does not include the ICC-managed cache.
                    width, height = sample["width"], sample["height"]
                    patch, marker = probe["rectangle"], probe["marker_rectangle"]

                    def box(rect):
                        return (rect["x"], rect["y"], rect["x"] + rect["width"],
                                rect["y"] + rect["height"])

                    def rgba(color, alpha):
                        return (*bytes.fromhex(color[1:]), alpha)

                    path = Path(tmp) / (probe["name"] + ".png")
                    with Image.new("RGBA", (width, height), rgba(probe["background"], 255)) as image:
                        image.paste(rgba(patch["color"], probe["patch_alpha"]), box(patch))
                        image.paste(rgba(probe["marker"], 255), box(marker))
                        image.save(path)
                    before = path.read_bytes()
                    self.assertEqual(sync["decode_wallpaper_bitmap"](path), (256, 256, raw))
                    self.assertEqual(path.read_bytes(), before)
                    result = sync["analyze_wallpapers"]([path])
                    roles = ("Accent", *sync["PRESET_SHADE_ROLES"])
                    expected = {role: "#" + capture["appearance"]["colors_argb"][role][3:]
                                for role in roles}
                    self.assertEqual(result["colorization_argb"], native["argb"])
                    self.assertEqual(result["palette"], expected)
        self.assertEqual(len(references), 7)
        self.assertEqual(references["decode-opaque"], references["decode-srgb"])
        self.assertEqual(references["decode-opaque"][0], references["decode-linear"][0])
        self.assertNotEqual(references["decode-opaque"][1], references["decode-linear"][1])
        self.assertEqual(references["decode-alpha-0-red"], references["decode-alpha-0-blue"])

    def test_icc_wallpaper_conversion(self):
        try:
            from PIL import Image
        except ImportError:
            self.skipTest("optional Pillow unavailable")
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        decode = sync["decode_wallpaper_bitmap"]
        collector = (ROOT / "scripts/capture-windows-wallpaper-probes.ps1").read_text(encoding="utf-8-sig")
        match = re.search(r"'linear-srgb' = @\{\s+sha256 = '([0-9A-F]{64})'\s+payload = '([^']+)'",
                          collector)
        self.assertIsNotNone(match)
        profile = zlib.decompress(base64.b64decode(match[2], validate=True))
        self.assertEqual(hashlib.sha256(profile).hexdigest().upper(), match[1])
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "linear.png"
            with Image.new("RGB", (512, 1)) as image:
                image.putdata([(20, 138, 20), (225, 48, 48)] * 256)
                image.save(path, icc_profile=profile)
                raw = sync["prepare_opaque_wallpaper_bitmap"](image.tobytes(), image.width, image.height)
            # The two exact RGB outputs are from the existing full-domain
            # native control. Conversion must precede resampling.
            expected = sync["prepare_opaque_wallpaper_bitmap"](
                bytes((79, 195, 79, 242, 120, 120)) * 256, 512, 1)
            self.assertNotEqual(expected, raw)
            before = path.read_bytes()
            self.assertEqual(decode(path), expected)
            self.assertEqual(path.read_bytes(), before)
            for mode in ("RGB", "RGBA"):
                invalid = Path(tmp) / (mode + ".png")
                with Image.new(mode, (1, 1)) as image:
                    image.save(invalid, icc_profile=b"invalid ICC")
                with self.assertRaisesRegex(ValueError, "reviewed RGB8 ICC transform"):
                    decode(invalid)

    def test_native_rgb8_replay_and_preconversion(self):
        native = runpy.run_path(str(ROOT / "scripts/theme/wallpaper-icc.py"))
        # A synthetic grid exercises scalar tetrahedral interpolation
        # independently of the private measured device-link payload.
        source = tuple(i * 257 for i in range(256)) * 3
        grid = tuple(value for r in range(32) for g in range(32) for b in range(32)
                     for value in (r * 2048, g * 2048, b * 2048))
        target = tuple(i * 64 for i in range(1024)) * 3
        replay = native["Rgb8Replay"]((source, grid, target))
        self.assertEqual(native["coordinate"](0), (0, 0))
        self.assertEqual(native["coordinate"](65535), (30, 2048))
        self.assertEqual(replay.convert(0, 0, 0), (0, 0, 0))
        self.assertEqual(replay.convert(255, 0, 255), (248, 0, 248))
        self.assertEqual(replay.convert(64, 128, 192), (62, 124, 186))
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        pixels = bytes((20, 138, 20, 225, 48, 48)) * 256
        transform = lambda r, g, b: (0, 0, 0) if r == 20 else (255, 255, 255)
        self.assertEqual(sync["_prepare_wallpaper_bitmap"](pixels, 512, 1, 3, transform),
                         (256, 1, bytes((127, 127, 127, 255)) * 256))
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "icc-replay-v2.bin"
            self.assertIsNone(native["read_full_bundle"](path))
            path.write_bytes(b"not a verified link")
            with self.assertRaisesRegex(ValueError, "header"):
                native["read_full_bundle"](path)

    def test_generated_gray_tables_and_wallpaper_conversion(self):
        native = runpy.run_path(str(ROOT / "scripts/theme/wallpaper-icc.py"))
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        precision = (ROOT / "scripts/capture-windows-icc-precision.ps1").read_text(encoding="utf-8-sig")
        expected = {
            "gray-linear": "B5643195AD00E72793FDDB40ADABA26617B894B24817C31149537AEE7B6065AF",
            "gray-gamma22": "C3A571A6A7E554745A5417B4785F2C587053E998917BB0ED6D797B79380D1CB8",
        }
        from PIL import Image
        for name, output_sha in expected.items():
            with self.subTest(profile=name):
                match = re.search(r"'" + name + r"' = @\{sha256='([0-9A-F]{64})'; base64='([^']+)'", precision)
                self.assertIsNotNone(match)
                profile = base64.b64decode(match[2], validate=True)
                self.assertEqual(hashlib.sha256(profile).hexdigest().upper(), match[1])
                tables = native["generate_gray_tables"](profile)
                self.assertEqual(tuple(map(len, tables)), (256, 384, 3072))
                self.assertEqual(tuple(map(native["_table_hash"], tables)),
                                 (native["GRAY_SOURCE_SHA"][match[1]], native["GRAY_GRID_SHA"],
                                  native["GENERATED_OUTPUT_SHA"]))
                convert = native["transform_for_profile"](profile)
                rgb = bytes(v for code in range(256) for v in convert(code))
                self.assertEqual(hashlib.sha256(rgb).hexdigest().upper(), output_sha)
                with tempfile.TemporaryDirectory() as tmp:
                    path = Path(tmp) / "gray.png"
                    with Image.frombytes("L", (512, 1), bytes(range(256)) * 2) as image:
                        image.save(path, icc_profile=profile)
                    self.assertEqual(sync["decode_wallpaper_bitmap"](path),
                                     sync["prepare_opaque_wallpaper_bitmap"](rgb * 2, 512, 1))
                    with Image.new("RGB", (1, 1)) as image:
                        image.save(path, icc_profile=profile)
                    with self.assertRaisesRegex(ValueError, "Gray ICC"):
                        sync["decode_wallpaper_bitmap"](path)
                    # Opaque LA must not be treated as an RGB ICC input.
                    with Image.frombytes("LA", (512, 1),
                                         bytes(v for code in list(range(256)) * 2
                                               for v in (code, 255))) as image:
                        image.save(path, icc_profile=profile)
                    self.assertEqual(sync["decode_wallpaper_bitmap"](path),
                                     sync["prepare_opaque_wallpaper_bitmap"](rgb * 2, 512, 1))
                    # Exercise the composed gray/alpha candidate, including
                    # hidden colors, fractional coverage and mixed taps.
                    # These are shared-path invariants, not native WIC
                    # gray-alpha measurement claims.
                    gray_alpha = bytes(v for code in list(range(256)) * 2
                                       for v in (code, (code * 3) % 256))
                    converted_rgba = bytes(v for gray, alpha in zip(gray_alpha[::2], gray_alpha[1::2])
                                           for v in (*convert(gray), alpha))
                    with Image.frombytes("LA", (512, 1), gray_alpha) as image:
                        image.save(path, icc_profile=profile)
                    expected = sync["_prepare_wallpaper_bitmap"](
                        converted_rgba, 512, 1, 4, lambda r, g, b: (r, g, b))
                    self.assertEqual(sync["decode_wallpaper_bitmap"](path), expected)
                    # The indexed transparency key must remain single
                    # channel until after the ICC transform.
                    with Image.frombytes("L", (2, 1), bytes((128, 129))) as image:
                        image.save(path, icc_profile=profile, transparency=128)
                    self.assertEqual(sync["decode_wallpaper_bitmap"](path),
                                     (2, 1, bytes(4) + bytes((*reversed(convert(129)), 255))))

    def test_gray_profile_uses_shared_curve_dispatcher(self):
        native = runpy.run_path(str(ROOT / "scripts/theme/wallpaper-icc.py"))
        # Minimal synthetic D50 monitor profiles. Verify common curve/grid
        # dispatch and version restrictions, not new native output hashes.
        def profile(version, curve):
            header = bytearray(128)
            header[8] = version
            header[12:24] = b"mntrGRAYXYZ "
            header[36:40] = b"acsp"
            struct.pack_into(">3i", header, 68, *native["D50"])
            white = b"XYZ " + bytes(4) + struct.pack(">3i", *native["D50"])
            directory = struct.pack(">I4sII4sII", 2, b"wtpt", 156, len(white),
                                    b"kTRC", 176, len(curve))
            payload = header + directory + white + curve
            struct.pack_into(">I", payload, 0, len(payload))
            return bytes(payload)

        curves = [b"curv" + bytes(8),
                  b"curv" + bytes(4) + struct.pack(">I3H", 3, 0, 24576, 65535),
                  b"para" + bytes(8) + struct.pack(">i", 65536)]
        for version, curve in ((2, curves[0]), (2, curves[1]),
                               (4, curves[1]), (4, curves[2])):
            with self.subTest(version=version, curve=curve[:4]):
                data = profile(version, curve)
                tables = native["generate_gray_tables"](data)
                self.assertEqual(tables[0], native["matrix_input_curve"](curve))
                self.assertEqual(tables[1], native["build_gray_grid"]())
                self.assertEqual(tables[2], native["srgb_output_curve"]())
                self.assertIsNotNone(native["transform_for_profile"](data))
        self.assertIsNone(native["transform_for_profile"](profile(2, curves[2])))
        self.assertIsNone(native["transform_for_profile"](
            profile(4, b"curv" + bytes(4) + struct.pack(">I2H", 2, 65535, 0))))

    def test_native_sampled_curve_bounds(self):
        native = runpy.run_path(str(ROOT / "scripts/theme/wallpaper-icc.py"))
        curve = native["matrix_input_curve"]
        # Formula-level boundaries reconstructed from the native routine;
        # these are not additional Windows measurements.
        expected = {0: (0, 257, 32896, 65535), 2: (0, 258, 32895, 65535),
                    3: (0, 257, 32895, 65534), 256: (0, 257, 32896, 65535),
                    1024: (0, 257, 32895, 65534), 8191: (0, 257, 32895, 65534)}
        for count, endpoints in expected.items():
            values = [i * 65535 // (count - 1) for i in range(count)] if count else []
            tag = b"curv" + bytes(4) + struct.pack(">I", count) + struct.pack(f">{count}H", *values)
            generated = curve(tag)
            self.assertEqual(tuple(generated[i] for i in (0, 1, 128, 255)), endpoints)
        with self.assertRaises(native["UnsupportedMatrixProfile"]):
            curve(b"curv" + bytes(4) + struct.pack(">I", 8192) + bytes(8192 * 2))

    def test_shared_mft2_bridge_curves(self):
        native = runpy.run_path(str(ROOT / "scripts/theme/wallpaper-icc.py"))
        precision = (ROOT / "scripts/capture-windows-icc-precision.ps1").read_text(encoding="utf-8-sig")
        for digest in ("D32E4F221D8FBA508546D930EC200C200AEAAAE95EA22E23331B68D3495BF1A4",
                       "086832DEE2195FBFC5FAF48A48C30CF2301D70CBA9C92CA46C11E6257C5DBB18"):
            encoded = re.search(r"'" + digest + r"' = '([^']+)'", precision)
            self.assertIsNotNone(encoded)
            profile = base64.b64decode(encoded[1], validate=True)
            self.assertEqual(hashlib.sha256(profile).hexdigest().upper(), digest)
            tags = native["icc_tag_directory"](profile)
            source, target = native["mft2_bridge_curves"](tags[b"A2B0"])
            self.assertEqual((len(source), len(target)), (768, 3072))
            self.assertEqual(source, native["matrix_input_curve"](
                b"curv" + bytes(4) + struct.pack(">I2H", 2, 0, 65535)) * 3)
            self.assertEqual(native["_table_hash"](source),
                             "6C61F33985621A47ACF0628A58E168E4A1215FE3BE5369CDDE2E1F4A94919605")
            self.assertEqual(native["_table_hash"](target),
                             "4404EC04FB9473830A5F4F24502FF3144BF7ACD7DCE6629803F26BCE890DC517")
            self.assertEqual((target[0], target[1023]), (0, 65535))
            with self.assertRaises(ValueError):
                native["mft2_bridge_curves"](tags[b"A2B0"][:-2])

    def test_incomplete_jpeg_icc_does_not_use_untagged_rgb(self):
        from PIL import Image
        decode = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))["decode_wallpaper_bitmap"]
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "incomplete.jpg"
            with Image.new("RGB", (2, 2)) as image:
                image.save(path, icc_profile=b"fragment")
            data = path.read_bytes()
            marker = b"ICC_PROFILE\0\x01"
            self.assertIn(marker + b"\x01fragment", data)
            path.write_bytes(data.replace(marker + b"\x01fragment", marker + b"\x02fragment", 1))
            with self.assertRaisesRegex(ValueError, "Unreadable embedded"):
                decode(path)

    def test_generated_matrix_tables_without_native_files(self):
        native = runpy.run_path(str(ROOT / "scripts/theme/wallpaper-icc.py"))
        collector = (ROOT / "scripts/capture-windows-wallpaper-probes.ps1").read_text(encoding="utf-8-sig")
        precision = (ROOT / "scripts/capture-windows-icc-precision.ps1").read_text(encoding="utf-8-sig")
        profiles = {}
        for name, digest, _ in native["PROFILES"]:
            match = re.search(r"'" + re.escape(name) + r"' = @\{\s+sha256 = '([0-9A-F]{64})'\s+payload = '([^']+)'",
                              collector)
            self.assertIsNotNone(match)
            self.assertEqual(match[1], digest)
            profiles[digest] = zlib.decompress(base64.b64decode(match[2], validate=True))
        for digest in set(native["GENERATED_SOURCE_SHA"]) - set(profiles):
            match = re.search(r"'" + re.escape(digest) + r"' = '([^']+)'", precision)
            self.assertIsNotNone(match)
            profiles[digest] = base64.b64decode(match[1], validate=True)
        select = native["transform_for_profile"]
        with patch.dict(select.__globals__, {"read_full_bundle": lambda: None}):
            for digest, profile in profiles.items():
                with self.subTest(profile=digest):
                    self.assertEqual(hashlib.sha256(profile).hexdigest().upper(), digest)
                    tables = native["generate_matrix_tables"](profile)
                    self.assertEqual(tuple(map(len, tables)), (768, 98304, 3072))
                    self.assertEqual(tuple(map(native["_table_hash"], tables)),
                                     (native["GENERATED_SOURCE_SHA"][digest],
                                      native["GENERATED_GRID_SHA"], native["GENERATED_OUTPUT_SHA"]))
                    transform = select(profile)
                    self.assertIsNotNone(transform)
                    self.assertEqual(transform(225, 48, 48), native["Rgb8Replay"](tables).convert(225, 48, 48))
                    # An unrelated creator signature must not affect generation.
                    alternate = profile[:80] + b"TEST" + profile[84:]
                    self.assertEqual(native["generate_matrix_tables"](alternate), tables)
                    # A device-link profile must never enter the matrix branch.
                    self.assertIsNone(select(profile[:12] + b"link" + profile[16:]))
            self.assertIsNone(select(b"invalid ICC"))
            srgb = profiles[native["PROFILES"][0][1]]
            linear = profiles[native["PROFILES"][1][1]]
            self.assertEqual(select(srgb)(225, 48, 48), (225, 47, 47))
            self.assertEqual(select(linear)(225, 48, 48), (242, 120, 120))
            # Replace the optional chad directory entry with an actual mft2
            # control from the PCS capture. Only its direction now differs.
            lut_digest = "D32E4F221D8FBA508546D930EC200C200AEAAAE95EA22E23331B68D3495BF1A4"
            encoded = re.search(r"'" + lut_digest + r"' = '([^']+)'", precision)
            self.assertIsNotNone(encoded)
            control = base64.b64decode(encoded[1], validate=True)

            def entry(profile, key):
                count = struct.unpack_from(">I", profile, 128)[0]
                return next(i for i in range(132, 132 + 12 * count, 12) if profile[i:i + 4] == key)

            start, length = struct.unpack_from(">II", control, entry(control, b"B2A0") + 4)
            mixed = bytearray(linear + control[start:start + length])
            struct.pack_into(">I", mixed, 0, len(mixed))
            directory = entry(linear, b"chad")
            struct.pack_into(">4sII", mixed, directory, b"B2A1", len(linear), length)
            for profile_class in (b"mntr", b"scnr"):
                mixed[12:16] = profile_class
                self.assertEqual(native["generate_matrix_tables"](bytes(mixed)),
                                 native["generate_matrix_tables"](linear))
            for tag in (b"A2B0", b"A2B1"):
                mixed[directory:directory + 4] = tag
                self.assertIsNone(select(bytes(mixed)))

    def test_full_domain_icc_bundle_selection(self):
        native = runpy.run_path(str(ROOT / "scripts/theme/wallpaper-icc.py"))
        # This synthetic receipt exercises storage and selection only. The
        # full-domain Windows import still requires real reference hashes.
        profile = b"synthetic profile identity"
        digest = hashlib.sha256(profile).digest()
        header = native["FULL_MAGIC"] + bytes.fromhex(native["TARGET_SHA"]) + bytes((1,))
        packed = bytes(native["TABLE_SIZE"])
        entry = digest + bytes(32) + packed
        body = header + entry
        receipt = body + hashlib.sha256(body).digest()
        self.assertEqual(native["full_bundle_entries"](receipt),
                         {digest.hex().upper(): (bytes(32), packed)})
        with self.assertRaisesRegex(ValueError, "integrity"):
            native["full_bundle_entries"](receipt[:-1] + bytes((receipt[-1] ^ 1,)))
        duplicate = header[:-1] + bytes((2,)) + entry + entry
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            native["full_bundle_entries"](duplicate + hashlib.sha256(duplicate).digest())
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "icc-replay-v2.bin"
            path.write_bytes(receipt)
            with patch.dict(native["transform_for_profile"].__globals__, {
                    "full_bundle_path": lambda: path}):
                self.assertEqual(native["read_full_bundle"](), receipt)
                self.assertEqual(native["transform_for_profile"](profile)(255, 12, 88), (0, 0, 0))
                self.assertIsNone(native["transform_for_profile"](b"different source"))
                self.assertIsNotNone(native["reference_identity"]())
                path.unlink()
                self.assertIsNone(native["reference_identity"]())
                self.assertIsNone(native["transform_for_profile"](profile))

    def test_all_live_scheme_roles_are_verified(self):
        control = runpy.run_path(str(ROOT / "scripts/theme/accent-control.py"))
        template, fixed = control["scheme_inputs"]()
        palette = control["SYNC"]["derive_manual_palette"]("#FF8C00")
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp)
            scheme = config / "WindowsModernDark.colors"
            expected = control["render"](template, fixed, "dark", palette)
            scheme.write_bytes(expected)
            live = config / "kdeglobals"
            live.write_bytes(expected)
            digest = hashlib.sha1(expected).hexdigest()
            verify = control["live_matches"]
            with patch.dict(verify.__globals__, {"CONFIG": config, "read": lambda *args: digest}):
                self.assertTrue(verify(scheme, template, fixed, "dark", palette))
                for section, key in (("Colors:View", "DecorationFocus"),
                                     ("Colors:Tooltip", "ForegroundActive"),
                                     ("Colors:Selection", "ForegroundActive"),
                                     ("Colors:Button", "BackgroundNormal"),
                                     ("WM", "inactiveForeground")):
                    parser = control["parse_colors"](expected)
                    parser.set(section, key, "1,2,3")
                    with live.open("w", encoding="utf-8") as stream:
                        parser.write(stream)
                    self.assertFalse(verify(scheme, template, fixed, "dark", palette))
                # An edited source and a matching edited live scheme must
                # not be accepted as the requested Windows palette.
                changed = expected.replace(b"DecorationFocus=255,182,52", b"DecorationFocus=1,2,3")
                self.assertNotEqual(changed, expected)
                scheme.write_bytes(changed)
                live.write_bytes(changed)
                self.assertFalse(verify(scheme, template, fixed, "dark", palette))

    def test_windows_icc_profile_boundary(self):
        report = json.loads((ROOT / "docs/windows11-26h2-wallpaper-probes-decode-profile.json").read_text(
            encoding="utf-8-sig"))
        self.assertEqual(report["probe_set"], "DecodeProfile")
        self.assertEqual(report["baseline"]["windows_build"], "26300.9974")
        self.assertTrue(report["restoration"]["wallpaper_path_verified"])
        self.assertTrue(report["restoration"]["palette_matches_baseline"])
        observations = {}
        for sample in report["samples"]:
            probe, observation = sample["image"], sample["observation"]
            capture = observation["capture"]
            native = capture["native_wallpaper_color_api"]
            boundary = observation["wic_boundary"]
            with self.subTest(profile=probe["icc_profile"]):
                self.assertTrue(observation["registered_source_matches"])
                self.assertTrue(observation["native_argb_changed_from_reference"])
                self.assertTrue(probe["pixel_validation"]["decoded_bgra_matches"])
                self.assertTrue(native["argb_matches_image_color"])
                self.assertTrue(native["rgb_matches_dwm_colorization"])
                self.assertEqual(boundary["transcoded_status"], "matched-controlled-opaque-regions")
                self.assertEqual(boundary["source"]["source_sha256"],
                                 capture["appearance"]["registered_wallpaper_sha256"])
                self.assertEqual(boundary["transcoded"]["source_sha256"],
                                 observation["cache_observation"]["transcoded"]["sha256"])
                buffers = {}
                for kind in ("source", "transcoded"):
                    item = boundary[kind]
                    self.assertEqual((item["width"], item["height"]), (256, 256))
                    self.assertEqual(item["order"], "top-down BGRX")
                    data = gzip.decompress(base64.b64decode(item["gzip_base64"], validate=True))
                    self.assertEqual(len(data), 256 * 256 * 4)
                    self.assertEqual(hashlib.sha256(data).hexdigest().upper(), item["bitmap_sha256"])
                    self.assertEqual(set(data[3::4]), {255})
                    buffers[kind] = data
                observations[probe["icc_profile"]] = (buffers, native["argb"])
        self.assertEqual(set(observations), {"none", "srgb", "linear-srgb"})
        untagged, native = observations["none"]
        srgb, srgb_native = observations["srgb"]
        linear, linear_native = observations["linear-srgb"]
        self.assertEqual(untagged["source"], untagged["transcoded"])
        self.assertEqual(untagged["source"], srgb["source"])
        self.assertEqual(untagged["source"], linear["source"])
        self.assertNotEqual(untagged["transcoded"], srgb["transcoded"])
        self.assertNotEqual(untagged["transcoded"], linear["transcoded"])
        self.assertEqual((native, srgb_native, linear_native),
                         ("0xAFD44343", "0xAFD24444", "0xAFD44343"))


    def test_native_icc_transform_calibration_matches_cache(self):
        try:
            from PIL import ImageCms
        except ImportError:
            self.skipTest("optional Pillow ImageCms unavailable")
        diagnostic = runpy.run_path(str(ROOT / "scripts/theme/analyze-wallpaper-icc.py"))
        fixture = json.loads((ROOT / "docs/windows11-26h2-icc-native-matches.json").read_text(encoding="utf-8"))
        samples, _, prepare, rows, layout, colors, _, _, references = diagnostic["reference_data"](ROOT)
        self.assertEqual(fixture["windows_build"], "26300.9974")
        self.assertEqual(fixture["color_count"], len(colors))
        self.assertEqual(diagnostic["sha"](b"".join(map(bytes, colors))), fixture["input_rgb_sha256"])
        self.assertEqual({item["source"] for item in fixture["samples"]}, {"srgb", "linear-srgb"})
        for item in fixture["samples"]:
            source = item["source"]
            with self.subTest(source=source):
                self.assertEqual(item["source_icc_sha256"],
                                 samples[source]["image"]["pixel_validation"]["icc_profile_sha256"])
                output = gzip.decompress(base64.b64decode(item["output_rgb_gzip_base64"], validate=True))
                self.assertEqual(len(output), len(colors) * 3)
                self.assertEqual(diagnostic["sha"](output), item["output_rgb_sha256"])
                mapping = {color: output[3*i:3*i+3] for i, color in enumerate(colors)}
                prepared = diagnostic["bitmap"](rows, layout, mapping, prepare)
                self.assertEqual(diagnostic["sha"](prepared), item["bitmap_sha256"])
                self.assertEqual(prepared, references[source])

    def test_wallpaper_file_to_reference_palette(self):
        try:
            from PIL import Image
        except ImportError:
            self.skipTest("optional Pillow unavailable")
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        analyze = sync["analyze_wallpapers"]
        report = json.loads((ROOT / "docs/windows11-26h2-wallpaper-probes-cache-isolation.json").read_text(
            encoding="utf-8"))
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            count = 0
            for sample in report["samples"]:
                if sample["image"]["rectangle"] is not None:
                    continue
                observation = sample["observation"]
                capture = observation["capture"]
                pixel = tuple(bytes.fromhex(
                    observation["cache_observation"]["transcoded"]["background_rgb"][1:]))
                # Preserve the sampled decoded RGB in a lossless local file.
                # These are synthetic uniform inputs, not native JPEG bytes.
                path = root / (sample["image"]["name"] + ".bmp")
                with Image.new("RGB", (1, 1), pixel) as image:
                    image.save(path)
                with self.subTest(name=sample["image"]["name"]):
                    result = analyze([path])
                    expected = {role: "#" + capture["appearance"]["colors_argb"][role][3:]
                                for role in ("Accent", *sync["PRESET_SHADE_ROLES"])}
                    self.assertEqual(result["colorization_argb"],
                                     capture["native_wallpaper_color_api"]["argb"])
                    self.assertEqual(result["palette"], expected)
                    self.assertEqual(result["mode_accents"],
                                     {"dark": expected["AccentLight2"], "light": expected["AccentDark1"]})
                count += 1
            self.assertEqual(count, 7)
            with self.assertRaises(ValueError):
                analyze([])
            # File decoding must preserve the existing multi-image
            # statistics reduction, not average independently chosen colors.
            red = root / "red.bmp"
            cyan = root / "cyan.bmp"
            for path, size, color in ((red, (40, 1), (188, 88, 88)),
                                      (cyan, (60, 1), (32, 132, 132))):
                with Image.new("RGB", size, color) as image:
                    image.save(path)
            self.assertEqual(analyze([red, cyan])["colorization_argb"], "0xAFD44343")

    def test_bounded_tint(self):
        self.assertEqual(frames.tint_color('dark', (0, 0, 0)), '#1D1D1D')
        self.assertEqual(frames.tint_color('dark', (255, 255, 255)), '#363636')
        self.assertEqual(frames.tint_color('light', (0, 0, 0)), '#EAEAEA')
        self.assertEqual(frames.tint_color('light', (255, 255, 255)), '#F9F9F9')

    def test_active_and_inactive_aurorae(self):
        for mode in ('light', 'dark'):
            with self.subTest(mode=mode):
                baseline = elements(frames.render(mode))
                tinted = elements(frames.render(mode, '#123456'))
                self.assertEqual(baseline.keys(), tinted.keys())
                self.assertEqual(tinted['decoration-center'][0].get('fill'), '#123456')
                self.assertEqual(tinted['decoration-maximized-center'].get('fill'), '#123456')
                self.assertEqual(tinted['decoration-inactive-center'][0].get('fill'), 'currentColor')
                self.assertEqual(tinted['decoration-maximized-inactive-center'].get('fill'), 'currentColor')
                self.assertEqual(ET.tostring(baseline['decoration-inactive-top']),
                                 ET.tostring(tinted['decoration-inactive-top']))

    def test_kvantum_preserves_popups(self):
        result = frames.patch_window_svg(SVG, '#123456', '#202020')
        nodes = elements(result)
        self.assertEqual(nodes['window-normal'].get('fill'), '#123456')
        self.assertEqual(nodes['window-normal'].get('opacity'), '1')
        self.assertEqual(nodes['window-normal-inactive'].get('fill'), '#202020')
        self.assertEqual(nodes['window-normal-inactive'].get('opacity'), '1')
        self.assertEqual(ET.tostring(nodes['menu-normal']), ET.tostring(elements(SVG)['menu-normal']))
        self.assertEqual(frames.patch_window_svg(result, '#123456', '#202020'), result)

    def test_real_window_and_toolbar_have_shared_opaque_tint(self):
        for mode in ('light', 'dark'):
            source = render_kvantum_svg(ROOT, mode)
            patched = frames.patch_window_svg(source, '#345678', '#202020')
            self.assertEqual(frames.patch_window_svg(patched, '#345678', '#202020'), patched)
            nodes = elements(patched)
            for role, color in (('menubar-normal', '#345678'), ('menubar-normal-inactive', '#202020')):
                for part in ('', '-left', '-right', '-top', '-topleft', '-topright',
                             '-bottom', '-bottomleft', '-bottomright'):
                    node = nodes[role + part]
                    surface = node[0] if part.startswith('-bottom') else node
                    self.assertEqual(surface.get('fill'), color)
                    self.assertIn(surface.get('opacity', '1'), ('1', '1.0'))
            self.assertEqual(ET.tostring(nodes['menu-normal']),
                             ET.tostring(elements(source)['menu-normal']))

    def test_real_kvantum_menu_slices(self):
        for mode, color, border in (('light', '#F9F9F9', '#DADADA'),
                                    ('dark', '#2C2C2C', '#454545')):
            with self.subTest(mode=mode):
                svg = elements(render_kvantum_svg(ROOT, mode))
                self.assertEqual(svg['menu-normal'].get('fill'), color)
                self.assertEqual(svg['menu-normal'].get('opacity'), '.98')
                for part in ('top', 'bottom', 'left', 'right', 'topleft', 'topright',
                             'bottomleft', 'bottomright'):
                    item = svg['menu-normal-' + part]
                    self.assertEqual(len(item), 2)
                    self.assertEqual([x.get('fill') for x in item], [border, color])
                    self.assertTrue(all(x.get('opacity') == '.98' for x in item))
                config = render_kvantum_config(ROOT, mode)
                menu = config.split('[Menu]\n', 1)[1].split('[MenuItem]', 1)[0]
                for side in ('top', 'bottom', 'left', 'right'):
                    self.assertIn('frame.' + side + '=8', menu)
                items = config.split('[MenuItem]\n', 1)[1].split('[MenuBar]', 1)[0]
                self.assertIn('text.margin.top=3', items)
                self.assertIn('text.margin.bottom=3', items)

    def test_kvantum_shared_artwork_geometry_and_states(self):
        paint = {'fill', 'stroke', 'opacity', 'fill-opacity', 'stroke-opacity',
                 'stop-color', 'stop-opacity'}

        def geometry(svg):
            return [(node.tag, {key: value for key, value in node.attrib.items()
                               if key not in paint}, len(node))
                    for node in ET.fromstring(svg).iter()]

        dark = render_kvantum_svg(ROOT, 'dark')
        light = render_kvantum_svg(ROOT, 'light')
        self.assertEqual(geometry(dark), geometry(light))
        for mode, svg, accent, backing in (
                ('dark', dark, '#4CC2FF', '#FFFFFF'),
                ('light', light, '#0067C0', 'none')):
            with self.subTest(mode=mode):
                nodes = elements(svg)
                self.assertEqual(len(nodes), sum(1 for node in ET.fromstring(svg).iter()
                                                 if node.get('id')))
                for prefix in ('', 'menu-'):
                    for kind in ('checkbox-checked', 'checkbox-tristate', 'radio-checked'):
                        for state in ('normal', 'focused'):
                            item = nodes[prefix + kind + '-' + state]
                            self.assertEqual(item[1].get('fill'), backing)
                            self.assertEqual(item[2].get('fill'), accent)
                            if state == 'focused':
                                self.assertEqual(item[3].get('opacity'), '.15')
                for prefix in ('slidercursor-', 'slidercursor-tickless-'):
                    for state in ('normal', 'pressed', 'focused', 'disabled'):
                        item = nodes[prefix + state]
                        ring = next(child for child in item if child.get('r') == '7')
                        self.assertEqual(ring.get('stroke-width'), '1')
                        self.assertEqual(ring.get('stroke'),
                                         'none' if mode == 'dark' else '#D5D5D5')

    def test_shared_system_palette(self):
        def rgb(hex_color):
            return ','.join(str(int(hex_color[i:i + 2], 16)) for i in (1, 3, 5))

        reference = json.loads((ROOT / "docs/windows11-26h2-accent-captures.json").read_text(
            encoding="utf-8"))
        captured = reference["captures"]
        roles = reference["winui_roles"]
        blue_palettes = {}
        for name, sample in captured.items():
            appearance = sample["appearance"]
            mode = "light" if appearance["apps_use_light_theme"] else "dark"
            colors = appearance["colors_argb"]
            settings_mode = sample["verified_settings_mode"]
            self.assertIn(settings_mode, ("Manual", "Automatic"))
            if settings_mode == "Manual":
                self.assertEqual(sample["manual_color_observed_from_ui_settings"],
                                 colors["Accent"])
            else:
                self.assertIsNone(sample["manual_color_observed_from_ui_settings"])
            if sample["script_schema_version"] >= 2:
                self.assertEqual(sample["accent_mode_registry"], settings_mode)
                self.assertFalse(sample["accent_mode_registry_conflict"])
                self.assertEqual(sample["accent_observed_from_ui_settings"], colors["Accent"])
            for role in ("Accent", "AccentDark1", "AccentDark2", "AccentDark3",
                         "AccentLight1", "AccentLight2", "AccentLight3"):
                self.assertRegex(colors[role], r"^#FF[0-9A-F]{6}$")
            primary_fill = roles[mode]["primary_fill"]
            self.assertRegex(colors[primary_fill], r"^#FF[0-9A-F]{6}$")
            if name.startswith("manual_blue_"):
                blue_palettes[mode] = [colors[role] for role in
                    ("Accent", "AccentDark1", "AccentDark2", "AccentDark3",
                     "AccentLight1", "AccentLight2", "AccentLight3")]
        self.assertEqual(blue_palettes["dark"], blue_palettes["light"])
        orange = captured["manual_orange_light"]["appearance"]["colors_argb"]
        self.assertEqual(orange["Accent"], "#FFFF8C00")
        self.assertEqual(orange[roles["light"]["primary_fill"]], "#FFE37700")

        registry_sample = captured["manual_orange_light_registry"]
        registry_appearance = registry_sample["appearance"]
        registry = registry_appearance["registry"]
        observation = reference["registry_palette_observation"]
        self.assertEqual(registry_sample["accent_mode_registry"], "Manual")
        self.assertFalse(registry_sample["accent_mode_registry_conflict"])
        self.assertEqual(registry["themes_history_auto_color_raw"], 0)
        self.assertEqual(registry_appearance["colors_argb"], orange)
        raw = bytes.fromhex(registry["accent_palette_hex"])
        self.assertEqual(len(raw), registry["accent_palette_length_bytes"])
        self.assertEqual(len(raw), 32)
        self.assertEqual(observation["slot_size_bytes"], 4)
        self.assertEqual(observation["slot_count"], 8)
        order = ("AccentLight3", "AccentLight2", "AccentLight1", "Accent",
                 "AccentDark1", "AccentDark2", "AccentDark3")
        self.assertEqual(observation["ui_settings_roles_in_slot_order"], list(order))
        for index, role in enumerate(order):
            slot = raw[index * 4:index * 4 + 4]
            self.assertEqual("#FF" + slot[:3].hex().upper(), orange[role])
            self.assertEqual(slot[3], 0)
        # Preserve the unknown eighth slot without treating it as an accent role.
        self.assertEqual(observation["unassigned_slot_index"], 7)
        self.assertEqual("#" + raw[28:31].hex().upper(),
                         observation["unassigned_slot_rgb"])
        self.assertEqual(raw[31], 0)
        self.assertEqual(registry["dwm_accent_color_raw"] & 0xFFFFFFFF, 0xFF008CFF)
        self.assertEqual(registry["explorer_accent_color_menu_raw"] & 0xFFFFFFFF,
                         0xFF008CFF)
        self.assertEqual(registry["explorer_start_color_menu_raw"] & 0xFFFFFFFF,
                         0xFF0077E3)
        self.assertEqual(registry["dwm_colorization_color_raw"] & 0xFFFFFFFF,
                         0xC4FF8C00)

        automatic_sample = captured[observation["automatic_capture"]]
        automatic_appearance = automatic_sample["appearance"]
        automatic_registry = automatic_appearance["registry"]
        automatic_colors = automatic_appearance["colors_argb"]
        self.assertEqual(automatic_sample["accent_mode_registry"], "Automatic")
        self.assertEqual(automatic_registry["control_panel_auto_colorization_raw"], 1)
        self.assertEqual(automatic_registry["themes_history_auto_color_raw"], 1)
        self.assertEqual(automatic_colors["Accent"], "#FF2475CE")
        for key in ("registered_wallpaper_sha256", "wallpaper_style_raw",
                    "tile_wallpaper_raw", "reported_display_width",
                    "reported_display_height"):
            self.assertEqual(automatic_appearance[key], registry_appearance[key])
        self.assertIsNone(automatic_appearance["source_wallpaper_sha256"])
        raw_auto = bytes.fromhex(automatic_registry["accent_palette_hex"])
        self.assertEqual(len(raw_auto), automatic_registry["accent_palette_length_bytes"])
        self.assertEqual(len(raw_auto), 32)
        for index, role in enumerate(order):
            slot = raw_auto[index * 4:index * 4 + 4]
            self.assertEqual("#FF" + slot[:3].hex().upper(), automatic_colors[role])
            self.assertEqual(slot[3], 0)
        self.assertEqual("#" + raw_auto[28:31].hex().upper(),
                         observation["automatic_unassigned_slot_rgb"])
        self.assertEqual(raw_auto[31], 0)
        self.assertEqual(automatic_registry["explorer_accent_color_menu_raw"] & 0xFFFFFFFF,
                         0xFFCE7524)
        self.assertEqual(automatic_registry["explorer_start_color_menu_raw"] & 0xFFFFFFFF,
                         0xFFB25C1C)
        # Automatic mode updates Explorer and UISettings but not these DWM
        # values in the measured transition. Keep the distinction explicit.
        for key in ("dwm_accent_color_raw", "dwm_colorization_color_raw"):
            self.assertEqual(automatic_registry[key], registry[key])
        self.assertNotEqual(automatic_registry["dwm_accent_color_raw"],
                            automatic_registry["explorer_accent_color_menu_raw"])

        schemes = {}
        for mode in ('dark', 'light'):
            with self.subTest(mode=mode):
                scheme = configparser.ConfigParser(interpolation=None)
                scheme.read_string(render_color_scheme(ROOT, mode))
                config = configparser.ConfigParser(interpolation=None)
                config.read_string(render_kvantum_config(ROOT, mode))
                colors = config['GeneralColors']
                # The default blue fill uses WinUI's theme-specific shade role.
                observed = captured["manual_blue_" + mode]["appearance"]["colors_argb"][
                    roles[mode]["primary_fill"]]
                self.assertRegex(observed, r"^#FF[0-9A-F]{6}$")
                observed_rgb = "#" + observed[3:]
                self.assertEqual(colors['highlight.color'].upper(), observed_rgb)
                self.assertEqual(scheme['Colors:Selection']['BackgroundNormal'], rgb(observed_rgb))
                for section, key, role in (
                        ('Colors:Window', 'BackgroundNormal', 'window.color'),
                        ('Colors:View', 'BackgroundNormal', 'base.color'),
                        ('Colors:Button', 'BackgroundNormal', 'button.color'),
                        ('Colors:Window', 'DecorationHover', 'light.color'),
                        ('Colors:Window', 'ForegroundNormal', 'text.color'),
                        ('Colors:Selection', 'BackgroundNormal', 'highlight.color'),
                        ('Colors:Selection', 'ForegroundNormal', 'highlight.text.color'),
                        ('ColorEffects:Disabled', 'Color', 'disabled.text.color')):
                    self.assertEqual(scheme[section][key], rgb(colors[role]))
                self.assertEqual(scheme['General']['ColorScheme'], 'WindowsModern' + mode.capitalize())
                self.assertEqual(scheme['WM']['activeBackground'], rgb(frames.BASE_COLORS[mode]))
                self.assertEqual(scheme['Colors:View']['ForegroundLink'],
                                 scheme['Colors:Selection']['BackgroundNormal'])
                schemes[mode] = [(section, tuple(scheme[section])) for section in scheme.sections()]
        self.assertEqual(schemes['dark'], schemes['light'])

    def test_qt_control_spacing_matches_both_themes(self):
        for mode in ('light', 'dark'):
            with self.subTest(mode=mode):
                config = render_kvantum_config(ROOT, mode)
                def section(name):
                    return dict(line.split('=', 1) for line in
                                config.split('[' + name + ']\n', 1)[1].split('\n[', 1)[0].splitlines()
                                if '=' in line and not line.startswith('#'))
                general = section('%General')
                self.assertEqual(general['scroll_min_extent'], '32')
                self.assertEqual(general['transient_groove'], 'false')
                self.assertEqual(general['tree_branch_line'], 'false')
                self.assertEqual(section('Hacks')['force_size_grip'], 'false')
                self.assertEqual(section('TitleBar')['text.italic'], 'false')
                slider = config.split('[Slider]\n', 1)[1].split('\n[', 1)[0].splitlines()
                for side in ('top', 'bottom', 'left', 'right'):
                    key = 'frame.' + side
                    self.assertEqual([line for line in slider if line.startswith(key + '=')],
                                     [key + '=2'])
                for control in ('LineEdit', 'ComboBox'):
                    values = section(control)
                    for side, size in (('top', '4'), ('bottom', '4'), ('left', '8'), ('right', '8')):
                        self.assertEqual(values['text.margin.' + side], size)

    def test_default_taskbar_layout_leaves_room_for_spacers(self):
        layouts = [
            'plasma/layout-templates/org.kde.windowsmodern.panel/contents/layout.js',
            'plasma/look-and-feel/org.kde.windowsmodern.dark/contents/layouts/org.kde.plasma.desktop-layout.js',
        ]
        for path in layouts:
            with self.subTest(path=path):
                script = (ROOT / path).read_text()
                self.assertEqual(script.count('tasks.writeConfig("fill", "false");'), 1)
                self.assertLess(script.index('var spacerLeft'), script.index('var tasks'))
                self.assertLess(script.index('tasks.writeConfig("fill", "false");'),
                                script.index('var spacerRight'))

    def test_missing_or_invalid_elements_rejected(self):
        with self.assertRaises(ValueError):
            frames.patch_window_svg(SVG.replace('window-normal-inactive', 'other'), '#123456', '#202020')
        with self.assertRaises(ValueError):
            frames.render('dark', 'invalid')

    def test_local_apply_and_solid_reset(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            aurorae = root / 'aurorae'
            kvantum = root / 'kvantum'
            kvantum.mkdir()
            for mode in ('light', 'dark'):
                deco = aurorae / f'windows-modern-{mode}-aurorae' / 'decoration.svg'
                deco.parent.mkdir(parents=True)
                deco.write_text(frames.render(mode))
                (kvantum / ('Windows-modernDark.svg' if mode == 'dark' else 'Windows-modern.svg')).write_text(SVG)
            with patch.object(frames, "wallpaper_tints", return_value=(dict.fromkeys(frames.BASE_COLORS, "#345678"), lambda: None)):
                frames.apply_local(aurorae, kvantum, root)
            for mode in ('light', 'dark'):
                deco = aurorae / f'windows-modern-{mode}-aurorae' / 'decoration.svg'
                self.assertEqual(elements(deco.read_text())['decoration-center'][0].get('fill'), '#345678')
            frames.apply_local(aurorae, kvantum)
            for mode, base in frames.BASE_COLORS.items():
                deco = aurorae / f'windows-modern-{mode}-aurorae' / 'decoration.svg'
                self.assertEqual(deco.read_text(), frames.render(mode))
                svg = kvantum / ('Windows-modernDark.svg' if mode == 'dark' else 'Windows-modern.svg')
                self.assertEqual(elements(svg.read_text())['window-normal'].get('fill'), base)

    def test_local_material_rejects_modified_frame_before_writing(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            aurorae, kvantum = root / "aurorae", root / "kvantum"
            kvantum.mkdir()
            paths = []
            for mode in ("light", "dark"):
                deco = aurorae / f"windows-modern-{mode}-aurorae" / "decoration.svg"
                deco.parent.mkdir(parents=True)
                deco.write_text(frames.render(mode))
                svg = kvantum / ("Windows-modernDark.svg" if mode == "dark" else "Windows-modern.svg")
                svg.write_text(SVG)
                paths.extend((deco, svg))
            paths[2].write_text(paths[2].read_text() + "<!-- user edit -->")
            before = {path: path.read_bytes() for path in paths}
            with patch.object(frames, "wallpaper_tints", return_value=(dict.fromkeys(frames.BASE_COLORS, "#345678"), lambda: None)):
                with self.assertRaises(ValueError):
                    frames.apply_local(aurorae, kvantum, root)
            self.assertEqual({path: path.read_bytes() for path in paths}, before)

    def test_local_material_rejects_symlink_and_preserves_permissions(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            aurorae, kvantum = root / "aurorae", root / "kvantum"
            kvantum.mkdir()
            deco = aurorae / "windows-modern-dark-aurorae" / "decoration.svg"
            deco.parent.mkdir(parents=True)
            deco.write_text(frames.render("dark"))
            deco.chmod(0o640)
            svg = kvantum / "Windows-modernDark.svg"
            external = root / "external.svg"
            external.write_text(SVG)
            svg.symlink_to(external)
            before = deco.read_bytes()
            with patch.object(frames, "wallpaper_tints", return_value=(dict.fromkeys(frames.BASE_COLORS, "#345678"), lambda: None)):
                with self.assertRaises(ValueError):
                    frames.apply_local(aurorae, kvantum, root)
                self.assertEqual(deco.read_bytes(), before)
                self.assertEqual(external.read_text(), SVG)
                svg.unlink()
                svg.write_text(SVG)
                frames.apply_local(aurorae, kvantum, root)
            self.assertEqual(deco.stat().st_mode & 0o777, 0o640)
            self.assertEqual(elements(deco.read_text())["decoration-center"][0].get("fill"), "#345678")

    def test_missing_wallpaper_fallback(self):
        self.assertEqual(frames.wallpaper_tints(None)[0], dict.fromkeys(frames.BASE_COLORS))
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(frames.wallpaper_tints(Path(tmp))[0], dict.fromkeys(frames.BASE_COLORS))

    def test_samples_separate_variants(self):
        try:
            from PIL import Image
        except ImportError:
            self.skipTest('optional Pillow unavailable')
        with tempfile.TemporaryDirectory() as tmp:
            package = Path(tmp)
            for folder, color in [('images', (255, 0, 0)), ('images_dark', (0, 0, 255))]:
                dest = package / 'contents' / folder / '64x64.png'
                dest.parent.mkdir(parents=True)
                Image.new('RGB', (64, 64), color).save(dest)
            colors, validate = frames.wallpaper_tints(package)
            self.assertEqual(colors['dark'], frames.tint_color('dark', (0, 0, 255)))
            self.assertEqual(colors['light'], frames.tint_color('light', (255, 0, 0)))
            (package / 'contents/images_dark/64x64.png').unlink()
            with self.assertRaises(ValueError):
                validate()
            self.assertEqual(frames.wallpaper_tints(package)[0]['dark'],
                             frames.tint_color('dark', (255, 0, 0)))

    def test_shared_wallpaper_sample_and_alpha(self):
        with tempfile.TemporaryDirectory() as tmp:
            image = Path(tmp) / "wallpaper.png"
            image.touch()
            # BGR/alpha: one opaque red, one fully transparent blue.
            decode = Mock(return_value=(2, 1, bytes((0, 0, 255, 255, 255, 0, 0, 0))))
            identity = lambda path: path.stat().st_size
            colors, validate = frames.wallpaper_tints(
                image, {"wallpaper_file_identity": identity, "decode_wallpaper_bitmap": decode,
                        "icc_reference_identity": lambda: None})
            decode.assert_called_once_with(image)
            self.assertEqual(colors, {mode: frames.tint_color(mode, (255, 0, 0))
                                      for mode in frames.BASE_COLORS})
            image.write_bytes(b"changed")
            with self.assertRaises(ValueError):
                validate()

    def test_live_material_cache_tracks_primary_file_and_decoder_revision(self):
        with tempfile.TemporaryDirectory() as tmp:
            image = Path(tmp) / "wallpaper.png"
            image.write_bytes(b"first")
            decode = Mock(return_value=(1, 1, bytes((0, 0, 255, 255))))
            sync = {"WALLPAPER_ANALYSIS_REVISION": 2, "decode_wallpaper_bitmap": decode}
            snapshot = {"activity": "one", "wallpapers": [{"path": str(image), "size": 5}]}
            first = frames.live_material_state(snapshot, None, sync)
            self.assertEqual(first["colors"], {mode: frames.tint_color(mode, (255, 0, 0))
                                                for mode in frames.BASE_COLORS})
            snapshot["activity"] = "two"
            snapshot["wallpapers"].append({"path": "/other.png", "size": 1})
            self.assertEqual(frames.live_material_state(snapshot, json.dumps(first), sync), first)
            decode.assert_called_once_with(image)
            snapshot["icc_reference"] = "imported-reference"
            imported = frames.live_material_state(snapshot, json.dumps(first), sync)
            self.assertEqual(imported["icc_reference"], "imported-reference")
            self.assertEqual(decode.call_count, 2)
            sync["WALLPAPER_ANALYSIS_REVISION"] += 1
            second = frames.live_material_state(snapshot, json.dumps(imported), sync)
            self.assertEqual(decode.call_count, 3)
            snapshot["wallpapers"][0]["size"] = 10
            frames.live_material_state(snapshot, json.dumps(second), sync)
            self.assertEqual(decode.call_count, 4)
            decode.side_effect = ValueError("Unsupported wallpaper")
            self.assertIsNone(frames.live_material_state(snapshot, None, sync))

    def test_live_material_skips_disabled_or_inactive_appearance(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            marker = root / "windows-modern/transparency-off"
            marker.parent.mkdir()
            marker.touch()
            discover = Mock()
            control = {"CONFIG": root / "config", "DATA": root,
                       "active_mode": Mock(return_value=True), "discover_wallpapers": discover}
            self.assertEqual(frames.sync_live_material("dark", control), "skipped")
            control["active_mode"].assert_not_called()
            discover.assert_not_called()
            marker.unlink()
            control["active_mode"].return_value = False
            self.assertEqual(frames.sync_live_material("dark", control), "skipped")
            discover.assert_not_called()

    def test_live_material_validates_failed_sample_and_unchanged_cache(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            config, data = root / "config", root / "data"
            config.mkdir()
            (config / "kdeglobals").touch()
            aurorae = data / "aurorae/themes"
            kvantum = config / "Kvantum/Windows-modern"
            kvantum.mkdir(parents=True)
            for mode, name in (("dark", "Windows-modernDark"), ("light", "Windows-modern")):
                deco = aurorae / f"windows-modern-{mode}-aurorae" / "decoration.svg"
                deco.parent.mkdir(parents=True)
                deco.write_text(frames.render(mode))
                (kvantum / (name + ".svg")).write_text(SVG)
            sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
            class Changed(ValueError):
                pass
            snapshot = {"activity": "one", "wallpapers": [{"path": "/primary.png"}]}
            state = {"colors": dict(frames.BASE_COLORS)}
            raw = json.dumps(state, separators=(",", ":"), sort_keys=True)
            discover = Mock(return_value=snapshot)
            validate = Mock(side_effect=Changed("stale"))
            control = {"CONFIG": config, "DATA": data, "SYNC": sync,
                       "WallpaperChangedError": Changed, "discover_wallpapers": discover,
                       "require_wallpaper_snapshot": validate, "read": lambda *args: raw}
            with patch.object(frames, "live_material_enabled", return_value=True), \
                 patch.object(frames, "live_material_state", return_value=None):
                with self.assertRaises(Changed):
                    frames.sync_live_material("dark", control)
                discover.assert_called_once_with(primary_only=True)
                validate.assert_called_once_with(snapshot, primary_only=True)
            validate.reset_mock()
            with patch.object(frames, "live_material_enabled", return_value=True), \
                 patch.object(frames, "live_material_state", return_value=state), \
                 patch.object(frames, "plan_local", return_value={}):
                with self.assertRaises(Changed):
                    frames.sync_live_material("dark", control)
                validate.assert_called_once_with(snapshot, primary_only=True)

    def test_material_selection_change_rolls_back(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            aurorae, kvantum = root / "aurorae", root / "kvantum"
            deco = aurorae / "windows-modern-dark-aurorae" / "decoration.svg"
            deco.parent.mkdir(parents=True)
            deco.write_text(frames.render("dark"))
            before = deco.read_bytes()
            kvantum.mkdir()
            svg = kvantum / "Windows-modernDark.svg"
            svg.write_text(SVG)
            selection = Mock(side_effect=[None, ValueError("Changed wallpaper")])
            with patch.object(frames, "wallpaper_tints", return_value=(
                    dict.fromkeys(frames.BASE_COLORS, "#345678"), lambda: None)):
                with self.assertRaisesRegex(ValueError, "Changed wallpaper"):
                    frames.apply_local(aurorae, kvantum, validate_selection=selection)
            self.assertEqual(deco.read_bytes(), before)
            self.assertEqual(svg.read_text(), SVG)

    def test_explicit_transparency_stages_both_renderers(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            kvantum, plasma, source = root / "kvantum", root / "plasma", root / "stage"
            kvantum.mkdir()
            for mode, name in (("dark", "Windows-modernDark"), ("light", "Windows-modern")):
                config = kvantum / (name + ".kvconfig")
                config.write_text("blurring=true\npopup_blurring=true\nblur_translucent=true\n"
                                  "translucent_windows=true\ntransparent_dolphin_view=true\n"
                                  "transparent_pcmanfm_sidepane=true\ntransparent_pcmanfm_view=true\nuntouched=1\n")
                for variant in ("", "translucent", "solid"):
                    for role in ("dialogs/background.svg", "widgets/panel-background.svg"):
                        src = source / ("Windows-modern-" + mode) / variant / role
                        src.parent.mkdir(parents=True, exist_ok=True)
                        src.write_text('<svg xmlns="http://www.w3.org/2000/svg" id="' + (variant or "normal") + '"/>')
                        if variant != "solid":
                            dst = plasma / ("Windows-modern-" + mode) / variant / role
                            dst.parent.mkdir(parents=True, exist_ok=True)
                            dst.write_bytes(src.read_bytes())
            sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
            pending = frames.plan_transparency(kvantum, plasma, source, False, sync["owned_file"])
            self.assertEqual(len(pending), 10)
            sync["write_pending"](pending)
            for mode, name in (("dark", "Windows-modernDark"), ("light", "Windows-modern")):
                self.assertEqual((kvantum / (name + ".kvconfig")).read_text(),
                                 "blurring=false\npopup_blurring=false\nblur_translucent=false\n"
                                 "translucent_windows=false\ntransparent_dolphin_view=false\n"
                                 "transparent_pcmanfm_sidepane=false\ntransparent_pcmanfm_view=false\nuntouched=1\n")
                self.assertEqual((plasma / ("Windows-modern-" + mode) / "dialogs/background.svg").read_bytes(),
                                 (source / ("Windows-modern-" + mode) / "solid/dialogs/background.svg").read_bytes())
            self.assertEqual(len(frames.plan_transparency(kvantum, plasma, source, True, sync["owned_file"])), 10)
            changed = plasma / "Windows-modern-light/dialogs/background.svg"
            changed.write_text("<svg/>")
            with self.assertRaisesRegex(ValueError, "differs from the generated selector"):
                frames.plan_transparency(kvantum, plasma, source, True, sync["owned_file"])
            self.assertEqual(changed.read_text(), "<svg/>")

    def test_transparency_preference_preserves_original_blur(self):
        with tempfile.TemporaryDirectory() as tmp:
            marker = Path(tmp) / "windows-modern/transparency-off"
            for original in ("", "true", "false"):
                current = [original]

                def write(expected, desired):
                    self.assertEqual(current[0], expected)
                    current[0] = desired

                with patch.object(frames, "read_blur_preference", side_effect=lambda: current[0]), \
                     patch.object(frames, "write_blur_preference", side_effect=write):
                    off = frames.TransparencyPreference(marker, False)
                    off.apply()
                    self.assertEqual(marker.read_bytes(), ("blurEnabled=" + original + "\n").encode())
                    self.assertEqual(current[0], "false")
                    frames.TransparencyPreference(marker, False).apply()
                    self.assertEqual(marker.read_bytes(), ("blurEnabled=" + original + "\n").encode())
                    on = frames.TransparencyPreference(marker, True)
                    on.apply()
                    self.assertFalse(marker.exists())
                    self.assertEqual(current[0], original)
                    on.rollback()
                    self.assertTrue(marker.exists())
                    self.assertEqual(current[0], "false")
                    off.rollback()
                    self.assertFalse(marker.exists())
                    self.assertEqual(current[0], original)

    def test_transparency_marker_failure_rolls_back_renderer_and_blur(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            aurorae, kvantum = root / "aurorae", root / "kvantum"
            kvantum.mkdir()
            for mode, name in (("dark", "Windows-modernDark"), ("light", "Windows-modern")):
                deco = aurorae / f"windows-modern-{mode}-aurorae" / "decoration.svg"
                deco.parent.mkdir(parents=True)
                deco.write_text(frames.render(mode))
                (kvantum / (name + ".svg")).write_text(SVG)
            files = [*aurorae.rglob("*.svg"), *kvantum.glob("*.svg")]
            before = {path: path.read_bytes() for path in files}
            marker = root / "windows-modern/transparency-off"
            current = ["true"]

            def write(expected, desired):
                self.assertEqual(current[0], expected)
                current[0] = desired

            with patch.object(frames, "read_blur_preference", side_effect=lambda: current[0]), \
                 patch.object(frames, "write_blur_preference", side_effect=write), \
                 patch.object(frames, "plan_transparency", return_value={}), \
                 patch.object(frames, "write_transparency_marker", side_effect=OSError("Marker write failed")):
                with self.assertRaisesRegex(OSError, "Marker write failed"):
                    frames.apply_local(aurorae, kvantum, transparency=(root, root, False),
                                       transparency_state=marker)
            self.assertEqual(current[0], "true")
            self.assertFalse(marker.exists())
            self.assertEqual({path: path.read_bytes() for path in files}, before)

    def test_current_wallpaper_selection(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            primary = root / 'blue wallpaper.jpg'
            secondary = root / 'green.png'
            primary.touch()
            secondary.touch()
            config = root / 'appletsrc'

            def section(index, screen, uri, plugin='org.kde.image'):
                return (f'[Containments][{index}]\nplugin=org.kde.plasma.folder\n'
                        f'lastScreen={screen}\nwallpaperplugin={plugin}\n'
                        f'[Containments][{index}][Wallpaper][org.kde.image][General]\n'
                        f'Image={uri}\n')

            first = section(2, 0, primary.as_uri())
            second = section(3, 1, secondary.as_uri())
            config.write_text(first + second, encoding='utf-8')
            self.assertEqual(frames.configured_wallpaper(config), primary)
            config.write_text(first + section(4, 0, secondary.as_uri()), encoding='utf-8')
            self.assertIsNone(frames.configured_wallpaper(config))
            config.write_text(section(2, 0, primary.as_uri(), 'org.kde.slideshow'), encoding='utf-8')
            self.assertIsNone(frames.configured_wallpaper(config))
            config.write_text(section(2, 0, 'https://example.invalid/image.jpg'), encoding='utf-8')
            self.assertIsNone(frames.configured_wallpaper(config))

    def test_samples_local_image(self):
        try:
            from PIL import Image
        except ImportError:
            self.skipTest('optional Pillow unavailable')
        with tempfile.TemporaryDirectory() as tmp:
            image = Path(tmp) / 'wallpaper.png'
            Image.new('RGB', (32, 32), (0, 0, 255)).save(image)
            colors, _ = frames.wallpaper_tints(image)
            self.assertEqual(colors['dark'], frames.tint_color('dark', (0, 0, 255)))
            self.assertEqual(colors['light'], frames.tint_color('light', (0, 0, 255)))

    def test_decoupled_appearance_module_interfaces(self):
        import ast

        scripts_dir = ROOT / "scripts/theme"
        names = (
            "theme-files.py",
            "accent-algorithms.py",
            "accent-renderers.py",
            "appearance-host.py",
            "sync-accent.py",
            "accent-control.py",
            "window-frames.py",
            "appearance-packages.py",
        )
        loaded = {}
        for name in names:
            path = scripts_dir / name
            tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
            imported = {
                alias.name
                for node in ast.walk(tree)
                if isinstance(node, ast.Import)
                for alias in node.names
            } | {
                node.module
                for node in ast.walk(tree)
                if isinstance(node, ast.ImportFrom) and node.module
            }
            self.assertNotIn("runpy", imported, name)
            mod_spec = importlib.util.spec_from_file_location(f"wm_test_{name}", path)
            module = importlib.util.module_from_spec(mod_spec)
            mod_spec.loader.exec_module(module)
            loaded[name] = module

        algorithms = loaded["accent-algorithms.py"]
        renderers = loaded["accent-renderers.py"]
        host = loaded["appearance-host.py"]
        sync_mod = loaded["sync-accent.py"]
        control_mod = loaded["accent-control.py"]
        self.assertIs(sync_mod.WallpaperFileChangedError, algorithms.WallpaperFileChangedError)
        self.assertIs(control_mod.SYNC["WallpaperFileChangedError"], algorithms.WallpaperFileChangedError)
        self.assertIs(control_mod.WallpaperChangedError, host.WallpaperChangedError)
        self.assertIs(sync_mod.render_scheme, renderers.render_scheme)
        self.assertIs(sync_mod.plan_kvantum, renderers.plan_kvantum)
        self.assertIs(sync_mod.publish_kvantum_reload, renderers.publish_kvantum_reload)

    def test_accent_control_without_local_kvantum_and_partial_rejection(self):
        control = runpy.run_path(str(ROOT / "scripts/theme/accent-control.py"))
        sync = control["SYNC"]
        template, fixed = control["scheme_inputs"]()
        selection = "#FF8C00"
        expected_palette = sync["derive_manual_palette"](selection)
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            config, data = base / "config", base / "data"
            config.mkdir()
            (config / "kdeglobals").write_text("", encoding="utf-8")
            schemes = data / "color-schemes"
            appearance["color_schemes"](ROOT, schemes)
            stored = [None]

            def read(group, key):
                return stored[0] if (group, key) == (control["GROUP"], control["KEY"]) else None

            # Absent ~/.config/Kvantum/Windows-modern still updates KDE schemes.
            with patch.dict(control["synchronize"].__globals__, {
                    "CONFIG": config, "DATA": data,
                    "active_mode": lambda mode: True,
                    "native_accent": lambda: (False, None),
                    "read": read,
                    "write_state": lambda value: stored.__setitem__(0, value),
                    "apply_current": Mock(),
                    "live_matches": lambda *args: True,
                    "notify_palette": Mock()}):
                self.assertTrue(control["synchronize"]("dark", "manual", [selection]))
                self.assertEqual(control["decode_state"](stored[0]), expected_palette)
                self.assertEqual(
                    (schemes / "WindowsModernDark.colors").read_bytes(),
                    control["render"](template, fixed, "dark", expected_palette))

                # An incomplete local Kvantum directory still fails closed before writing.
                (config / "Kvantum/Windows-modern").mkdir(parents=True)
                before_dark = (schemes / "WindowsModernDark.colors").read_bytes()
                with self.assertRaises(ValueError):
                    control["synchronize"]("dark", "manual", ["#0078D4"])
                self.assertEqual((schemes / "WindowsModernDark.colors").read_bytes(), before_dark)

    def test_window_material_aurorae_without_kvantum_and_incomplete_pair_rejection(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            config, data = root / "config", root / "data"
            config.mkdir()
            (config / "kdeglobals").write_text("", encoding="utf-8")
            aurorae = data / "aurorae/themes"
            plasma = data / "plasma/desktoptheme"
            stage = root / "stage"
            for mode in ("dark", "light"):
                deco = aurorae / f"windows-modern-{mode}-aurorae" / "decoration.svg"
                deco.parent.mkdir(parents=True)
                deco.write_text(frames.render(mode), encoding="utf-8")
                for variant in ("", "translucent", "solid"):
                    for role in ("dialogs/background.svg", "widgets/panel-background.svg"):
                        src = stage / f"Windows-modern-{mode}" / variant / role
                        src.parent.mkdir(parents=True, exist_ok=True)
                        src.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" id="{variant or "normal"}"/>',
                                       encoding="utf-8")
                        if variant != "solid":
                            dst = plasma / f"Windows-modern-{mode}" / variant / role
                            dst.parent.mkdir(parents=True, exist_ok=True)
                            dst.write_bytes(src.read_bytes())

            def read_cfg(file, group, key):
                if (file, group, key) == ("kwinrc", "org.kde.kdecoration2", "library"):
                    return "org.kde.kwin.aurorae"
                if (file, group, key) == ("kwinrc", "org.kde.kdecoration2", "theme"):
                    return "__aurorae__svg__windows-modern-dark-aurorae"
                return ""

            image = root / "wallpaper.png"
            image.write_bytes(b"image")
            snapshot = {"activity": "one", "wallpapers": [{"path": str(image), "size": 5}]}
            stored = [None]
            decode = Mock(return_value=(1, 1, bytes((0, 0, 255, 255))))
            sync = {
                "owned_file": frames._theme_files.owned_file,
                "write_pending": frames._theme_files.write_pending,
                "restore_pending": frames._theme_files.restore_pending,
                "WALLPAPER_ANALYSIS_REVISION": 1,
                "icc_reference_identity": lambda: None,
                "decode_wallpaper_bitmap": decode,
            }
            control = {
                "CONFIG": config,
                "DATA": data,
                "SYNC": sync,
                "WallpaperChangedError": ValueError,
                "active_mode": lambda mode: mode == "dark",
                "read": lambda group, key: "Breeze" if (group, key) == ("KDE", "widgetStyle") else stored[0],
                "read_config": read_cfg,
                "discover_wallpapers": lambda primary_only=False: dict(snapshot),
                "require_wallpaper_snapshot": lambda state, primary_only=False: None,
            }
            self.assertTrue(frames.live_material_enabled("dark", control))
            with patch.object(frames, "write_material_state", side_effect=lambda value: stored.__setitem__(0, value)):
                self.assertEqual(frames.sync_live_material("dark", control), "changed")
            expected_tint = frames.tint_color("dark", (255, 0, 0))
            self.assertEqual(
                elements((aurorae / "windows-modern-dark-aurorae/decoration.svg").read_text())["decoration-center"][0].get("fill"),
                expected_tint)

            # Transparency staging without user-local Kvantum updates all 8 Plasma selectors.
            absent_kvantum = config / "Kvantum/Windows-modern"
            pending = frames.plan_transparency(absent_kvantum, plasma, stage, False)
            self.assertEqual(len(pending), 8)

            # A half-installed local Kvantum SVG pair must be rejected rather than ignored.
            absent_kvantum.mkdir(parents=True)
            (absent_kvantum / "Windows-modernDark.svg").write_text(SVG, encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Incomplete"):
                frames.sync_live_material("dark", control)


if __name__ == '__main__':
    unittest.main()
