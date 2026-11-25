# SPDX-License-Identifier: GPL-3.0-or-later
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('window_frames', ROOT / 'scripts/theme/window-frames.py')
frames = importlib.util.module_from_spec(spec)
spec.loader.exec_module(frames)
SVG = ('<svg xmlns="http://www.w3.org/2000/svg">'
       '<path id="window-normal" fill="#ffffff" opacity=".8" d="M0 0"/>'
       '<path id="window-normal-inactive" fill="#ffffff" opacity=".8" d="M1 1"/>'
       '<path id="menu-normal" fill="#ffffff" opacity=".8" d="M2 2"/>'
       '</svg>')


def elements(svg):
    return {node.get('id'): node for node in ET.fromstring(svg).iter() if node.get('id')}


class WindowMaterialTests(unittest.TestCase):
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
        theme = ROOT / 'Kvantum/Windows-modern'
        for name in ('Windows-modern', 'Windows-modernDark'):
            source = (theme / (name + '.svg')).read_text()
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
        theme = ROOT / 'Kvantum/Windows-modern'
        for name, color, border in (('Windows-modern', '#F9F9F9', '#DADADA'),
                                    ('Windows-modernDark', '#2C2C2C', '#454545')):
            with self.subTest(name=name):
                svg = elements((theme / (name + '.svg')).read_text())
                self.assertEqual(svg['menu-normal'].get('fill'), color)
                self.assertEqual(svg['menu-normal'].get('opacity'), '.98')
                for part in ('top', 'bottom', 'left', 'right', 'topleft', 'topright',
                             'bottomleft', 'bottomright'):
                    item = svg['menu-normal-' + part]
                    self.assertEqual(len(item), 2)
                    self.assertEqual([x.get('fill') for x in item], [border, color])
                    self.assertTrue(all(x.get('opacity') == '.98' for x in item))
                config = (theme / (name + '.kvconfig')).read_text()
                menu = config.split('[Menu]\n', 1)[1].split('[MenuItem]', 1)[0]
                for side in ('top', 'bottom', 'left', 'right'):
                    self.assertIn('frame.' + side + '=8', menu)
                items = config.split('[MenuItem]\n', 1)[1].split('[MenuBar]', 1)[0]
                self.assertIn('text.margin.top=3', items)
                self.assertIn('text.margin.bottom=3', items)

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
