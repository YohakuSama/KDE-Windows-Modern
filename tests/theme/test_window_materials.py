# SPDX-License-Identifier: GPL-3.0-or-later
import base64
import configparser
import gzip
import hashlib
import json
import importlib.util
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

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

    def test_active_wallpaper_package_variants(self):
        control = runpy.run_path(str(ROOT / "scripts/theme/accent-control.py"))
        resolve = control["resolve_wallpaper"]
        with tempfile.TemporaryDirectory() as tmp:
            package = Path(tmp) / "wallpaper # one"
            light = package / "contents/images/3840x2160.jpg"
            dark = package / "contents/images_dark/3840x2160.jpg"
            for path in (light, dark):
                path.parent.mkdir(parents=True)
                path.write_bytes(b"image")
            (package / "metadata.json").write_text("{}")
            self.assertEqual(resolve(package.as_uri(), "dark"), dark)
            self.assertEqual(resolve(package.as_uri(), "light"), light)
            self.assertEqual(resolve(package.as_uri() + "#light", "dark"), light)
            self.assertEqual(resolve(package.as_uri() + "#dark", "light"), dark)
            self.assertEqual(resolve(light.as_uri(), "dark"), light)
            self.assertEqual(resolve(str(light), "dark"), light)
            with self.assertRaises(ValueError):
                resolve(package.as_uri() + "#day-night", "dark")
            with self.assertRaises(ValueError):
                resolve("https://example.com/image.jpg", "light")
            dark.unlink()
            self.assertEqual(resolve(package.as_uri(), "dark"), light)
            (light.parent / "1920x1080.jpg").write_bytes(b"other")
            with self.assertRaisesRegex(ValueError, "unambiguous"):
                resolve(package.as_uri(), "light")

    def test_automatic_wallpaper_cache_and_discovery(self):
        control = runpy.run_path(str(ROOT / "scripts/theme/accent-control.py"))
        discover = control["discover_wallpapers"]
        automatic = control["automatic_state"]
        with tempfile.TemporaryDirectory() as tmp:
            image = Path(tmp) / "wallpaper.png"
            image.write_bytes(b"first")
            topology = {"activity": "current", "screens": 2}
            params = {"wallpaperPlugin": {"type": "s", "data": "org.kde.image"},
                      "Image": {"type": "s", "data": image.as_uri()}}
            palette = control["SYNC"]["derive_manual_palette"]("#FF8C00")
            with patch.dict(discover.__globals__, {
                    "desktop_snapshot": lambda: topology,
                    "plasma_call": lambda *args: params}), \
                 patch.dict(control["SYNC"], {"analyze_wallpapers": lambda paths: {"palette": palette}}):
                snapshot = discover("light")
                self.assertEqual(snapshot["activity"], "current")
                self.assertEqual(len(snapshot["wallpapers"]), 2)
                self.assertEqual(snapshot["wallpapers"][0], snapshot["wallpapers"][1])
                state = automatic("light", None)
                self.assertEqual(control["decode_state"](json.dumps(state)), palette)
                with patch.dict(control["SYNC"], {"analyze_wallpapers": lambda paths: self.fail("decoded cached images")}):
                    self.assertIs(automatic("dark", state), state)
                image.write_bytes(b"replacement image")
                self.assertNotEqual(automatic("light", state)["wallpapers"], state["wallpapers"])
                params["PreviewImage"] = {"type": "s", "data": image.as_uri()}
                with self.assertRaisesRegex(ValueError, "previewing"):
                    discover("light")

    def test_repeated_wallpaper_path_reuses_statistics(self):
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        analyze = sync["analyze_wallpapers"]
        calls = []
        def decode(path):
            calls.append(path)
            return (1, 1, bytes((88, 88, 188, 255)))
        with patch.dict(analyze.__globals__, {"decode_opaque_wallpaper_bitmap": decode}):
            path = Path("/wallpaper.png")
            single = analyze([path])
            repeated = analyze([path, path])
        self.assertEqual(calls, [path, path])
        self.assertEqual(single, repeated)

    def test_windows_accent_state_validation(self):
        control = runpy.run_path(str(ROOT / "scripts/theme/accent-control.py"))
        palette = control["SYNC"]["derive_manual_palette"]("#FF8C00")
        state = {"schema_version": 1, "source": "manual", "palette": palette}
        self.assertEqual(control["decode_state"](json.dumps(state)), palette)
        self.assertIsNone(control["decode_state"](None))
        state["palette"] = {**palette, "AccentDark1": "invalid"}
        with self.assertRaises(ValueError):
            control["decode_state"](json.dumps(state))
        state["palette"] = {"Accent": "#FF8C00"}
        with self.assertRaisesRegex(ValueError, "Incomplete"):
            control["decode_state"](json.dumps(state))

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
            self.assertEqual(scheme["Colors:View"]["ForegroundLink"], rgb(shade))
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
                palette = sample["palette"]
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

    def test_decode_wallpaper_orientation_and_opacity(self):
        try:
            from PIL import Image
        except ImportError:
            self.skipTest("optional Pillow unavailable")
        sync = runpy.run_path(str(ROOT / "scripts/theme/sync-accent.py"))
        decode = sync["decode_opaque_wallpaper_bitmap"]
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
            with self.assertRaisesRegex(ValueError, "Transparent"):
                decode(rgba)
            # RGB PNG can also carry a transparent-color key.
            with Image.new("RGB", (1, 1), (10, 20, 30)) as image:
                image.save(rgba, transparency=(10, 20, 30))
            with self.assertRaisesRegex(ValueError, "Transparent"):
                decode(rgba)
            with self.assertRaises(ValueError):
                decode(root)
            with self.assertRaises(ValueError):
                decode(root / "missing.jpg")

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
            with patch.object(frames, 'wallpaper_color', return_value='#345678'):
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

    def test_missing_wallpaper_fallback(self):
        self.assertIsNone(frames.wallpaper_color(None, 'dark'))
        with tempfile.TemporaryDirectory() as tmp:
            self.assertIsNone(frames.wallpaper_color(Path(tmp), 'light'))

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
            self.assertEqual(frames.wallpaper_color(package, 'dark'), frames.tint_color('dark', (0, 0, 255)))
            self.assertEqual(frames.wallpaper_color(package, 'light'), frames.tint_color('light', (255, 0, 0)))
            (package / 'contents/images_dark/64x64.png').unlink()
            self.assertEqual(frames.wallpaper_color(package, 'dark'), frames.tint_color('dark', (255, 0, 0)))


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
            self.assertEqual(frames.wallpaper_color(image, 'dark'),
                             frames.tint_color('dark', (0, 0, 255)))
            self.assertEqual(frames.wallpaper_color(image, 'light'),
                             frames.tint_color('light', (0, 0, 255)))


if __name__ == '__main__':
    unittest.main()
