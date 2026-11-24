// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../plasma/applets/org.kde.windowsmodern.startmenu/contents/ui/code/popupPosition.js" as PopupPosition

TestCase {
    name: "StartMenuPopupPosition"

    function test_position_data() {
        return [
          {
            "tag": "left bottom",
            "mode": 0,
            "edge": "bottom",
            "screen": {
              "x": 0,
              "y": 0,
              "width": 1920,
              "height": 1080
            },
            "button": {
              "x": 8,
              "y": 1032,
              "width": 48,
              "height": 48
            },
            "popup": {
              "width": 600,
              "height": 720
            },
            "expected": {
              "x": 8,
              "y": 304
            }
          },
          {
            "tag": "center bottom",
            "mode": 0,
            "edge": "bottom",
            "screen": {
              "x": 0,
              "y": 0,
              "width": 1920,
              "height": 1080
            },
            "button": {
              "x": 936,
              "y": 1032,
              "width": 48,
              "height": 48
            },
            "popup": {
              "width": 600,
              "height": 720
            },
            "expected": {
              "x": 660,
              "y": 304
            }
          },
          {
            "tag": "floating bottom",
            "mode": 0,
            "edge": "bottom",
            "screen": {
              "x": 0,
              "y": 0,
              "width": 1920,
              "height": 1080
            },
            "button": {
              "x": 936,
              "y": 1012,
              "width": 48,
              "height": 48
            },
            "popup": {
              "width": 600,
              "height": 720
            },
            "expected": {
              "x": 660,
              "y": 284
            }
          },
          {
            "tag": "explicit centered",
            "mode": 2,
            "edge": "bottom",
            "screen": {
              "x": 0,
              "y": 0,
              "width": 1920,
              "height": 1080
            },
            "button": {
              "x": 8,
              "y": 1032,
              "width": 48,
              "height": 48
            },
            "popup": {
              "width": 600,
              "height": 720
            },
            "expected": {
              "x": 660,
              "y": 304
            }
          },
          {
            "tag": "explicit left",
            "mode": 3,
            "edge": "bottom",
            "screen": {
              "x": 0,
              "y": 0,
              "width": 1920,
              "height": 1080
            },
            "button": {
              "x": 936,
              "y": 1032,
              "width": 48,
              "height": 48
            },
            "popup": {
              "width": 600,
              "height": 720
            },
            "expected": {
              "x": 8,
              "y": 304
            }
          },
          {
            "tag": "screen center",
            "mode": 1,
            "edge": "bottom",
            "screen": {
              "x": 0,
              "y": 0,
              "width": 1920,
              "height": 1080
            },
            "button": {
              "x": 8,
              "y": 1032,
              "width": 48,
              "height": 48
            },
            "popup": {
              "width": 600,
              "height": 720
            },
            "expected": {
              "x": 660,
              "y": 180
            }
          },
          {
            "tag": "top panel",
            "mode": 0,
            "edge": "top",
            "screen": {
              "x": 0,
              "y": 0,
              "width": 1920,
              "height": 1080
            },
            "button": {
              "x": 936,
              "y": 0,
              "width": 48,
              "height": 48
            },
            "popup": {
              "width": 600,
              "height": 720
            },
            "expected": {
              "x": 660,
              "y": 56
            }
          },
          {
            "tag": "left panel",
            "mode": 0,
            "edge": "left",
            "screen": {
              "x": 0,
              "y": 0,
              "width": 1920,
              "height": 1080
            },
            "button": {
              "x": 0,
              "y": 500,
              "width": 48,
              "height": 48
            },
            "popup": {
              "width": 600,
              "height": 720
            },
            "expected": {
              "x": 56,
              "y": 164
            }
          },
          {
            "tag": "right panel",
            "mode": 0,
            "edge": "right",
            "screen": {
              "x": 0,
              "y": 0,
              "width": 1920,
              "height": 1080
            },
            "button": {
              "x": 1872,
              "y": 500,
              "width": 48,
              "height": 48
            },
            "popup": {
              "width": 600,
              "height": 720
            },
            "expected": {
              "x": 1264,
              "y": 164
            }
          },
          {
            "tag": "negative monitor origin",
            "mode": 0,
            "edge": "bottom",
            "screen": {
              "x": -1920,
              "y": -100,
              "width": 1920,
              "height": 1080
            },
            "button": {
              "x": -984,
              "y": 932,
              "width": 48,
              "height": 48
            },
            "popup": {
              "width": 600,
              "height": 720
            },
            "expected": {
              "x": -1260,
              "y": 204
            }
          },
          {
            "tag": "right edge clamp",
            "mode": 0,
            "edge": "bottom",
            "screen": {
              "x": 0,
              "y": 0,
              "width": 1920,
              "height": 1080
            },
            "button": {
              "x": 1864,
              "y": 1032,
              "width": 48,
              "height": 48
            },
            "popup": {
              "width": 600,
              "height": 720
            },
            "expected": {
              "x": 1312,
              "y": 304
            }
          },
          {
            "tag": "oversized popup",
            "mode": 0,
            "edge": "bottom",
            "screen": {
              "x": 0,
              "y": 0,
              "width": 500,
              "height": 400
            },
            "button": {
              "x": 200,
              "y": 352,
              "width": 48,
              "height": 48
            },
            "popup": {
              "width": 600,
              "height": 720
            },
            "expected": {
              "x": 8,
              "y": 8
            }
          }
        ];
    }

    function test_position(data) {
        const actual = PopupPosition.position(data.mode, data.edge, data.screen,
                                              data.button, data.popup, 8);
        compare(actual.x, data.expected.x);
        compare(actual.y, data.expected.y);
    }
}
