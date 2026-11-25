# SPDX-License-Identifier: GPL-3.0-or-later
"""Guard documented shell action roles and same-name theme precedence."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
MAPPING = json.loads((ROOT / 'scripts/native-assets-map.json').read_text(encoding='utf-8'))


class SystemIconRolesTests(unittest.TestCase):
    def test_unique_output_paths(self):
        targets = [path for names in MAPPING['icons'].values() for path in names.split()]
        self.assertEqual(len(targets), len(set(targets)))

    def test_documented_power_roles_across_contexts(self):
        expected = {
            'e72e': 'system-lock-screen',
            'e7e8': 'system-shutdown',
            'f305': 'system-reboot',
            'f3b1': 'system-log-out',
            'e748': 'system-switch-user',
        }
        for glyph, role in expected.items():
            names = MAPPING['icons'][glyph].split()
            for context in ('actions', 'status'):
                for suffix in ('', '-symbolic'):
                    with self.subTest(glyph=glyph, context=context, suffix=suffix):
                        self.assertIn(context + '/' + role + suffix, names)

    def test_sleep_and_logout_are_distinct(self):
        self.assertIn('actions/system-suspend-symbolic', MAPPING['icons']['e708'].split())
        self.assertIn('status/system-logout', MAPPING['icons']['f3b1'].split())
        self.assertNotIn('actions/system-suspend-hibernate',
                         [path for names in MAPPING['icons'].values() for path in names.split()])

    def test_panel_optical_families(self):
        groups = MAPPING['panel_glyph_groups']
        glyphs = [code for group in groups.values() for code in group]
        self.assertEqual(len(glyphs), len(set(glyphs)))
        self.assertTrue(set(glyphs).issubset(MAPPING['icons']))
        self.assertNotIn('eb1a', groups['battery'])
        self.assertEqual(groups['batteryUnknownCharging'], ['eb1a'])
        self.assertEqual(groups['batterySaver'],
                         ['e863', 'e864', 'e865', 'e866', 'e867', 'e868',
                          'e869', 'e86a', 'e86b', 'ea94', 'ea95'])
        self.assertIn('batterySaver', MAPPING['panel_glyph_center_groups'])
        for level in ('e83f', 'ea93', 'e850', 'e85a'):
            self.assertIn(level, groups['battery'])
        self.assertEqual(groups['volume'], ['e992', 'e993', 'e994'])
        self.assertEqual(groups['volumeHigh'], ['e995'])
        self.assertEqual(groups['volumeMuted'], ['e74f'])
        self.assertEqual(groups['bluetooth'], ['e702'])
        self.assertEqual(groups['removable'], ['e88e'])
        self.assertIn('status/device-notifier-symbolic', MAPPING['icons']['e88e'].split())
        self.assertIn('removable', MAPPING['panel_glyph_center_groups'])

    def test_panel_independent_state_optical_centers(self):
        groups = MAPPING['panel_glyph_groups']
        centered = set(MAPPING['panel_glyph_center_groups'])
        self.assertTrue(centered.issubset(groups))
        self.assertIn('battery', centered)
        self.assertIn('volume', centered)
        self.assertIn('notification', centered)
        self.assertNotIn('wifi', centered)
        self.assertNotIn('wifiLimited', centered)
        self.assertEqual(groups['wifi'], ['e701', 'e872', 'e873', 'e874'])

    def test_settings_and_monitor_sidebar_roles(self):
        expected = {
            'e713': [
                'preferences-desktop'
            ],
            'e962': [
                'preferences-desktop-mouse'
            ],
            'e765': [
                'preferences-desktop-keyboard'
            ],
            'e7f5': [
                'preferences-desktop-sound',
                'preferences-desktop-multimedia'
            ],
            'e7f4': [
                'preferences-desktop-display'
            ],
            'eda2': [
                'preferences-system-disks'
            ],
            'e749': [
                'preferences-devices-printer'
            ],
            'e774': [
                'preferences-system-network'
            ],
            'e771': [
                'preferences-desktop-theme-global',
                'preferences-desktop-theme'
            ],
            'e8d2': [
                'preferences-desktop-font'
            ],
            'ecaa': [
                'preferences-desktop-default-applications'
            ],
            'e7c4': [
                'preferences-system-windows'
            ],
            'e748': [
                'preferences-system-login'
            ],
            'e721': [
                'preferences-desktop-search',
                'preferences-system-search'
            ],
            'e77b': [
                'preferences-desktop-user'
            ],
            'e776': [
                'preferences-desktop-accessibility'
            ],
            'e702': [
                'preferences-system-bluetooth'
            ],
            'e8b9': [
                'preferences-desktop-wallpaper'
            ],
            'e786': [
                'preferences-desktop-animations',
                'preferences-desktop-effects'
            ],
            'e8f9': [
                'preferences-desktop-activities'
            ],
            'f2a3': [
                'preferences-desktop-notification-bell',
                'preferences-desktop-notification',
                'preferences-desktop-notifications',
                'preferences-system-notifications'
            ],
            'e83d': [
                'preferences-security'
            ]
        }
        for glyph, roles in expected.items():
            for role in roles:
                for context in ('apps', 'categories'):
                    for suffix in ('', '-symbolic'):
                        with self.subTest(glyph=glyph, role=role, context=context, suffix=suffix):
                            self.assertIn(f'{context}/{role}{suffix}', MAPPING['icons'][glyph].split())
        for glyph, path in (
                ('e703', 'actions/network-connect-symbolic'),
                ('e71d', 'categories/applications-all-symbolic'),
                ('ec49', 'actions/speedometer-symbolic'),
                ('e8fd', 'actions/view-process-system'),
                ('e821', 'actions/tools-symbolic'),
                ('e76b', 'actions/go-next-symbolic-rtl')):
            self.assertIn(path, MAPPING['icons'][glyph].split())
