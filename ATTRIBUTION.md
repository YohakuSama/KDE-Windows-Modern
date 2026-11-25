# Attribution & Licenses

Windows Modern is a derivative work released under the GNU General Public
License v3.0 (GPL-3.0). This file lists the upstream projects that were
used to create it and the licenses that apply to them.

## Project License

- **Windows Modern** — GPL-3.0 (see `LICENSE`)

## Code & Theme Components

| Component | Author | Source | License | Usage |
|-----------|--------|--------|---------|-------|
| Win11OS-kde | yeyushengfan258 | <https://github.com/yeyushengfan258/Win11OS-kde> | GPL-3.0 | Base Plasma desktop theme, Aurorae window decorations, Kvantum configs, color schemes, look-and-feel packages |
| Fluent-kde | vinceliuice | <https://github.com/vinceliuice/Fluent-kde> | GPL-3.0 | Kvantum SVG and configuration base |
| OnzeMenuKDE | adhec | <https://github.com/adhec/OnzeMenuKDE> | GPL-3.0 / GPL-2.0+ | Start menu ancestor |
| menu-11-next | Eisteed | <https://github.com/Eisteed/menu-11-next> | GPL-2.0+ | Start menu reference / design basis |
| Win7 Show Desktop | Zren / Chris Holland | <https://github.com/Zren/plasma-applet-win7showdesktop> | GPL-2.0+ (upstream KDE) | Show Desktop applet reference |
| KDE Plasma System Tray | KDE e.V. | <https://invent.kde.org/plasma/plasma-workspace> | GPL-2.0+ | C++ system tray containment fork source |

## Wallpapers

The `wallpaper/Windows-modern/` package uses
photographs sourced from Pexels. Both are licensed under the **Pexels License**:
free to use, modify, and distribute; attribution is not strictly required but is
included here as a courtesy.

The wallpaper package uses Plasma 6's light/dark image mechanism: `contents/images/`
holds the light image and `contents/images_dark/` holds the dark image. Plasma
auto-switches between them based on the active color scheme.

| Image | Photographer | Source | License | Usage |
|-------|--------------|--------|---------|-------|
| Dark image | Mahmoud Ramadan | <https://www.pexels.com/photo/31622984/> | Pexels License | `wallpaper/Windows-modern/contents/images_dark/` |
| Light image | Ace Visuals Co | <https://www.pexels.com/photo/19931186/> | Pexels License | `wallpaper/Windows-modern/contents/images/` |

## Icon Pack Sources

The `icons/windows-modern/` icon theme is a curated derivative work.
**Eleven** is the anchor pack; the other packs listed below were used only
where Eleven was missing an icon or where another pack provided a clearly
superior match for Windows 11 style.

| Pack | Author | Source | License | Role in final theme |
|------|--------|--------|---------|---------------------|
| **Eleven** | mjkim0727 | <https://github.com/mjkim0727/Eleven-icon-theme> | GPL-3.0 | Anchor pack — the majority of icons |
| **Fluent** | vinceliuice | <https://github.com/vinceliuice/Fluent-icon-theme> | GPL-3.0 | Quality overrides (weather, dialog, security, applications, media controls) |
| **Win11** | yeyushengfan258 | <https://github.com/yeyushengfan258/Win11-icon-theme> | GPL-3.0 | Gap-filling (network, cellular, emotes, animations, MIME types, devices) |
| **We10X** | yeyushengfan258 | <https://github.com/yeyushengfan258/We10X-icon-theme> | GPL-3.0 | Small gap-fills (security-high, folder-visiting, mail icons) |
| **Fluentwin** | — | <https://store.kde.org/p/1395671> | No explicit license listed on the store page; the author's other projects are GPL-3.0 | Tiny fills (preferences-desktop-personal, cs-cat-admin, cs-cat-prefs) |

The following packs were considered during curation but **not selected**
for the final output:

- Cobalt-icons
- Windows-Eleven
- Windows-Beuty

## Selling / Distribution Notice

Because this project is built almost entirely from GPL/AGPL-licensed
upstream works, you may charge a fee for distribution, support, or
packaging. However, anyone who receives the work also receives the full
rights granted by those licenses, including:

- the right to receive the complete corresponding source code,
- the right to redistribute copies freely or for a fee,
- the right to modify and share their modifications.

You may not impose additional restrictions that would prevent recipients
from exercising those rights.

> **I am not a lawyer.** For commercial distribution, consult a lawyer
> familiar with open-source licensing.


### Microsoft Fluent UI System Icons: Data Line

`icons/windows-modern/actions/office-chart-line.svg` and its symbolic alias use the original Microsoft Fluent UI System Icons `ic_fluent_data_line_24_regular.svg` path with KDE's ColorScheme-Text recoloring. Source: https://github.com/microsoft/fluentui-system-icons/blob/main/assets/Data%20Line/SVG/ic_fluent_data_line_24_regular.svg . License: MIT, reproduced below for this asset.

MIT License

Copyright (c) 2020 Microsoft Corporation

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

### Windows Terminal application artwork

The generic terminal and Konsole application aliases use the original `res/terminal/Terminal.svg` from Microsoft's open-source Windows Terminal project, revision `43c7ec76a2eb64dac184358fbad25040c9f4a24f` (https://github.com/microsoft/terminal/blob/43c7ec76a2eb64dac184358fbad25040c9f4a24f/res/terminal/Terminal.svg). MIT license; copyright Microsoft Corporation. The complete MIT license notice above also applies to this artwork. The theme remains a KDE theme and does not provide Microsoft's Windows Terminal executable.
