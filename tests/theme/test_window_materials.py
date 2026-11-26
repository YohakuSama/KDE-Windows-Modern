# SPDX-License-Identifier: GPL-3.0-or-later
import configparser
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
