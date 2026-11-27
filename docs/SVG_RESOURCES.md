# SVG resource ownership / SVG 资源归属

本文件记录项目中 SVG 的唯一编辑来源、语义别名和生成边界。目标是让同一份图形只有一个维护来源，同时保留 KDE、Qt 和 Plasma 依赖的全部资源名称与原生路径。

## 资源归属

| 资源 | 唯一所有者 | 管理方式 |
| --- | --- | --- |
| 全局图标主题 | `icons/windows-modern/` | 独立可安装图标主题，保留所有标准图标名称 |
| 图标语义别名 | `icons/windows-modern-aliases.json` | 声明完全相同的 SVG 文件组、canonical 文件和兼容别名 |
| Plasma 桌面主题 atlas | `platform/plasma/appearance/atlas/Windows-modern-dark/` | 由 `core/source-map.json` 生成到原生 Plasma 路径 |
| 弹窗与面板九宫格帧 | `core/materials/popup-frame.svg.in`、`core/materials/popup-frames.py`、`modules/taskbar/design/panel-frames.py` | 分别生成弹窗帧与面板帧 atlas 输出 |
| Windows 原始资源导入 | `core/resources/import/` | `native-assets-map.json` 定义原始角色到 KDE 图标名的映射 |
| 公共头像等资源 | `core/resources/` | 由多个宿主共用的独立资源 |
| 功能专属资源 | 对应的 `modules/*/` | 只由所属功能模块维护 |

不要为了目录形式统一，把独立安装包、Plasma atlas 和功能资源全部搬入同一个目录。资源所有权应与实际消费者和部署边界一致。

## 全局图标主题的 canonical 与别名

当前图标主题包含 4,991 个 SVG。按 Git blob 内容核对后，发现 740 组完全相同的文件，共涉及 3,524 个路径。

- 2,207 个 canonical SVG 是每组唯一的编辑来源。
- 2,784 个路径是语义别名。
- 192 组优先选择 Windows 原始资源映射中的目标名称作为 canonical。
- 其他组使用稳定的通用图标名称。

完整映射保存在 `icons/windows-modern-aliases.json`。每组记录 canonical 路径、别名路径、Git blob SHA-1 和选择依据。

别名文件继续保留为普通 SVG 文件。这样不会改变 KDE 图标主题查找、文件名、目录声明、安装复制和打包行为。它们属于兼容输出，不再作为独立设计来源。

### 修改规则

1. 需要调整一组图形时，只编辑该组的 canonical SVG。
2. 执行 `python3 -I scripts/verify-svg-aliases.py --sync`，将 canonical 内容同步到全部语义别名，并更新 manifest 中的 Git blob SHA-1。
3. 执行 `python3 -I scripts/verify-svg-aliases.py --check`，确认所有别名字节一致，且没有未登记的重复组。
4. 安装和打包只执行只读 `--check`。检查失败时停止，不自动覆盖维护者的源码。

完整 owner 安装包包含别名清单与只读检查器，安装时仍会核对全部主题 SVG。
独立 KDE Store 图标组件包只包含 `icons/windows-modern/` 下的实际主题文件，
不携带开发清单和检查脚本。

如果某个图标名称需要独立外观，应先从 manifest 对应组中移除该别名，再将该文件作为独立 SVG 维护。不要直接修改别名文件。

检查器还会发现新增的重复组、被拆分的组、缺失文件和 canonical 内容变化。它不会自动重命名或删除图标。

## 其他资源的复用机制

### Plasma atlas

`platform/plasma/appearance/atlas` 当前有 165 个 SVG。2 组完全相同的文件来自弹窗帧生成器：`core/materials/popup-frame.svg.in` 定义模板，`core/materials/popup-frames.py` 根据 renderer mode 和 role 生成对应路径。另 1 组来自 `modules/taskbar/design/panel-frames.py` 的面板帧生成。它们都是生成输出，不是独立编辑源。

### Windows 原始资源

`core/resources/import/native-assets-map.json` 当前包含 293 个原始资源映射，覆盖 1,020 个语义输出路径。导入器在生成每个输出时计算内容哈希，并对相同内容使用文件硬链接复用数据。manifest 仍为每个输出保留来源和 SHA-256，验证时继续检查全部语义路径。

### 功能模块资源

`core/resources` 与 `modules/*` 中其余 16 个 SVG 没有发现跨目录的完全重复内容。它们继续归各自共享资源或功能模块所有，不为了集中管理而制造新的依赖。

## 当前盘点

| 范围 | SVG 文件 | 完全重复组 | 唯一内容数 |
| --- | ---: | ---: | ---: |
| `icons/windows-modern` | 4,991 | 740 | 2,207 |
| Plasma atlas | 165 | 3 | 161 |
| core、modules 与测试资源 | 16 | 0 | 16 |
| 合计 | 5,172 | 743 | 2,384 |

以上是文件内容身份统计，不代表 Windows 图标覆盖率、视觉相似度或原始素材验收完成度。
