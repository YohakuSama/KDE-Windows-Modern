# SPDX-License-Identifier: GPL-3.0-or-later
import importlib.util
from pathlib import Path
import tempfile
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("boot_frames", ROOT / "scripts/theme/boot-frames.py")
frames = importlib.util.module_from_spec(spec)
spec.loader.exec_module(frames)

def opaque_components(image):
    points = {(x, y) for y in range(image.height) for x in range(image.width)
              if image.getpixel((x, y))[3] >= 128}
    count = 0
    while points:
        pending = [points.pop()]
        count += 1
        while pending:
            x, y = pending.pop()
            for point in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
                if point in points:
                    points.remove(point)
                    pending.append(point)
    return count


class BootFrameTests(unittest.TestCase):
    def test_packaging_and_real_prompt_callbacks(self):
        with tempfile.TemporaryDirectory() as tmp:
            dest = Path(tmp) / "windows-modern"
            frames.build(dest, "/usr/share/plymouth/themes/windows-modern")
            self.assertEqual(len(list(dest.glob("ring-*.png"))), 80)
            self.assertEqual(len(list(dest.glob("*.png"))), 81)
            pixels = []
            for i in range(80):
                with Image.open(dest / f"ring-{i}.png") as image:
                    self.assertEqual(image.size, (48,48))
                    self.assertEqual(image.mode, "RGBA")
                    self.assertEqual(image.getpixel((0,0))[3], 0)
                    self.assertGreater(image.getchannel("A").getbbox()[2], 15)
                    self.assertEqual(opaque_components(image), 5)
                    pixels.append(image.tobytes())
            self.assertGreater(len(set(pixels)), 70)
            descriptor = (dest / "windows-modern.plymouth").read_text()
            self.assertIn("ModuleName=script", descriptor)
            self.assertIn("ImageDir=/usr/share/plymouth/themes/windows-modern", descriptor)
            self.assertIn("ScriptFile=/usr/share/plymouth/themes/windows-modern/windows-modern.script", descriptor)
            script = (dest / "windows-modern.script").read_text()
            for callback in ("Refresh", "DisplayPassword", "DisplayQuestion", "DisplayNormal", "Message"):
                self.assertIn(f"Plymouth.Set{callback}Function(", script)
            self.assertNotIn("readline", script)
            self.assertIn('Plymouth.GetMode() == "shutdown"', script)
