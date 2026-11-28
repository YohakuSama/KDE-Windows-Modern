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

    def test_start_footer_and_snooze_outline_roles(self):
        expected = {
            "e8a5": "actions/wm-start-documents-symbolic",
            "e896": "actions/wm-start-downloads-symbolic",
            "ec4f": "actions/wm-start-music-symbolic",
            "e8b9": "actions/wm-start-pictures-symbolic",
            "e714": "actions/wm-start-videos-symbolic",
            "ec27": "actions/wm-start-network-symbolic",
            "ec25": "actions/wm-start-home-symbolic",
            "ec50": "actions/wm-start-thispc-symbolic",
            "e713": "actions/wm-start-settings-symbolic"
        }
        for code, target in expected.items():
            self.assertIn(target, MAPPING['icons'][code].split())
        self.assertIn('status/notifications-disabled-symbolic', MAPPING['icons']['f285'].split())
        self.assertNotIn('status/notifications-disabled-symbolic', MAPPING['icons']['f2a8'].split())
        self.assertIn('f285', MAPPING['panel_glyph_groups']['notification'])
        self.assertEqual(MAPPING['wallpaper_accents'], {
            'Windows-modern': {'Light': '#0067C0', 'Dark': '#4CC2FF'}
        })

    def test_window_move_and_resize_roles(self):
        self.assertIn('actions/transform-move-symbolic', MAPPING['icons']['e7c2'].split())
        self.assertIn('actions/transform-scale-symbolic', MAPPING['icons']['e744'].split())
        for absent in ('activities', 'window-keep-above', 'window-keep-below',
                       'view-group', 'view-private', 'kmenuedit'):
            self.assertFalse(any(path.split('/')[-1] == absent
                                 for names in MAPPING['icons'].values()
                                 for path in names.split()))

    def test_sound_output_role_is_not_speaker_volume(self):
        self.assertEqual(MAPPING['icons']['f4c3'], 'actions/wm-sound-output-symbolic')
        self.assertIn('f4c3', MAPPING['optional_glyphs'])
        for code in ('e992', 'e993', 'e994', 'e995'):
            self.assertNotIn('actions/wm-sound-output-symbolic', MAPPING['icons'][code].split())

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

    def test_sleep_hibernate_and_logout_are_distinct(self):
        self.assertIn('actions/system-suspend-symbolic', MAPPING['icons']['e708'].split())
        self.assertIn('status/system-logout', MAPPING['icons']['f3b1'].split())
        for context in ('actions', 'status'):
            for suffix in ('', '-symbolic'):
                target = context + '/system-suspend-hibernate' + suffix
                self.assertIn(target, MAPPING['icons']['e823'].split())
                self.assertNotIn(target, MAPPING['icons']['e708'].split())
        self.assertIn('e823', MAPPING['optional_glyphs'])

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

    def test_reviewed_26h2_kcm_aliases(self):
        expected = {
            "e950": ["devices/cpu", "devices/cpu-symbolic", "apps/preferences-devices-cpu", "apps/preferences-devices-cpu-symbolic", "categories/preferences-devices-cpu", "categories/preferences-devices-cpu-symbolic"],
            "e88e": ["devices/drive-removable-media-usb-pendrive", "devices/drive-removable-media-usb-pendrive-symbolic"],
            "ec4f": ["status/emblem-music-symbolic"],
            "e92e": ["apps/input-keyboard-virtual", "apps/input-keyboard-virtual-symbolic", "devices/input-keyboard-virtual", "devices/input-keyboard-virtual-symbolic"],
            "e946": ["apps/ktip", "apps/ktip-symbolic"],
            "e721": ["apps/plasma-search", "apps/plasma-search-symbolic", "apps/preferences-desktop-baloo", "apps/preferences-desktop-baloo-symbolic", "categories/preferences-desktop-baloo", "categories/preferences-desktop-baloo-symbolic"],
            "e8b0": ["apps/preferences-desktop-cursors", "apps/preferences-desktop-cursors-symbolic", "categories/preferences-desktop-cursors", "categories/preferences-desktop-cursors-symbolic"],
            "e7f4": ["apps/preferences-desktop-display-randr", "apps/preferences-desktop-display-randr-symbolic", "categories/preferences-desktop-display-randr", "categories/preferences-desktop-display-randr-symbolic", "status/preferences-desktop-display-randr", "status/preferences-desktop-display-randr-symbolic"],
            "ed15": ["apps/preferences-desktop-feedback", "apps/preferences-desktop-feedback-symbolic", "categories/preferences-desktop-feedback", "categories/preferences-desktop-feedback-symbolic"],
            "e8d2": ["apps/preferences-desktop-font-installer", "apps/preferences-desktop-font-installer-symbolic", "categories/preferences-desktop-font-installer", "categories/preferences-desktop-font-installer-symbolic"],
            "e7fc": ["apps/preferences-desktop-gaming", "apps/preferences-desktop-gaming-symbolic", "categories/preferences-desktop-gaming", "categories/preferences-desktop-gaming-symbolic"],
            "eda7": ["apps/preferences-desktop-keyboard-shortcut", "apps/preferences-desktop-keyboard-shortcut-symbolic", "categories/preferences-desktop-keyboard-shortcut", "categories/preferences-desktop-keyboard-shortcut-symbolic"],
            "efa5": ["apps/preferences-desktop-touchpad", "apps/preferences-desktop-touchpad-symbolic", "categories/preferences-desktop-touchpad", "categories/preferences-desktop-touchpad-symbolic"],
            "eda4": ["apps/preferences-desktop-touchscreen", "apps/preferences-desktop-touchscreen-symbolic", "categories/preferences-desktop-touchscreen", "categories/preferences-desktop-touchscreen-symbolic"],
            "e72e": ["apps/preferences-desktop-user-password", "apps/preferences-desktop-user-password-symbolic", "categories/preferences-desktop-user-password", "categories/preferences-desktop-user-password-symbolic"],
            "e7c4": ["apps/preferences-desktop-virtual", "apps/preferences-desktop-virtual-symbolic", "categories/preferences-desktop-virtual", "categories/preferences-desktop-virtual-symbolic"],
            "e7e8": ["apps/preferences-system-power-management", "apps/preferences-system-power-management-symbolic", "categories/preferences-system-power-management", "categories/preferences-system-power-management-symbolic"],
            "e8f9": ["apps/preferences-system-tabbox", "apps/preferences-system-tabbox-symbolic", "categories/preferences-system-tabbox", "categories/preferences-system-tabbox-symbolic"],
            "e716": ["apps/preferences-system-users", "apps/preferences-system-users-symbolic", "categories/preferences-system-users", "categories/preferences-system-users-symbolic"],
            "e8ea": ["devices/smartphone", "devices/smartphone-symbolic"],
            "ec50": ["apps/system-file-manager", "apps/system-file-manager-symbolic"],
            "eda3": ["devices/network-card", "devices/network-card-symbolic"],
            "e8af": ["apps/preferences-system-network-remote", "apps/preferences-system-network-remote-symbolic", "categories/preferences-system-network-remote", "categories/preferences-system-network-remote-symbolic"],
            "eea0": ["devices/memory", "devices/memory-symbolic", "apps/memory", "apps/memory-symbolic"],
            "e964": ["apps/hwinfo", "apps/hwinfo-symbolic", "devices/hwinfo", "devices/hwinfo-symbolic"],
            "e70a": ["apps/preferences-desktop-tablet", "apps/preferences-desktop-tablet-symbolic", "categories/preferences-desktop-tablet", "categories/preferences-desktop-tablet-symbolic", "devices/tablet", "devices/tablet-symbolic"],
            "e9ca": ["status/temperature-normal", "status/temperature-normal-symbolic"],
            "e968": ["apps/preferences-system-network-sharing", "apps/preferences-system-network-sharing-symbolic", "categories/preferences-system-network-sharing", "categories/preferences-system-network-sharing-symbolic"],
            "e8e5": ["apps/preferences-desktop-filetype-association", "apps/preferences-desktop-filetype-association-symbolic", "categories/preferences-desktop-filetype-association", "categories/preferences-desktop-filetype-association-symbolic"],
            "eda2": ["devices/drive-multidisk", "devices/drive-multidisk-symbolic"],
            "e7f5": ["devices/audio-card", "devices/audio-card-symbolic"],
            "f08c": ["apps/redshift-status-on", "apps/redshift-status-on-symbolic", "categories/redshift-status-on", "categories/redshift-status-on-symbolic"],
            "e771": ["apps/preferences-desktop-plasma-theme", "apps/preferences-desktop-plasma-theme-symbolic", "apps/preferences-desktop-theme-applications", "apps/preferences-desktop-theme-applications-symbolic", "apps/preferences-desktop-theme-windowdecorations", "apps/preferences-desktop-theme-windowdecorations-symbolic"],
            "e839": ["apps/preferences-system-network-connection", "apps/preferences-system-network-connection-symbolic"],
            "e774": ["apps/preferences-system-network-proxy", "apps/preferences-system-network-proxy-symbolic"],
        }
        for preserved_brand in ("fcitx", "kwalletmanager", "kwin", "wayland", "xorg"):
            self.assertFalse(any(path.split("/")[-1] in (preserved_brand, preserved_brand + "-symbolic")
                                 for names in MAPPING["icons"].values()
                                 for path in names.split()))
        for glyph, paths in expected.items():
            for path in paths:
                with self.subTest(glyph=glyph, path=path):
                    self.assertIn(path, MAPPING['icons'][glyph].split())

    def test_original_wifi_locked_states_and_pager(self):
        expected = {"e670": ("0", "20"), "e671": ("40",),
                    "e672": ("60",), "e673": ("80", "100")}
        for glyph, levels in expected.items():
            for level in levels:
                for suffix in ("", "-symbolic"):
                    self.assertIn("status/network-wireless-" + level + "-locked" + suffix,
                                  MAPPING["icons"][glyph].split())
        self.assertEqual(MAPPING["panel_glyph_groups"]["wifiLocked"], list(expected))
        self.assertNotIn("wifiLocked", MAPPING["panel_glyph_center_groups"])
        self.assertIn("actions/wm-quick-page-up-symbolic", MAPPING["icons"]["eddb"].split())
        self.assertIn("actions/wm-quick-page-down-symbolic", MAPPING["icons"]["eddc"].split())

    def test_media_transport_original_roles(self):
        for glyph, path in (
                ("f8ac", "actions/wm-media-previous-symbolic"),
                ("f8ad", "actions/wm-media-next-symbolic"),
                ("f5b0", "actions/wm-media-play-symbolic"),
                ("f8ae", "actions/wm-media-pause-symbolic")):
            self.assertIn(path, MAPPING["icons"][glyph].split())
