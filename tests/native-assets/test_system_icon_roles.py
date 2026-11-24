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
