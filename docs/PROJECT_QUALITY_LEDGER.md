# 项目质量总账 / Project quality ledger

参考版本：Windows 11 26H2 Build 26300.9974。初始功能基线：[05ceaa169804](https://github.com/YohakuSama/KDE-Windows-Modern/commit/05ceaa16980417c41744de7945484c23c05a6d1f)；架构复核基线：[f54fb1f2f7ab](https://github.com/YohakuSama/KDE-Windows-Modern/commit/f54fb1f2f7ab800b5127f653065d0e9c3d32d35b)（2026-11-27，testing）。目标平台为 KDE Plasma 6 / KWin，优先维护者的 NixOS、Wayland 与 150% 缩放环境。

本文件是项目任务、源码状态、已知差距、优先级和实机验收记录的唯一维护入口。各模块文档继续保存原始证据、详细技术约定和研究历史，不再各自维护完成度。目标是在项目范围内还原原版视觉、布局、功能、交互和动画，兼顾资源来源、性能与稳定性。保留 KDE 的真实服务和原生动作；不添加虚假 Windows 服务、推广内容或重复后端。对宿主限制、不能等效的功能和范围变更，记录依据并取得维护者确认，不自行降低验收标准。

## 统计规则

- I（已实现）：已实现该行定义的有界源码路径。有参考资料或已有实现记录支持；不表示该功能所有输入、所有原版细节或实机均已验证。仅在该行已知的实现缺口解决后标 I；有新差异时重新打开。
- P（部分完成）：已有实现，但仍有明确源码缺口、原版参数/行为证据不足，或适配方案未完成。即使界面已经出现，也不能标 I。
- O（未完成）：已知有一项必要功能/实现缺失。局部诊断、样本或基础设施不等于该项完成。
- U（待盘点）：当前尚无充分的逐项审查，不能推断缺失或完成。REF 表示仍需原版证据；不阻塞其他独立任务。
- 统计固定编号的任务范围，不统计提交数、代码行数或对话数。表中 I/N 为已实现任务范围占比，不是视觉相似度、全项目工程量百分比或剩余时间估计。P 不折算为 50% 或 99%。任务细化时保留原编号或明确映射，记录统计口径变更，禁止用拆分简单任务提高比例。
- 源码完成和实机验收独立记录。实机状态只有 Pending / Pass / Fail / Not applicable（须维护者确认范围）。本基线全部 Pending：当前尚无与该提交对应、覆盖目标环境的完整验收记录。未验收不表示测试失败。只有维护者提供实际环境、提交、场景和结果后才能记 Pass。发现源码差距则同时将对应 I 改回 P/O。
- 源码 100% 需要所有适用任务范围完成、未盘点项和阻塞项清零、参考依据与静态检查覆盖完成。实机 100% 需要适用场景全部通过。达到任务范围占比 100% 不能自动声明像素级相同、稳定发布或免除实机验收。

首次为文档与现有选定实现的基线整理，沿用旧总账 12 项 A01–A12 和 19 项 D01–D19 的原状态，其他项目按当前文档和已知实现保守标记。没有进行全仓库逐文件验证、构建、自动化测试、CI 或实机验证；未核对项目不得当作已确认不存在问题。原始布局压缩包 SHA-256 为 c0e66b05371a0ea1f6447146d21c2b835083c35d448b4e5a0428cda66f315450，首次整理时记录与仓库档案一致。完整原始 PRI/XBF 继续留在维护者私有资料中，仓库只保存可追溯元数据和独立实现。本次进一步核对目录、文件身份和关键实现，见架构复核章节；未完成全仓库逐文件语义审查或重新解析全部原版档案。

## 当前总览

| 工作块 | 优先级 | I | P | O | U | 合计 | I/N |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| [01 全局视觉规范与布局](#block-01) | P0 | 1 | 5 | 0 | 0 | 6 | 16.7% |
| [02 原始图标与光标](#block-02) | P0 | 1 | 4 | 0 | 0 | 5 | 20.0% |
| [03 基础控件与菜单](#block-03) | P0 | 1 | 3 | 0 | 0 | 4 | 25.0% |
| [04 动态配色与材质](#block-04) | P0 | 11 | 10 | 3 | 0 | 24 | 45.8% |
| [05 任务栏与系统托盘](#block-05) | P1 | 1 | 6 | 0 | 0 | 7 | 14.3% |
| [06 开始菜单与搜索](#block-06) | P1 | 4 | 3 | 0 | 0 | 7 | 57.1% |
| [07 快捷中心与通知中心](#block-07) | P1 | 11 | 4 | 0 | 0 | 15 | 73.3% |
| [08 窗口管理与动画](#block-08) | P1 | 1 | 8 | 0 | 0 | 9 | 11.1% |
| [09 锁屏、登录及启动外观](#block-09) | P1 | 0 | 4 | 0 | 0 | 4 | 0.0% |
| [10 文件管理器与终端](#block-10) | P2 | 0 | 5 | 0 | 0 | 5 | 0.0% |
| [11 安装、兼容性与性能](#block-11) | P2（稳定性问题即时处理） | 2 | 6 | 0 | 0 | 8 | 25.0% |
| 总计 | | 33 | 58 | 3 | 0 | 94 | 35.1% |

实机验收：94 项 Pending，0 项有本基线对应的 Pass 记录。新增 4 项架构任务，Q11/V04 从 U 更新为 P；未因文档整理增加 I。任务范围仍可随有证据的遗漏补充，不宣称已列尽全部目标差距。已有功能和源码优势见各行现状，不将 P 项解释为从零开发。

## 模块化源码迁移

维护者确认在 testing 中优先优化架构，再推进各功能还原。按公共核心、功能模块、平台适配与安装管理组织源码。所有任务完成并由维护者独立测试通过后，再由维护者决定创建新仓库。现阶段禁止创建新仓库或合并 main。

首批采用低风险、内容不变的源码迁移：[core](../core/README.md) 管理公共源码，[modules](../modules/README.md) 管理开始菜单、搜索、任务视图、显示桌面、日历、通知等功能源码。原生 Plasma 路径暂为生成镜像，现有安装、构建与验收引用保持有效；现有静态检查与打包入口拒绝漂移。第二批已归类系统托盘、快捷中心、剪贴板、运行、任务栏、锁屏/登录、窗口管理、应用、配色/材质、平台适配及安装工具，七个 applet 的运行源码均已分配所有者。第三批开始取消原生镜像的 Git 跟踪：五个纯 QML applet 内容、三个 KWin 脚本内容、Alt+Tab 内容及两个任务栏布局脚本共 91 个文件改为按需生成。源码安装与主要开发入口使用 --prepare，安装 ZIP 从归档提交的唯一源码生成对应原生文件；第四批将全部已映射的 Plasma 原生源码（七个 applet 的元数据与 C++、锁屏/登录、桌面菜单、全局主题）及 Store 深浅依赖配置改为按需生成，第四批累计 332 个生成输出。第五批进一步移除 50 个 Aurorae/Kvantum/配色模板、Plymouth、应用配置/补丁、常规组件安装与部分资源生成工具的部署镜像，累计 382/436 个生成输出。第六批收敛剩余 54 个重复编辑位置：43 个脚本及工具数据的原生入口改为受映射校验的源码相对链接，安装包从归档提交恢复实体文件；7 个 Konsole 原生文件及 4 个 Nix 表达式保留原生路径为唯一编辑源，移除另一份相同源码。原 436 个映射位置全部完成编辑源唯一化，现映射 425 个输出（382 个生成文件、43 个源码入口），另外 11 个为不经映射的唯一原生源码。第七批将 166 个 Plasma SVG atlas 文件（165 个 SVG、1 个元数据）迁入 platform/plasma/appearance/atlas，保持 Git blob 与权限完全相同，原部署目录改为按需生成。第七批映射 591 个输出（548 个生成文件、43 个源码入口）；另有 11 个唯一原生源码。弹窗、任务栏面板和开关生成器默认写规范源；开始/搜索页与托盘状态改用明确的输入及信号。第八批将任务栏几何、窗口组弹窗、拖放和音频状态依赖改为显式输入；Start、Search、Task View、Icon Tasks 共用 30 逻辑像素图标画布函数，新增 4 个自包含生成输出。第八批映射 595 个输出（552 个生成文件、43 个源码入口）。第九批将壁纸桥接、文件/配置监听、防抖同步及 Win+R/V 注册迁入 Corona 所有的外观监听器和快捷键路由器，开始菜单与时钟共用可选面板能力查找函数，新增 6 个生成输出。第九批映射 601 个输出（558 个生成文件、43 个源码入口）。第十批将面板弹窗焦点协调与 KWin 模糊/滑入效果拆为 PanelPopupController 和 PopupEffects；托盘保留原 QML 接口并委托，新增 4 个生成输出。第十批映射 605 个输出（562 个生成文件、43 个源码入口）。第十一批将 Search 的原生动作所有权迁至 Start 根对象，并通过原生动作变化/就绪信号更新搜索入口；将外观文件的归属验证、原子替换及回滚迁入独立事务模块，新增 1 个源码入口。第十二批将 Konsole 私有插件的 7 个源码文件从 app-decorations/konsole 迁入 platform/qt/konsole，并由 source-map 生成原有构建输入；Nix 构建接口和插件 ABI 保持不变，静态检查先准备生成目录。现映射 613 个输出（569 个生成文件、44 个源码入口），另有 4 个唯一原生 Nix 表达式。图标/壁纸库、部分源生成工具与顶层安装入口保持原路径；后续完成其他公共视觉规范、全局能力生命周期与配色职责收敛。保留运行时自包含包，不新增常驻服务。此阶段没有宣称全部模块已解耦，A14/V07/V08/D20 仍为部分完成。

## 开发顺序与批次

1. 先处理共享视觉根因：原始布局解析及消费者绑定、逻辑尺寸、字体、图标、控件。统一深浅色，不因多个 applet 重复修同一参数。
2. 同时处理不依赖未确认参数的实现工作：配色角色、材质和可复用控件；ICC 等参考阻塞独立列出，不停止其他模块。
3. 在共享规范下并行推进任务栏/托盘、Start/Search、快捷中心/通知中心、窗口管理、锁屏/登录。先修明显布局或交互错误，后补需要原版证据的细节。
4. 补齐文件管理器、终端和其他适用 Qt 应用；安装兼容、安全与性能回归贯穿各批次。优先复用原生机制、现有工具和必要的版本匹配补丁。
5. 同源问题合并到一个批次；独立任务可同批处理。每批在 testing 上集中提交，更新受影响编号、证据/剩余工作与汇总。静态检查和实机验收分开，不增加无收益的诊断批次。只由维护者授权 CI、PR、main 合并及发布。

## 已知参考阻塞及优先获取方式

- A01/A02、S01、W07：目前已具备原始布局档案。优先复用现有 PRI/XBF 参数证据与提取工具，按组件实际模板、状态及 Photon 启用路径解析。静态资源未覆盖的原版运行时行为再集中请求测量。
- A05–A09：复用已审核资源分支与私有 26H2 导入；仅请求缺失的具体原始角色或光标证据，不重复采集完整 ISO，不提交专有资源。
- D01/D02/D04/D06–D12：先复用已有色阶、缓冲区与 ICC 调研材料，缺失数据在同一个采集批次请求；不以重复诊断代替运行时代码。
- M01/M02、W02/W06、E04：存在宿主结构/合成能力差异。先确认可复用原生接口；需额外补丁、可选插件或无法完全等效时记录方案和影响，交维护者确认。
- 所有跨屏、真实硬件、输入、动画和应用刷新结果属于业主实机验收，不等待此验收才推进独立源码任务。

<a name="block-01"></a>

## 01 全局视觉规范与布局

优先级：P0。依赖：基础，无前置工作块。规范源码归属：`core/design/`、`core/controls/`、`platform/plasma/appearance/` 及 `modules/` 各宿主公共布局与排版入口。

依据与实现记录：[原始布局来源](windows11-26h2-layout-sources.json)、[参数证据](windows11-26h2-ui-parameters.json)、[视觉规范](WINDOWS11_FIDELITY.md)、[样式说明](STYLE.md)。

| ID | 状态 | 任务范围 | 现有实现 / 已知能力 | 剩余工作 / 验收边界 |
| --- | --- | --- | --- | --- | --- |
| A01 | P | PRI/XBF 与 Photon 资源定位 | 19 个原始文件及 1481 个有效 XBF 哈希与本地 26H2 镜像逐字节一致；已解码 25 个核心 XBF 字典并记录偏移（新增 `StartDocked/TileStyles`、`TaskbarSearchPageThemeResources`、`ActionCenter/Styling/Styles.Win11`、`JumpViewUI/RefreshedStyles`、`LockApp/StandardStyles`、`LockApp/CreativeOverlay.LockMDL2Font`、`LogonWebHostStyles`、`SnapLayout/CommonStyles` 及 `21h1_themeresources` 字号/控件/滚动条/菜单/动画常量）；已由 `StartMenuExperienceHost` 与 `Client.Photon` 清单及 `wsxpacks.json` 证实原生 XAML（`StartDocked` + `Client.Core/StartMenu`）承载 Start 外框、固定网格、全部应用、底栏与电源菜单，Photon `Windows.Shell.StartMenu` 仅为嵌入 XAML 的 Recommended 推荐流扩展包 | 按下游具体功能项（S04、T03、E04）继续解析非字典模板节点流与运行时视觉状态切换；静态资源未覆盖的运行时条件分支标 REF |
| A02 | P | 原版布局参数 | 登录凭据宽度 296、快捷中心 376/400/48、搜索框圆角 16、托盘内容边距 4、弹窗与任务栏标准间距 12（`TaskbarMargin=12` / `Metrics_LauncherFrame_Margin=12`）、通用圆角 4/8、菜单最小行高 32、跳转列表 294、通知/日历飞出卡片默认宽度 336（`NotificationCenterFlyoutWidth=360` 扣除 `2×12` 外边距，内层 `312=NotificationCenterFlyoutActualWidth`、分组头 `32`、应用图标 `16`），以及 Start 原版外框 `642×750` / `834×890`（`1600` 阈值、`626×734` / `818×874` 内层表面、`8+25=33px` 外边距、`96×84` 网格、`156×156` 分类卡与 `278px` 账户菜单上限）均已由原版 XBF 验证并接入 | 结合剩余功能工作块核对窗口/文件管理器局部常量，保留并记录宿主适配 |
| A03 | P | 逻辑像素、DPI、窗口和屏幕约束 | 弹窗几何与屏幕可用区裁剪共用 `popupGeometry.js`；补齐 `TaskbarButton`、`TaskbarGlyph`、`AccountAvatar`、`MediaControls`、`MediaCard` 封面、剪贴板图片预览、Start 头像与任务栏预览封面的非零整数 DPR `sourceSize` 守卫；补齐 Login 电源菜单、剪贴板更多菜单、快捷中心底栏/详情页、通知中心与日历月视图方向键/标题、电池进度条、Start 列表/搜索建议/分类折叠箭头/底栏位置栏/`AToolButton`/视图选择器、RTL 顶边对齐任务栏 Search 锚点、锁屏用户切换、`MoreSettingsLink`、`NativeButtonContent` 及 Alt+Tab 卡片的 RTL 镜像，以及 `RunDialog` 窄高屏与多语言按钮宽度自适应 | 下游具体模块的窄屏/多屏与复杂布局细节随各自任务收口，100%/125%/150%/200%、多显示器与 RTL 实机表现待维护者验收 |
| A04 | P | 文字及排版 | 开始搜索和菜单已用系统字体度量；移除锁屏 `MediaControls` 硬编码 `"Segoe UI"` 并补齐 `NoPasswordUnlock`/`SearchHome` 的系统默认字体绑定；为锁屏用户切换、无密码登录按钮、快捷中心标题/亮度/蓝牙状态、Start 菜单/字母索引/分组标题与搜索建议/快捷词补齐 `Text.PlainText` 与省略截断，`RunDialog`、`MoreSettingsLink` 与 `SearchHome` 接入系统字号下限扩展以避免辅助大字号裁切 | 各模块局部字重、行高、基线与原生 Kvantum/Plasma 控件排版细节随 03–10 工作块逐项核对，中英文/CJK IME 与辅助缩放待实机验收 |
| A13 | I | 单一主题、深浅色生成架构 | Plasma、Aurorae、Kvantum 和配色采用共享源/生成路径，保留原有安装接口 | 该范围仅为源码统一；色彩语义归 D16/D17，具体控件差距归各自任务 |
| A14 | P | 公共源码及视觉参数的唯一维护来源 | core、modules、platform、packaging 已建立编辑源；七个 applet、窗口、锁屏/登录、应用、配色和安装工具归类；任务栏两入口共用布局正文；原 436 个映射位置已完成唯一编辑源收敛；追加 166 个 Plasma atlas 原生文件与 4 个图标画布助手输出，现有 579 个生成文件、44 个受校验的源码入口、4 个唯一原生 Nix 表达式；开始、搜索、任务视图和任务按钮共用画布规则；SVG 主题别名已建立唯一维护映射；快捷中心普通/分体磁贴、滑块行与 WinUI 滑块槽/手柄状态尺寸、紧凑行与分组边距/间距/图标槽、可折叠设备列表箭头与展开时长、面板内容边距、登录/锁屏共用时钟与头像/凭据字号/焦点底边条/无密码登录按钮宽度圆角边框/底栏状态按钮几何、数字时钟飞出面板卡片与 28/24px 按钮几何、开始菜单弹出菜单与网格行高/大中应用图标/内嵌滚动预留槽、Snap Layouts 两种预览共享参数、Alt+Tab 小圆角参数，以及跨 Digital Clock、开始菜单、快捷设置和锁屏的 WinUI 通用圆角与菜单最小行高已统一；日历紧凑时钟、搜索筛选/分类、托盘隐藏项/快捷设置组、登录用户切换及快捷设置滑块按钮接入同一 ControlCornerRadius；Start 上下文菜单/视图菜单与锁屏电源菜单共用 WinUI 菜单最小行高；任务栏窗口预览关闭按钮与 RunDialog 主操作按钮接入 ControlCornerRadius；Login 与 LockScreen 电源菜单共用 OverlayCornerRadius，150/160px 宿主宽度集中具名管理并保留现值；Start/Search 快捷搜索与 All Apps 分类卡片、Alt+Tab 卡片、Quick Settings MediaCard/Footer 外层表面、任务栏窗口预览悬停卡片及 NotificationHistory 消息卡片共用独立 cardSurfaceRadius（与外层 overlay 圆角分离并保留各自 UI 缩放）；PageHeader、Bluetooth/Network 详情页与 ClipboardPage 操作按钮共用 detailActionButtonHeight，Clipboard 卡片宽度直接读取共享 FluentScrollBar 轨道宽度；Wi-Fi/Bluetooth/设备列表/ListRow/VolumeMixer 共用 detailRowOuterInset，三类详情行、托盘溢出箭头悬停背景及剪贴板历史条目共用 ControlCornerRadius；SearchBoxRoundCornerRadius 按 TaskbarResources.xbf 原始 16px 参数统一进入 controlMetrics；Start/Search 列表、按钮、搜索框、电源菜单选项、分类标题、字母分组标题与字母索引磁贴微交互统一读取 microInteractionDuration；壁纸包 4 个文件经哈希核对无重复；静态核对 source-map 物化、常规/NixOS/组件安装及打包入口；安装包不依赖源码链接 | 冻结架构清单第 5 项已完成；新 clone/安装/打包及后续功能迭代中的非字节重复语义仍待实机验收；参数真实性归 A02/A08 |

<a name="block-02"></a>

## 02 原始图标与光标

优先级：P0。依赖：A01/A02 提供角色证据；不阻塞其他布局开发。规范源码归属：`icons/windows-modern/`、`core/resources/import/`、`core/controls/`、`packaging/`。

依据与实现记录：[资源导入](NATIVE_ASSETS.md)、[资源审查](NATIVE_COVERAGE.md)、[26H2 审计](windows11-26h2-resource-audit.json)、[光标说明](CURSORS.md)。

| ID | 状态 | 任务范围 | 现有实现 / 已知能力 | 剩余工作 / 验收边界 |
| --- | --- | --- | --- | --- | --- |
| A05 | P | 26H2 原始素材、角色及状态 | 已独立复核本地 26300.9974 镜像 7 项输入哈希与 45 项 shell 输出完全一致（38 电池、4 搜索、2 任务视图、1 头像），并在 NixOS 测试事务中接入可逆 `shell-assets` 准备路径；已核实 `Taskbar.View.dll` 的 Start/TaskView 动态图标为编译态 Win2D/Lottie 类（`AnimatedVisuals.StartLight.cpp`/`StartDark.cpp`），`Client.Core/Icons/WindowsLogo.svg` 为 `12×12` 内联徽章，`StartDocked/PowerOptionsView.xbf` 经 `ShutdownUXViewModel`（`U+EC83`/`U+E708`/`U+E7E8`）分派电源选项，保持 `start-logo.svg` 兼容标注与 `U+E823` 休眠映射不冒充原始静态文件 | 实机核对本地私有部署加载与各状态切换；编译态 Lottie 动态资源不在静态文件导入范围内 |
| A06 | P | 系统控件回退消除 | Start、托盘、时钟铃铛与托盘溢出箭头（`ExpanderArrow`）均已优先解析 `native-assets` 私有角色并在缺失时安全回退；全仓规范源扫描确认 0 处未映射私有图标角色引用；保留 `fcitx`/`kwalletmanager`/`kwin`/`wayland`/`xorg` 等真实平台及第三方身份 | 实机核对动态桌面项、`QIcon::fromTheme` 应用列表与同名多尺寸回退优先级 |
| A07 | P | 系统及应用图标清单 | 基于 26H2 `SegoeIcons.ttf` v1.56 与 `SettingsAppThreshold.pri` 新增远程桌面（`E8AF`）、内存（`EEA0`）、硬件芯片（`E964`）、平板（`E70A`）、传感器温度（`E9CA`）、网络共享（`E968`）、文件关联（`E8E5`）、多磁盘（`EDA2`）、声卡（`E7F5`）、夜间模式（`F08C`）、个性化子项（`E771`）及网络代理/连接（`E774`/`E839`）原版映射，并经 `verify-svg-aliases.py` 补齐 `devices/memory.svg` 与 `devices/network-card.svg` 兼容别名（98 项 KCM 声明覆盖升至 86 项，刻意保留非 Windows 平台专有图标） | 核对系统设置页面内部控件、Sycoca 实际解析路径及共享图标角色消费者 |
| A08 | P | 光学尺寸、状态与命中区 | 托盘已有光学边界补偿与信号组共享画布；移除 `StatusNotifierItem` 与 `BackgroundAppItem` 悬停时的 Breeze 图标增亮（`active: false`），补齐 `BackgroundAppItem` 分数缩放 `roundToIconSize: false`；新增 `TrayMetrics.itemHoverRect` 统一 `ExpanderArrow` 与独立可见托盘项的 40px 悬停/按压圆角背景，对齐溢出箭头 `0.9` 按压缩放与 `SystemTray_IconRotateDuration=300ms` | 100%/125%/150%/200% 分数缩放下的可见墨迹边界、点击命中与视觉居中待实机验收 |
| A09 | I | 原版光标 | 新增 `core/resources/import/import-cursor-assets.py` 私有导入器，校验 `aero.theme` 并将 26H2 全部 17 项 `Cursors/*.cur/*.ani`（含 `beam_r`/`cross_r`/`aero_pin`/`aero_person` 及 18 帧×50ms 动画）与可选 `ole32.dll` 32 位多 DPI 拖放光标组（`dnd-move`/`copy`/`alias`）由直通 Alpha 预乘转换为 `Windows-Modern-26H2` XCursor 主题（`32/48/64/96/128` 像素对映 KDE `24/36/48/72/96` 名义尺寸，150% 缩放 1:1 命中 `48×48` 原始帧，含 79 项 Wayland/Qt/GTK/X11 别名）；接入 `install.sh`、`install-nixos.sh`、`nixos-test-state.py` 与 `uninstall.sh` 可逆安装并保留 `Bibata-Modern-Ice` 公开回退 | Wayland/XWayland/GTK 跨应用光标切换与 150% 缩放热点表现待实机验收 |

<a name="block-03"></a>

## 03 基础控件与菜单

优先级：P0。依赖：A01–A04、A05–A08；与配色工作块独立推进。规范源码归属：`core/controls/`、`platform/plasma/appearance/atlas/`、`platform/qt/kvantum/`、`modules/desktopmenu/`、`platform/plasma/desktopmenu/`。

依据与实现记录：[公共控件证据](NATIVE_COVERAGE.md#shared-native-widget-geometry)、[UI 参数](windows11-26h2-ui-parameters.json)、[样式规范](STYLE.md)、[弹窗约定](PANEL_UI_CONTRACT.md)。

| ID | 状态 | 任务范围 | 现有实现 / 已知能力 | 剩余工作 / 验收边界 |
| --- | --- | --- | --- | --- | --- |
| A10 | P | 基础控件外观与各状态 | Plasma/Kvantum 已共享滑块与按钮基础几何；`controlMetrics.js` 接入 `21h1_themeresources.xbf` 的 `83ms/167ms/250ms` 动画常量并统一 `FluentSwitch`；补齐 Start `AToolButton` 按压填充与 `0.4` 禁用态及键盘/无障碍守卫、`ViewModeMenu` 按压态与 RTL 锚点、`FlyoutButton` RTL 文本对齐，全量扫描 165 个 Plasma atlas SVG 修正无效 CSS 类 | 继续分渲染器（Plasma KSVG / Kvantum / 原生 Qt）核对复选/单选、进度条、按钮高程边框渐变及焦点环细节，待实机验收 |
| A11 | P | 文本输入、列表、滚动、下拉及标签页 | 修正 `widgets/lineedit.svg` 四处无效小写 `ColorScheme-text` 并对齐 `DefaultTextBoxStyle` `TextControlThemePadding = 10/5/6/6`；`NetworkPage` Wi-Fi 密码框改用原生 `PlasmaComponents3.TextField`（32px 最小高度、2px 焦点底边强调色条与 RTL 内边距镜像）；`FluentScrollBar` 与 Kvantum 统一 `ScrollBarVerticalThumbMinHeight = 30` 及 `83ms/167ms` 透明度/展宽动画，补齐 `ShutdownMenu` 与 `EmojiPicker` 悬停/滚动联动；`ListRow` 接入 `3×16→10px` 选中竖条与 RTL 镜像，`ClipboardPage` 标签页补齐按压态与 `18→12px` 指示条收缩 | 核对通用 Kvantum/Qt 树视图、可编辑/不可编辑 `QComboBox` 弹层、多行输入框与触控板惯性滚动实机表现 |
| A12 | P | 菜单、弹窗、提示框公共样式 | 共享 FrameSVG 模板与 `9/6/9/8` tooltip padding；补齐 `widgets/menubaritem.svg` 与 `appearance-packages.py` 缺失的 `.ColorScheme-Text` 深浅色规则，补齐 `NativeMenuItem` 与桌面右键菜单 `QMenu` 的 RTL 文本/图标边距镜像 | 核对原生 Qt 应用子菜单阴影/圆角、复选菜单项指示器与异步 tooltip 定位限制；材质算法归 M01–M04 |
| C01 | I | 桌面右键菜单与更多选项 | 基于 26H2 `FileExplorerExtensions.dll` 与 `Microsoft.WindowsTerminal`（`OpenTerminalHere`）对齐完整动词分组与顺序（查看、排序方式、刷新、条件性下一个桌面背景｜粘贴｜条件性撤销/重做、新建｜显示设置、个性化｜经 `KTerminalLauncherJob` 接入在终端中打开｜显示更多选项）；保留真实 `QAction` 实例、快捷键与动态可用性，保留 `KNewFileMenu` 新建子菜单真实文件夹/模板图标；支持可选 `shell-assets/context-menu/{dark,light}/*.svg` 双色图标与实时 `QPalette::Highlight` 强调色替换、`SegoeIcons.ttf`（`ECC8`/`E8A7`/`E756` 等）回退、`1.0–2.0x` 多 DPR 禁用态半透明图标、中英文翻译与 RTL 样式镜像 | 桌面与文件夹模式、终端启动及多语言/RTL 菜单交互待维护者实机验收；Dolphin 文件菜单归 E04 |

<a name="block-04"></a>

## 04 动态配色与材质

优先级：P0。依赖：A01/A02 的主题角色；D01–D19 和 M01–M04 可按独立根因并行。规范源码归属：`core/palette/`、`core/materials/`、`core/transactions/`、`platform/plasma/appearance/`、`platform/qt/kvantum/`。

依据与实现记录：[动态配色证据](NATIVE_COVERAGE.md#dynamic-accent-source-completion-ledger)、[ICC 研究](windows11-26h2-icc-investigation.md)、[色彩捕获](windows11-26h2-accent-captures.json)、[材质约定](WINDOWS11_FIDELITY.md#native-material-implementation-boundary)。

| ID | 状态 | 任务范围 | 现有实现 / 已知能力 | 剩余工作 / 验收边界 |
| --- | --- | --- | --- | --- | --- |
| D01 | I | 手动预设分派和 48 组色阶 | 已由本地 26300.9974 `System32/uxtheme.dll`（`@0x73E80`）与 `windowsudk.shellcommon.dll`（`@0x5DE680`）1,536 字节 `48×8` `COLORREF` 表逐字节复核全部 48 组预设主色与 288 个派生色阶（共 336 个 RGB 值 0 差异），并导出精确 `6×8` 设置色块网格 `PRESET_SWATCH_GRID` | 实机切换各预设色阶与跨渲染器视觉效果待维护者验收 |
| D02 | P | 自定义饱和色 CIELAB 和近灰 HSL | 两个分支存在 | 校验原始输入、分界和舍入；REF |
| D03 | I | 位图加权统计及多图汇总 | 已有实现，记录的缓冲区案例相符 | 任意真实桌面输入待验收；解码边界归 D06–D12 |
| D04 | P | 自动候选归一化及回退 | 原生归一化和七色阶生成已实现 | 确定饱和度/亮度精确边界；REF |
| D05 | I | Colorization strength（Alpha）计算 | 已有基于测量的候选公式，与材质透明度分离 | 更广图片范围待验收 |
| D06 | P | 不透明 BMP/JPEG/PNG/WebP 解码和方向 | 已有解码路径 | 核对 WIC 各格式及像素变体，禁止泛化少量测量 |
| D07 | P | 透明 PNG | RGB/GrayAlpha 共用路径已存在 | 核对 ICC 标记 GrayAlpha、其他像素模式与原版边界 |
| D08 | O | 透明非 PNG 和未审查像素格式 | 尚无经确认的解码路径 | 确定 Windows 支持及其处理方式再实现；REF |
| D09 | I | 已审查 RGB matrix/TRC ICC | 独立表生成及测量控制的全域证据 | 仅此输入范围；其他 profile 归 D11/D12 |
| D10 | I | 已审查 D50 Gray8 monitor ICC | 独立网格和两组 gamma 原版数据 | 扩展 sampled/v4 曲线需补原版对比，不将扩展范围视为已验收 |
| D11 | O | Forward RGB LUT ICC | 输入/输出曲线和测量执行已有，独立 CLUT 尚未还原 | 恢复原生坐标归一化与受支持 profile 分派；禁止拟合表替代；REF |
| D12 | O | 其他 ICC 家族与组合 | 尚未确定 Windows 解码的完整支持范围 | 确认范围并实现，禁止静默近似转换；REF |
| D13 | I | 原生壁纸发现、事件和缓存失效 | Plasma 静态/幻灯片/定时壁纸适配、WallpaperAccentSource 与事件/缓存路径已有 | 仅计现有托盘宿主中的路径；多屏、活动、分辨率、文件替换待验收。生命周期耦合归 V08 |
| D14 | I | 强调色选择所有权及原始 RGB 持久化 | 原生选择优先级、待同步状态、事务写入和手动重算已有 | 旧状态无原始输入时保留；竞争/切换待验收 |
| D15 | I | Windows 风格颜色选择界面和交互 | 新增 `ConfigColors.qml`（系统托盘/快捷设置配置“颜色”页及快捷设置深色模式磁贴右键入口）与 `switch-mode.sh --status-json`/`--reset-native-accent`：支持浅色/深色切换、自动壁纸取色、`6×8` 48 色原版色块网格、`ColorButton` + `#RRGGBB` 自定义输入、7 色阶预览，以及 KDE `kcm_colors` 原生强调色覆盖检测与一键恢复“使用当前配色方案” | KDE 原生 `kcm_colors` 保持独立系统模块边界；实机交互与模式联动待维护者验收 |
| D16 | I | 深浅色七色阶发布、主填充及链接角色 | 生成的配色及 Kvantum 使用对应模式色阶 | 该范围仅为发布路径；独立角色归 D17 |
| D17 | P | 独立选择背景、按压/悬停与 on-accent 角色 | `Win11Palette` 与 `colorType.js` 补齐 `90%/80%` 强调色悬停/按压合成（`AccentFillColorSecondary`/`Tertiary`）、禁用态填充与 `TextOnAccentFillColorDisabled`，统一 `FlyoutButton`、日历今日/当前年月圆标与 Search 筛选胶囊的悬停/按压/对比字色，并为登录/锁屏输入框补齐 `#0078D4` 文本选中背景与 `#FFFFFF` 选中文本 | KDE 全局 `.colors` 的 `Colors:Selection` 仍同时承担第三方 Qt 控件 `QPalette::Highlight`，需继续分渲染器核对通用 Qt 文本框与列表选中表现 |
| D18 | P | 现有应用实时刷新 | 已有版本匹配 Qt6 Kvantum 1.1.9 路径 | 其余渲染器/版本刷新、开着的应用刷新与实际进程行为未证实 |
| D19 | I | 强调色与安装、模式切换集成 | 初始化和同步路径存在 | 完整安装、升级和动态切换待业主验收 |
| D20 | P | 配色/材质的计算、宿主控制、渲染和事务边界 | `core/palette/accent-algorithms.py` 独立持有预设/CIELAB/HSL 色阶、对比色、手动批次比对及壁纸解码/ICC 预变换/加权取色算法；`core/palette/accent-renderers.py` 独立持有 KDE `.colors` 渲染、Kvantum 强调色绑定与 `live-reload.json` 回执发布；`core/transactions/theme-files.py` 独立持有文件归属验证、原子替换与回滚；`platform/plasma/appearance/appearance-host.py` 独立持有 KDE 配置读取、模式/渲染器判别与实时壁纸 D-Bus 快照校验，`accent-control.py`、`window-frames.py`、`appearance-packages.py` 与 `sync-accent.py` 全部改为 `importlib` 显式模块接口并保留原有命名导出及锁/版本缓存/回滚契约；非 Kvantum 控件样式或无用户目录 Kvantum 时正常同步 KDE `.colors`、Plasma 调色板、Aurorae 标题栏及弹窗透明选择器，Kvantum 本地资源不完整或外链时仍严格拒绝 | 冻结架构清单第 8 项已完成（架构改革 8/8 全部收口）；后续随 D17/M02 等功能还原演进并待维护者实机验收多渲染器与异常竞争场景 |
| M01 | P | Acrylic 临时表面 | 共享弹窗生成器和 KWin blur，透明关闭时有不透明路径；`PopupEffects` 新增监听并遵循 `windows-modern/transparency-off` 标记，已核实 `Win11Palette` 暗色分离弹层 `#1C1C1C` 与日历 `#09FFFFFF` 对应 `21h1_themeresources.xbf` 角色 | 按原版角色核对背景采样、tint/luminosity、噪声、边缘与合成；不另建无必要渲染器 |
| M02 | P | Mica 长期窗口表面 | 现有方案为壁纸静态平均 tint，活动/非活动状态有实现 | 确定目标 Mica 算法和可行的宿主实现，解决空间采样与窗口状态；明确不能达到的宿主边界 |
| M03 | I | 透明度切换及事务同步 | 现有共享锁、检查式写入、回滚、solid 选择和偏好保存路径 | 仅指源码事务路径；异常终止和实机合成验收另记 |
| M04 | P | Smoke 模态遮罩与其他表面材质分派 | 完成全仓 19 个模块的弹层/模态/面板表面逐消费者盘点：临时飞出面板与上下文菜单遵循 `DialogShowingWithoutSmokeLayer` 不加全局遮罩，`colorType.js`/`Win11Palette` 暴露 `SmokeFillColorDefault = #4D000000` 供模态对话框使用，分体式快捷设置/媒体/通知/日历卡片统一遵循 `transparency-off` 回退，非 WindowsModern 高对比度配色方案保持原样不被覆盖 | KWin 系统级模态父窗口变暗特效与第三方 Qt 应用模态对话框表现待维护者实机验收 |

<a name="block-05"></a>

## 05 任务栏与系统托盘

优先级：P1。依赖：A03/A08/A10/A12；配色与材质由 04 统一。规范源码归属：`modules/taskbar/`、`modules/systemtray/`、`modules/taskview/`、`modules/showdesktop/`、`platform/plasma/taskbar/`、`platform/plasma/systemtray/`。

依据与实现记录：[面板约定](PANEL_UI_CONTRACT.md#taskbar)、[视觉规范](WINDOWS11_FIDELITY.md#tray-geometry-and-current-plasma-compatibility)、[托盘架构](PLASMA_SYSTEMTRAY_ARCHITECTURE.md)。

| ID | 状态 | 任务范围 | 现有实现 / 已知能力 | 剩余工作 / 验收边界 |
| --- | --- | --- | --- | --- | --- |
| T01 | P | 任务栏布局和定位 | 居中布局、48px 高度、`30px` 共享图标画布与 `TaskbarConstants.xbf` 参数（`MediumTaskbarButtonExtent=44`、`TaskbarButtonHitTestableMargin=2/4/2/4`）已核实；补齐 `publishIconGeometries` 销毁期空值守卫与 `Plasmoid.containment` 空屏安全回退 | 对比极端窄屏任务栏溢出弹层（`OverflowToggleButton` 宿主差异）、多显示器独立任务栏配置与用户自定义布局实机表现 |
| T02 | P | 任务按钮及原生窗口动作 | Icon Tasks 已有任务模型、固定/启动、预览和关闭路径；按 26H2 `TaskListButtonResources.xbf` 统一非活动运行窗口与最小化窗口的短胶囊指示条（`normal-center` 与 `minimized-center` 共用 4 单位短胶囊，与活动窗口 10 单位强调色胶囊区分），新增多窗口分组层叠背板（`MultiWindowElement`）、任务按钮按压缩放回弹及 `Ctrl+Shift+Left/Right` 边界与 RTL 顺序修正 | 核对多屏/多条带溢出、拖拽重排及 `Win+1..9` 实机交互 |
| T03 | P | 任务栏右键菜单和跳转列表 | 按 26H2 `JumpViewUI/RefreshedStyles.xbf`（`TaskbarJumpListFrameWidth = 294 @5862`）对齐 `ContextMenu.qml` 294px 最小宽度，修复 MPRIS 播放/暂停实时状态绑定，并在 `Backend` 与 `Plasmoid.contextualActions`/`ContextMenu` 接入真实系统监视器“任务管理器”（`plasma-systemmonitor`/`ksysguard`）入口 | 原生 `PlasmaExtras.Menu`（`QMenu`）承载跳转列表，与原版独立 XAML 固定图标列存在宿主差异；各应用动作与键盘导航待实机验收 |
| T04 | P | 托盘状态、隐藏区及原生应用图标 | 保留真实状态模型、5 列隐藏网格、用户固定/隐藏偏好；扩展 `WindowsTray::systemOrder` 与 `BaseRole::NativeCapture` 使麦克风与屏幕共享捕获指示器与摄像头隐私指示器同列位于输入法及核心状态组之前，移除 `HiddenItemsView` 重复的 `PlasmaExtras.Highlight` 叠加并统一 4px 悬停/键盘焦点圆角底板 | 核对真实第三方 SNI 图标出现/消失、USB/蓝牙动态插拔与高分屏实机表现 |
| T05 | P | 系统状态组的布局和交互 | 网络/音量/电池共用连续悬停圆角底板并补齐按压/展开态过渡动画；`PlasmoidItem` 补齐电池已充满、充电中、已接通电源、节能模式（`PowerProfilesControl`）单行状态提示，以及离线/飞行模式时从 `toolTipSubText` 提取真实网络状态单行提示 | 多显示器、真实充电/省电切换、音频静音与网络断线实机验收 |
| T06 | I | 启动器、任务视图、搜索按钮与显示桌面入口 | Start 补齐 Tab 焦点高亮、`Space`/`Enter` 键盘激活与关闭态单行提示；Search 框/胶囊模式补齐关闭态提示并保持 `220/36` 及 `11/37/16` 原版内边距；Task View 使用双色原版资源调用 KWin Overview；Show Desktop 补齐 RTL 屏幕边缘镜像命中、按压/悬停管道色阶（`ShowDesktopPipePointerOver`/`ShowDesktopPipePressed`）、活动态微光及无障碍勾选状态 | 不同面板方向、缩放比例与组合布局待维护者实机验收；弹层内部行为归 S/W |
| T07 | P | 任务预览和 tooltip 生命周期 | 共享启动器单行名称与窗口缩略图浮层（`12px` `ToolTipMargin`、`32px` 独立关闭区、16px 窗口图标关闭整数吸附）；补齐预览收起与 `ToolTipWindowMouseArea` 销毁时自动清除 `KWin.HighlightWindow` 预览高亮及多处空父项守卫 | 核对多窗口超宽横向滚动、指针快速穿越、PipeWire 首帧延迟与关闭动画实机表现 |

<a name="block-06"></a>

## 06 开始菜单与搜索

优先级：P1。依赖：A01/A02/A04/A08、A11/A12；T06 为入口。规范源码归属：`modules/startmenu/`、`modules/search/`。

依据与实现记录：[面板约定](PANEL_UI_CONTRACT.md#start-and-search)、[Start 参数证据](NATIVE_COVERAGE.md#shared-control-evidence-and-credential-hosts)、[视觉规范](WINDOWS11_FIDELITY.md#start-and-search-use-distinct-widths-at-the-same-height)。

| ID | 状态 | 任务范围 | 现有实现 / 已知能力 | 剩余工作 / 验收边界 |
| --- | --- | --- | --- | --- | --- |
| S01 | I | 开始菜单整体布局 | 按 26H2 `StartResources.xbf`（`Metrics_SmallStartWidth/MaxHeight = 642×750`、`Metrics_LargeStartWidth/MaxHeight = 834×890`、`Metrics_LargeStartScreenWidthThreshold = 1600`、`PinnedListItemWidth/Height = 96×84`）与 `StartCP3SearchBoxMargin = 33` 对齐 `popupPosition.js` 与 `MenuRepresentation.qml`（扣除 8px KSVG 外框后内层 `626×734` / `818×874`、`margin = 25` 即 `8+25=33px` 外边距，精确生成 `576 = 6×96` 小号与 `768 = 8×96` 大号内容列、`56+8=64px` 底栏及全空分区提示） | 多显示器、极端窄高屏裁剪与 100%/125%/150%/200% 实机排版待维护者验收 |
| S02 | P | 固定、推荐、全部应用和分类 | 补齐大号 Start 8 列固定/网格视图（`>= 768px`）与 3 列首页推荐流、小号 6 列固定与 2 列推荐流；按 `StartResources.xbf` 与 `TileStyles.xbf` 对齐 `156×156` 分类卡片（`AllAppsCategoryCardWidth/Height = 156`）与 `40px` 列表行/分组头高度（`Metrics_AllAppsGridItem/Header_Height_Stack = 40`），保留 `>= 3` 应用建类阈值与真实 Kicker 模型，不添加假服务 | KDE Kicker `FavoritesModel` 为扁平收藏列表，不支持原版固定区自定义应用文件夹合并（All Apps Category 视图独立提供分类文件夹）；拖拽重排与各视图切换待实机验收 |
| S03 | I | 字母索引、分类切换和键盘 | 保留 ICU 拼音/假名/谚文与 `#`/`world` 分组；补齐 `AllAppsPage` 分类卡片网格与分类展开网格的键盘方向键导航（`keyNavigationEnabled`）及顶行回退焦点链，修复 `AlphabeticalAppsView` 与 `LetterIndex` 的 RTL 左右方向键镜像，补齐 `LetterIndex` `Home`/`End` 首尾可用字母跳转、`OpenKeySpline`/`CloseKeySpline` 缩放曲线，以及分类/字母索引统一的 `AToolButton` 返回按钮 | 读屏器播报与多语种输入环境下实机交互待维护者验收 |
| S04 | P | 搜索首页、结果及页面几何 | `popupPosition.js` 同步将 Search 调整为与 Start 等高且保持约 `1.21×` 外框宽度的 `758×734` / `992×874` 内层尺寸（对应 `774×750` / `1008×890` 外框）；`SearchHome` 统一接入 `StartScrollBar`，`SearchPage` 补齐筛选胶囊 RTL 排布、`24px` 非整数缩放结果图标与 150ms 防闪烁无结果提示（`wmStartSearchNoResults`） | `SearchUx.Core.dll` 宽版 Search 运行时目标宽度尚待同缩放截图实机标定；素材归 A05，入口/状态协议归 V07/V08 |
| S05 | I | 搜索真实功能和输入 | 复用 Kicker/Milou 本地应用、文件、系统设置、电源动作、计算器与单位换算及 `SearchHome` 本地建议/快捷搜索/常用应用（无在线推广）；为 `StartSearchField` 新增尾随清除按钮（`wmStartSearchClearButton`，动态扩展 `trailingInset` 并支持 RTL 镜像与清除后保焦），保留 CJK IME 预编辑临时显影与完整键盘导航 | 不同输入法框架（Fcitx5/IBus）与本地索引实机响应待维护者验收 |
| S06 | I | 账号、电源和上下文菜单 | 按 `TileStyles.xbf`（`Metrics_AccountBadgeMenuFlyout_MaxWidth = 278`）、`UserTileView.xbf` 与 `PowerOptionsView.xbf` 对齐底栏弹层宽度上限与菜单职责分离：账户菜单承载账户设置、锁定、注销与切换用户，电源菜单承载睡眠（遵循 `showSleepButton`）、休眠、关机、重启（遵循 `showRestartButton`）及无可用电源项提示（`ShutdownNoChoicesTextBlock`）；`ContextMenu` 补齐多 Activity `subActions` 子菜单展开与勾选项显示 | 真实会话锁定、切换用户、睡眠/休眠与多 Activity 收藏待维护者实机验收；系统认证归 L01/L02 |
| S07 | P | 开始/搜索动效和自身状态 | 内部子页与弹层（`RecommendedPage`、`AllAppsPage` 分类浮层、`LetterIndex`）接入 `StartResources.xbf` 的 `OpenKeySpline = 0,0 0,1` / `CloseKeySpline = 1,0 1,1` 并遵循系统减弱动画门控；补齐任务栏 Search 打开时点击 Start 原地切换回 Start 首页、点击任务栏 Search 图标/胶囊或 `Win+S` 对称收起、点击任务栏完整搜索框保持焦点等状态机切换 | 外层 `PlasmaCore.Dialog` 打开/收起位移动画受 KWin/Plasma 宿主控制，与原版 `StartSlideDistance` 的实机观感及焦点恢复待维护者验收；跨弹窗关系归 Q15 |

<a name="block-07"></a>

## 07 快捷中心与通知中心

优先级：P1。依赖：A01–A04/A08/A10–A12、T05；M01 负责材质。规范源码归属：`modules/quicksettings/`、`modules/clipboard/`、`modules/calendar/`、`modules/notifications/`、`platform/plasma/popup/`。

依据与实现记录：[快捷中心约定](PANEL_UI_CONTRACT.md#quick-settings)、[通知日历约定](PANEL_UI_CONTRACT.md#calendar-and-notifications)、[原版参数](windows11-26h2-ui-parameters.json)、[托盘实现](../plasma/applets/org.kde.windowsmodern.systemtray)。

| ID | 状态 | 任务范围 | 现有实现 / 已知能力 | 剩余工作 / 验收边界 |
| --- | --- | --- | --- | --- | --- |
| Q01 | I | Win+A 面板布局及底栏 | 按 `controlcenterstyles.xbf` 对齐 `376px` 分页卡片、`328px` 内容组、`24px` 边距、`400px` 二级详情页最小高度与 `48px` 底栏；补齐 `ActionPanel` `Plasmoid.containment` 空屏安全回退与 `Footer` RTL 子项镜像，电池按 `hasBattery` 条件展示并由设置齿轮接入真实系统设置/快捷菜单 | 不同缩放、多屏工作区与历史底栏反馈待维护者实机复验 |
| Q02 | I | 快捷开关、分页、重排 | 保持三列网格、行吸附滚动、条件分页圆点/翻页箭头、拖拽边缘自动滚屏及 `quickSettingsOrder` 隐藏槽位持久化；为 `Tile`/`SplitTile` 补齐键盘菜单键（`Key_Menu`）右键入口，并为 `Page`/`DetailPage` 补齐 `Alt+Left`（RTL `Alt+Right`）/ `Back` 返回快捷键 | 触控屏与多页拖拽实机体验待维护者验收 |
| Q03 | P | 亮度与音量主滑块 | 共享 `27px` 对称端槽、`4px` 轨道与 `18px` 外手柄（`12/14/10px` WinUI 内核态）、120 角度/40px 滚轮聚合、键盘静音及 `F4C3` 原版声音输出角色 | 多外接显示器场景下 PowerDevil 仅暴露不透明显示标识，仍需原生连接器映射方可消歧（当前按约定禁用主轨并引导进入详情页） |
| Q04 | I | Wi-Fi/网络详情 | 复用 `PlasmaNM` 真实扫描与连接模型、单卡片互斥展开（`NetworkSelection`）、WEP/WPA/SAE 密钥校验与显隐切换、连接中进度条；新增 `Activating -> Deactivated` 非主动断开时的连接失败状态反馈（`Can't connect to this network`）及详情页 RTL 继承 | 真实企业级 802.1X、热点切换与弱信号失败场景待维护者实机验收 |
| Q05 | I | 蓝牙详情 | 复用 `BluezQt` 与 `SharedDevicesStateProxyModel`，单连接设备显示 `friendlyName`/多设备显示数量，详情页支持开关切换、添加设备向导、分组列表（补齐 `PlainText`/省略截断与 RTL 边距）、连接/断开及失败状态提示 | 真实蓝牙耳机/外设配对、重连与动态改名待维护者实机复验 |
| Q06 | I | 音频详情和混音 | 保留输入/输出设备折叠路由（首选设备缺失但存在真实设备时保持可选）；为 `VolumeMixerSection` 新增应用图标点击/键盘独立静音切换（`wmVolumeMixerAppMuteButton`）与静音视觉反馈，并为 `InputDeviceSection` 新增麦克风输入音量与静音滑块 | 多声卡/蓝牙音频热插拔与应用流动态增减待维护者实机验收 |
| Q07 | I | 电池与电源模式详情 | `Footer` 电池入口、`BatterySaverToggle` 先前电源模式记忆恢复及 `BatteryPage` 真实 `BatteryControlModel`/`PowerProfilesControl`/`InhibitionControl` 联动完备；修复无电池台式机从节能磁贴右键进入时的动态标题（`Power Mode`）与隐藏空电池块，补齐电量进度条 RTL 镜像 | 笔记本充放电剩余时间、多电池健康度与 `power-profiles-daemon` 实机切换待维护者验收 |
| Q08 | P | 媒体卡片 | 接入 MPRIS、`178px` 高度预算、`12px` 卡片间距、应用来源识别与 `Previous`/`Next` `250ms` 连发；为 `MediaCard` 封面补齐非零整数 DPR `sourceSize` 守卫与圆角 `OpacityMask` 裁切 | 短屏紧凑桌面下媒体卡片与磁贴分页共存预算及媒体时间进度呈现仍待原版实机对比确认 |
| Q09 | I | Win+V 剪贴板 | 复用真实 Klipper 历史（`moveToTop` 保留完整 MIME）、多类型文本/图片预览（补齐非零整数 DPR `sourceSize` 与 RTL 对齐）、固定/删除、保护已固定项的条件 `Clear all`、隔离加载的 `EmojiPicker`（新增 `wmEmojiSearchClear` 清除按钮与表情/颜文字/符号网格方向键及回车选取），并补齐剪贴板列表 `Up`/`Down` 键盘导航与 `Delete` 键删除 | Wayland 下跨应用粘贴、大图历史与 Fcitx5 联动待维护者实机验收 |
| Q10 | P | Win+K 投屏 | `ActionPanel` 在检测到 `org.gnome.NetworkDisplays` 时显示 `Cast` 磁贴（补齐悬停提示），并在 `windows-shortcuts.py` 中仅当桌面存在 `org.gnome.NetworkDisplays.desktop` 且 `Meta+K` 未被占用时条件绑定/备份恢复 `Win+K`，不制造虚假入口 | KDE Plasma 6 无内置原生快捷中心 Miracast 子页，当前委托独立 `NetworkDisplays` 窗口处理设备发现与连接，保留宿主边界说明 |
| Q11 | I | 其余快捷开关及条件可用性 | 逐项核查全部 10 个快捷磁贴（网络、蓝牙、飞行模式、节能、夜间模式、深色模式、麦克风静音、移动热点、投屏、辅助功能）：均绑定真实系统后端并按硬件/服务可用性条件显隐，排除未接通 Wayland 原生服务的 `TouchpadToggle` 占位实现，补齐 `Cast`/`Accessibility` 提示文本 | 各硬件开关在不同内核/驱动环境下的可用性待维护者实机验收 |
| Q12 | P | Win+N 通知/日历整体几何 | 按 26H2 `Styles.Win11.xbf`（`NotificationCenterFlyoutWidth = 360`、`NotificationCenterFlyoutMargin = 12,8,12,0`、`NotificationCenterFlyoutActualWidth = 312`）将默认飞出卡片宽度由 `320` 对齐为 `336px`（内层 `336 - 2×12 = 312px`），保留日历折叠、多时区/议程高度预算与短屏裁剪保护 | 非空通知区 `420px`（外框 `444px`）目标高度仍属比例适配，需在目标环境实机复核非空/清空与短屏表现 |
| Q13 | I | 通知内容、历史、toast 和勿扰 | 共享 `NotificationManager` 历史与传输进度（`Clear all` 不取消运行中任务）；按 `Styles.Win11.xbf` 与 `styles.xbf` 对齐 `32px` 通知应用分组头最小高度（`GroupHeaderMinHeight`）与 `16px` 应用图标（`AppLogoIconSize`、`roundToIconSize: false`），补齐内联回复框 `32px` 最小高度、勿扰横幅 RTL 对齐及 `FocusSession` 倒计时恢复 | 真实应用通知动作、富文本链接、内联回复与勿扰规则实机交互待维护者验收 |
| Q14 | I | 日历与时钟 | 保持区域日期/时间、显式 12/24 小时制、独立翻译 `calendarLocale`、月/年/十年三级原位缩放、120 角度与触控板单次翻页防惯性连跳、多时区去重及日程列表；补齐 `CalendarView` 月视图左右方向键与月份标题按钮的 RTL 镜像，以及 `CalendarGrid`/`CalendarZoomGrid` 减弱动画（`shortDuration <= 0`）无闪烁守卫 | 触控板手势、节假日插件与跨日午夜刷新待维护者实机验收 |
| Q15 | I | 跨弹窗互斥、焦点和独立开关 | 同面板 `PanelPopupHost` 统一持有 `PanelPopupController` 与 `PopupEffects`，保持 `tray`/`clock` 互斥、`start` 同焦点组独立共存及 `180ms` 外部失焦收起与 `pin` 保持打开；修复 `Win+V` 剪贴板通过 `Esc`、关闭按钮、条目选取或二次按 `Win+V` 关闭时未调用 `restoreShellPopupFocus()` 的焦点组断链问题 | 多面板、多显示器点击切换与焦点恢复实机表现待维护者验收 |

<a name="block-08"></a>

## 08 窗口管理与动画

优先级：P1。依赖：A03/A08/A10/A12、M02；与 Shell 组件并行。规范源码归属：`modules/windowmanager/`、`modules/run/`、`platform/plasma/shortcuts/`。

依据与实现记录：[窗口视觉规范](WINDOWS11_FIDELITY.md#native-material-implementation-boundary)、[应用标题栏](APP_WINDOW_CHROME.md)、[样式规范](STYLE.md#alt-tab-window-switcher)。

| ID | 状态 | 任务范围 | 现有实现 / 已知能力 | 剩余工作 / 验收边界 |
| --- | --- | --- | --- | --- |
| W01 | P | 窗口装饰和标题栏 | Aurorae 深浅色共享源码（`30px` 标题栏高、`46×30px` 最小化/最大化/关闭命中区、`1px` 边框、`12px` 阴影外边距、活动/非活动文字与底色区分及 `#C42B1C` 关闭悬停）已统一由 `window-frames.py` 生成 | 活动/非活动切换、双击最大化、标题栏右键菜单及 150% 分数缩放边缘表现待维护者实机验收 |
| W02 | P | 窗口圆角和阴影 | 顶部 `8px` 圆角、活动/非活动阴影及最大化/全屏无圆角已接入；明确遵循 KWin 6.8 原生圆角边界，不对任意客户端内容施加硬裁剪遮罩 | Aurorae V2 不暴露底部客户区圆角参数，且无边框 Konsole 外角仍受合成器协议限制（待上游 KDecoration3/CSD 圆角或可选效果评估） |
| W03 | P | Alt+Tab 切换器 | KWin `TabBoxSwitcher` 居中浮层支持等高按窗口宽高比自适应卡片、自动换行居中、中键/悬停关闭按钮（补齐按压深红反馈）、软件渲染无遮罩降级及多屏当前屏幕定位；补齐 `SwitcherView` 图标 `roundToIconSize: false` 及 RTL 行内卡片排布与左右方向键镜像 | 多显示器焦点屏切换、大量窗口滚动及快速连按 `Alt+Tab` 实机表现待维护者验收 |
| W04 | P | Win+Tab 任务视图及虚拟桌面 | `Task View` 任务栏按钮（优先加载 26H2 双色调原始素材）与 `windows-shortcuts.py` 统一将 `Win+Tab` 绑定至 KWin 原生 `Overview`（保留真实窗口堆叠、搜索与虚拟桌面增删切换后端） | 原生 KWin Overview 顶部虚拟桌面条与 26H2 底部桌面缩略条存在宿主布局差异，待维护者实机确认是否保持原生呈现 |
| W05 | P | Snap Layouts 布局选择和贴靠 | 拖至顶边 `SnapBar`（`72×44` 六布局自适应窄屏缩放）与可选 Konsole 最大化按钮悬停 `CaptionSnapPicker` 共用 `layouts.js` 整数像素无隙网格与 `minSize`/`maxSize` 校验，补齐 `90ms` 悬停微交互过渡（受 `shortDuration > 0` 门控） | 通用 Aurorae 窗口最大化按钮悬停未受 KWin 暴露独立脚本钩子，实机拖拽与多屏跨屏释放待维护者验收 |
| W06 | P | Snap Assist、持久贴靠组与后续填充 | 新增 `SnapAssistPicker.qml` 与 `layouts.js` 剩余槽位/占用检测（`sameCellGeometry`、`remainingLayoutCells`）：在拖顶或标题栏贴靠完成后自动跳过已占用槽位，在下一个空槽中心展示当前桌面候选窗口缩略图选择器（`KWin.WindowThumbnail`、`roundToIconSize: false`、软件渲染降级、不抢占已贴靠窗口 Wayland 焦点），支持 2/3/4 分区顺序连续填充并在激活其他窗口、移动/关闭已贴靠窗口或切屏/切桌面时自动收起 | KWin 脚本层不提供跨任意 3/4 分区的任务栏持久贴靠组集合或联动分割线拖拽（KWin 自定义平铺树为桌面全局而非成对窗口组），已在 `APP_WINDOW_CHROME.md` 记录合成器边界并待实机验收 |
| W07 | P | 窗口生命周期和系统动效 | 完成 26H2（`21h1_themeresources.xbf` `167/333/500ms`、`SystemTrayResources` `300ms`、`LockApp` `100/200/400/750/0ms`）与全仓 KWin/Plasma/QML 动效盘点并归档至 `WINDOWS11_FIDELITY.md`；补齐锁屏 `MainBlock` `errorPulse`、`SnapBar`/`CaptionSnapPicker`/`SnapAssistPicker` 等全部 QML 微交互对系统减弱动画（`Kirigami.Units.shortDuration <= 0`）的零时长门控 | KWin 原生打开/关闭/最小化/最大化曲线与 26H2 DWM 体感对比待维护者实机验收 |
| W08 | P | OSD 与全局快捷键 | `osd/contents/code/main.js` 将音量、亮度、麦克风、键盘布局等原生 OSD 统一重定位至当前工作区底部居中（底边上 `12px`，防重入且多屏安全）；`windows-shortcuts.py` 完整覆盖 `Win+Up/Down`（`snapkeys`）、`Win+Tab`、`Win+R`、`Win+M`、`Win+Home`、`Win+A/N`、`Win+V`、`Win+K`（条件绑定）、`Win+PrtSc`/`Alt+PrtSc` 与 `Ctrl+Shift+Esc`，冲突检测与备份恢复齐备 | OSD 内部条目仍复用 Plasma 原生 OSD 内容布局（未重写独立 QML OSD 服务），实机按键无冲突表现待维护者验收 |
| W09 | I | Win+R 运行窗口 | `RunDialog.qml` 接入真实命令执行、多屏工作区居中、窄高屏与大字号自适应、IME 组合态保护及 RTL 镜像；新增 `Up`/`Down` 历史命令回溯（保存未提交草稿并去重持久化至 `runCommandHistory`）、`Cancel` 按钮（`wmRunCancelButton`）与关闭后 `restoreShellPopupFocus()` 焦点归还，无托盘或卸载托盘时由 `ShellShortcutRouter` / `run-release` 平滑回退原生 KRunner | Wayland 多显示器定位、权限拦截提示与实际应用启动待维护者实机验收 |

<a name="block-09"></a>

## 09 锁屏、登录及启动外观

优先级：P1。依赖：A01–A04/A05–A12、M01；不改变认证或电源后端。规范源码归属：`modules/lockscreen/`、`modules/login/`、`modules/boot/`、`core/animations/`、`core/logic/`。

依据与实现记录：[样式规范](STYLE.md)、[登录原版参数与部署](NATIVE_COVERAGE.md#shared-control-evidence-and-credential-hosts)、[项目安装说明](../README.md#optional-boot-and-login-appearance)。

| ID | 状态 | 任务范围 | 现有实现 / 已知能力 | 剩余工作 / 验收边界 |
| --- | --- | --- | --- | --- |
| L01 | P | Win+L 锁屏及凭据页 | 保持 `kscreenlocker` 真实 PAM 认证、指纹/智能卡提示、`ScreenMonitor` 6.8 多屏指针跟随、`MediaControls`、`NoPasswordUnlock` 及 `296px` 凭据宽度；为锁屏电源菜单补齐条件休眠项（`Hibernate` / `suspendToDiskSupported`）与中文回退，补齐密码框 RTL 对称内边距、时钟 `PlainText` 渲染及唤醒态暂停后台 `1Hz` 时钟计时器 | 默认头像仍为 Fluent 兼容轮廓（见 A05），PAM 解锁、Fcitx5 输入法与多屏唤醒待维护者实机验收 |
| L02 | P | 系统登录管理器 | 独立可选 Plasma Login Manager greeter 具备受校验的 `greeter-native-assets.py` / `greeter-colors.py` 私有素材与深色方案同步、`SignInWelcome` 欢迎过渡及会话/键盘/网络/电池/电源底栏；为 `Login.qml` 新增按住显示密码按钮（同步 `GreeterState.showPassword`）与空密码框方向键切用户的 RTL 镜像，为 `WinUserSwitcher` 补齐 `Tab`/`Up`/`Down`/`Enter` 键盘切换与无障碍属性，并暂停隐藏态 `WinClock` `1Hz` 计时器 | NixOS 常规安装默认不替换系统登录管理器，可选构建部署与多用户/多会话切换待维护者单独确认并实机验收 |
| L03 | P | 启动、注销、休眠恢复和 Splash | KSplash（`Splash.qml`）与登录欢迎页共用 `SignInProgress.qml` 五点圆环（`1600ms` 周期，仅在可见时运行且不阻塞会话就绪），Plymouth 可选主题（`windows-modern.script` + `boot-frames.py`）共用相同角间距并在关机态隐藏启动徽标仅展示真实系统状态文本 | Plymouth 不通过 `GetMode` 区分独立重启标识，LUKS 解锁提示与真实冷启动/注销/休眠恢复帧过渡待维护者实机验收 |
| L04 | P | 壁纸、声音及其模式适配 | 完成本地 26H2 `Web/`（22 套壁纸包）与 `Media/`（70 个 WAV）逐项盘点并记录于 `WINDOWS11_FIDELITY.md`：`Windows-modern` 同时封装浅色 `img0.jpg` 与深色 `img19.jpg`（含校准强调色元数据），由 Plasma `org.kde.image` 随深浅色自动切换且桌面保持 `preserveAspectFit` 不裁切原图，锁屏独立配置 `img100.jpg`；18 个核心系统音效映射为 20 个 Freedesktop 事件并刻意排除 52 个闹钟/铃声/语音及默认静音窗口音效，保留用户静音偏好与第三方应用音效 | `Windows Background.wav`（滑块提示）与 `Windows Unlock.wav` 未纳入当前固定私有 `runtime` 清单，如需增补待维护者更新私有资源索引后实机验收 |

<a name="block-10"></a>

## 10 文件管理器与终端

优先级：P2。依赖：A03/A08/A10–A12、W01/W02/W05；保留原生应用后端。规范源码归属：`modules/explorer/`、`modules/terminal/`、`modules/browser/`、`platform/qt/konsole/`、`nix/`。

依据与实现记录：[应用布局实现及边界](APP_WINDOW_CHROME.md)、[样式规范](STYLE.md)、[Dolphin 补丁](../app-decorations/dolphin)、[Konsole 插件适配器](../platform/qt/konsole)。

| ID | 状态 | 任务范围 | 现有实现 / 已知能力 | 剩余工作 / 验收边界 |
| --- | --- | --- | --- | --- |
| E01 | P | Konsole 集成标题栏 | `platform/qt/konsole`（26.08.x 隔离可选插件）复用真实 `IKonsolePlugin` 与原生 `QTabWidget`，提供标签同行 `46×34` 窗口控制按钮（原版 `E921`/`E922`/`E923`/`E8BB`）、新建标签与配置文件下拉（`E710`/`E70D`）、8 向边缘缩放、`KWindowShadow` 阴影及最大化按钮悬停 `CaptionSnapPicker` 桥接，并在缺失素材或全屏/窄窗时安全回退原生布局 | 与 Windows Terminal 实机对比标题栏命中区、多标签溢出与分屏交互待维护者验收（无边框外角归 W02） |
| E02 | P | 终端内容、配色及交互外观 | `WindowsModern.profile`（Campbell 配色、`Cascadia Mono 12pt`、`8px` 内边距、竖线光标）、`konsoleui.rc`/`sessionui.rc`（默认收起双工具栏并保留完整菜单/右键/分屏动作）与 `WindowsModern-tabs.css`（对齐 `QMenu` `8px` 圆角）均由 `app-appearance.py` 可逆管理，不改动用户自定义 profile 或 shell 会话 | 中英等宽字体回退、深浅模式切换下非激活标签对比度与终端滚动待维护者实机验收 |
| E03 | P | Dolphin 基础外观和局部布局 | `dolphinui.rc`（`Navigation` + `Commands` 双工具栏、`20px` 图标）与 `app-appearance.py`（常显标签栏、面包屑地址栏、全宽状态栏、备份回滚）已就绪；`nix/dolphin-chrome.nix` 隔离包含 `statusbar-margins.patch`（修复非 Breeze 样式下状态栏容量条挤压）与 `tab-controls.patch`（`wmNewTabButton` 新标签角按钮及汉堡菜单防重复） | 真实 KIO 导航、标签拖拽分离、容量菜单与列表/图标视图在 150% 缩放下的表现待维护者实机验收 |
| E04 | P | Dolphin Explorer 结构和菜单缺口 | 在 `modules/explorer/patches/` 新增并通过 `nix/dolphin-chrome.nix`（`dolphin-26.08.3`）编译验证 `explorer-chrome.patch` 与 `compact-contextmenu.patch`：当 `wmCommandToolBar` 激活时，在双工具栏上方置顶非浮动 `wmTabStripToolBar`（双向绑定真实 `DolphinTabBar` 与紧随末标签的 `+` 新建标签按钮，保留拖拽排序/分离/中键关闭/文件拖放自动激活，无该工具栏或手机模式下自动回退原生标签栏），对齐全宽面包屑地址栏并在导航栏右侧常驻驱动原生 `Search::DolphinQuery` 的动态占位符搜索框（保留 `Ctrl+F` 高级筛选栏），保留 `PlacesPanel` 原生分组与书签/可移动卷，并将 `DolphinContextMenu` 精简为 Windows 11 主菜单加尾部 `wm-show-more-options-symbolic`（`Show more options` / `显示更多选项`）扩展子菜单（支持 `Shift+右键` 直出完整经典菜单）；同步接入 `--with-dolphin` / `--full` 隔离启动器 `Windows Modern Explorer` | 多标签溢出滚动、分屏双地址栏、KIO 第三方插件菜单、搜索防抖及 150% 缩放下的实机交互待维护者验收（保留系统原版 `dolphin` 不覆盖） |
| E05 | P | 其他 KDE/Qt 应用窗口的一致性 | 完成全仓通用 Qt/KIO 控件与日常应用消费者清单盘点并记录于 `APP_WINDOW_CHROME.md`：覆盖 Kvantum + `WindowsModern{Light,Dark}.colors` + `windows-modern` 图标下的通用对话框（`KFileWidget`/`KIO::RenameDialog`/`KPropertiesDialog`/`QMenu`）、`Dolphin`、`Konsole`、`KWrite`/`Kate`、`Haruna`、`Spectacle`；同步将可选 `Firefox` `userChrome.css` 最大化/还原图标升级为 Windows 11 `rx=1.5` 圆角几何并补齐按压态；明确列出 `System Settings`/`System Monitor`/`Discover`（仅覆盖图标与配色，不重建内部 Kirigami 页面）及 GTK4 应用边界 | 各日常 Qt 应用在深浅色切换、手动/自动强调色刷新及 150% 分数缩放下的实机表现待维护者验收 |

<a name="block-11"></a>

## 11 安装、兼容性与性能

优先级：P2（稳定性问题即时处理）。依赖：贯穿所有工作块，不等待视觉完成才处理回归。规范源码归属：`packaging/`、`platform/nixos/`、`nix/`、`scripts/materialize-modules.py` 及顶层安装/恢复入口。

依据与实现记录：[安装说明](../README.md#nixos)、[开发流程](CONTRIBUTING.md)、[发布和打包](RELEASE.md)、[NixOS 入口](../install-nixos.sh)。

| ID | 状态 | 任务范围 | 现有实现 / 已知能力 | 剩余工作 / 验收边界 |
| --- | --- | --- | --- | --- |
| V01 | I | NixOS 安装、增量更新及回滚源码路径 | 可逆安装器、ABI 匹配、身份核对与备份流程已有 | 仅指已实现路径；真实构建、升级失败及卸载恢复由维护者验收 |
| V02 | P | 其他 Plasma 6 环境及 ABI 兼容 | `install.sh` / `uninstall.sh` 分阶段批处理（失败组件拒绝重置面板布局并提示 `--restore`）、`qt-plugin-dir.sh` 插件目录探测、Fedora `fix-dolphin-statusbar.sh` 补丁预检及 Konsole/Dolphin/Kvantum 显式上游版本门控均已核查 | 不同发行版 Qt/Plasma 次版本升级、X11 会话与缺省可选依赖的真实安装恢复待维护者验收 |
| V03 | I | 完整私有包与公开包边界 | 已有资源 pin、成员/哈希检查、私有包与公开包区分、失败不发布的源码路径 | 维护者实际打包及安装验收另记；体积不是完整性依据 |
| V04 | P | 全局源码与静态检查覆盖 | 独立静态审查已完成全仓 `source_plan`（653 项输出无漂移）、`verify-svg-aliases.py --check`（5,172 个 SVG 零未登记重复）、`popup-frames.py --check`、`window-frames.py --check`、全部跟踪 Shell 脚本 `bash -n`/`shellcheck`、全部 JSON/XML/SVG/KCFG/RC 解析、全部 `.nix` 语法解析及全部 QML `qmlformat` AST 解析；经维护者批准完成 `nix/test-runtime.nix` 全量隔离编译验证（`systemtray`、`icontasks`、`contextmenu`、`konsole-26.08.3`、`dolphin-26.08.3`、`kvantum-1.1.9` 全部通过 Qt 6.12 / Plasma 6.8.3 编译并修复 `shellshortcutrouter.cpp` `<QDBusPendingCall>` 与 `nativecontextmenu.cpp` `containment()` `const` 限定） | CI 执行与实机集成测试留待维护者批准后运行（未修改或触发任何工作流） |
| V05 | P | 无障碍、语言与输入兼容 | 全仓主要组件已补齐 `Accessible.role`/`name`/`onPressAction`、键盘方向键/菜单键/`Alt+Left` 导航、`Text.PlainText` 防注入、IME `inputMethodComposing` 提交/取消保护、RTL `LayoutMirroring` 镜像，以及 `translations/zh_CN.json`（688 项唯一键）与 `lockText.js` 中文回退 | 屏幕阅读器（Orca）、Fcitx5 候选窗跟随、阿拉伯/希伯来 RTL 会话及触控板/触摸屏手势待维护者实机验收 |
| V06 | P | 运行性能、资源开销与长时稳定性 | 完成全仓静态性能、解码尺寸、缓存上限、计时器与离屏纹理审计并记录于 `WINDOWS11_FIDELITY.md`：补齐 `DefaultAccountPortrait` 导入/回退头像的非零整数 DPR `sourceSize`（全仓 `10/10` 个 `Image` 均受 DPR `sourceSize` 约束）；为 `ToolTipInstance`、`SwitcherView` 与 `SnapAssistPicker` 遮罩补齐软件渲染 `layer.enabled` 门控；确认 C++ `QIcon` 缓存具 `128` 项上限、Corona 外观同步采用 `350ms` 单次防抖，且全仓 `10` 个重复 `Timer` 100% 受可见/激活态门控（零后台常驻轮询） | 目标机器（NixOS `2560×1600@150%`）冷启动耗时、内存/CPU/GPU 占用与长时睡眠唤醒稳定性由维护者实机记录验收 |
| V07 | P | 模块间显式数据和动作接口 | 原生模型、路由及信号已有；PinnedPage/AllAppsPage/AlphabeticalAppsView/RecommendedPage/SearchPage 与 ListItemDelegate 全部通过显式属性、回调与激活/右键信号与宿主通信，CompactRepresentation/MenuRepresentation 显式传递按钮锚点与 Kicker 模型，SearchPage 显式接收 searching、appLookup、favoritesModel 与 appsModel；SystemTrayState 通过 reconcileHostExpansion 输入及 hostExpansionRequested 信号同步宿主，ExpandedRepresentation、HiddenItemsView、PlasmoidPopupsContainer、ExpanderArrow、CurrentItemHighLight、ItemLoader、AbstractItem、PlasmoidItem、BackgroundAppItem 均显式接收 trayRoot/trayState/popupDialog/preloadHost；Icon Tasks 的 LayoutMetrics.js、TaskList、Task、GroupDialog、ContextMenu、ToolTipDelegate、ToolTipInstance、ToolTipWindowMouseArea、MouseHandler、AudioStream、PulseAudio、PlayerController 及懒加载角标/进度/缩略图覆盖层全部使用显式宿主输入；LockScreen/MainBlock/MediaControls 与 Login 移除跨文件隐式外层 ID 访问 | 冻结架构清单第 6 项已完成；Start/clock 同面板可选能力宿主生命周期归 V08，跨模块完整交互链路与编译期 QML 绑定行为待维护者实机验收 |
| V08 | P | 全局能力与可选组件生命周期 | Corona 所有的 ShellAppearanceMonitor 与 ShellShortcutRouter 由任一已加载原生壳插件（System Tray、Icon Tasks、Desktop Context Menu）通过跨插件安全的 QObject/QMetaObject 接口初始化，无托盘冷启动仍可启动壁纸/配色监听并接管已迁移的 Win+R/V 原生回退，独立卸载托盘同步释放 Win+R/V；每个面板 Containment 通过 PanelPopupHost（`windowsModernPanelPopups`）独立持有 PanelPopupController 与 PopupEffects，Start/clock/tray 共用同面板焦点组与 split blur 且不依赖托盘存活；Start/clock/tray/taskbar 在移除（含 undo 期）或跨面板迁移时自动收起弹窗并跳过已标记销毁的实例 | 冻结架构清单第 7 项已完成；多屏、动态重建、会话退出、混合包与 ABI 实机生命周期待维护者验收，不增加常驻服务 |


## 架构与耦合复核（2026-11-27）

审查基线 f54fb1f2f7ab。通过 Git tree 递归取得选定目录的完整文件清单（响应均未截断），对关键入口、路由、模型、状态、资源生成、安装、应用桥接和静态检查进行源码审查。本节只记录直接确认的关系与待处理问题，不推断已经发生的运行故障。

| 目录 | Git blob 条目 | 范围 |
| --- | ---: | --- |
| plasma/ | 509 | 其中 QML/JS/C++/头文件 283 个 |
| scripts/ | 109 | 生成、资源、配色、安装及开发工具 |
| app-decorations/ | 12 | 应用与渲染器适配 |
| nix/ | 4 | 版本匹配的构建定义 |
| tests/ | 109 | 现有验证场景；本次未执行 |
| docs/ | 31 | 技术文档与参考数据 |

上述条目数不含其他顶层目录、第三方子模块内部文件及私有原版资源。目录和哈希核对不等于逐文件语义审查。结论：项目已有组件分离、部分公共资源与接口；尚未彻底解耦。

### 功能模块归类复核（2026-11-27）

基于 testing 提交 `01ad5c1f`，递归检查完整 Git tree 与
`core/source-map.json`。确认 19 个功能模块目录、233 个模块源码、配置及资源文件。
其中 230 个由 source-map 的 tree/file 映射直接收录，另外 3 个任务栏布局
模板/正文由两条 rendered 规则消费。没有未归属的模块源码、配置或资源，也没有重复
的生成输出目标。

原生宿主与功能源码所有权已明确：System Tray 组合 systemtray、
quicksettings、clipboard、run；Digital Clock 组合 calendar、notifications；
Start 组合 startmenu 与 search/startmenu 页面，Search 另有独立任务栏 applet。
Search 使用 Start 所有的模型辅助函数和原生动作。Calendar 使用
notifications 所有的提示图标策略。NotificationHistory 当前复用
Calendar 目录中的 Win11Palette/FlyoutButton，这两项已识别为公共控件归属，
留待既有的「公共控件归类」处理。详细边界记录在
[功能模块目录说明](../modules/README.md)。

结论：八项冻结清单中的「功能模块归类」完成。此结论只表示源码所有者、
宿主组合和已知跨模块依赖已经归类，不代表 V07 模块接口、V08 生命周期、
A14 公共源码或第二项公共控件归类完成。未修改运行时代码，未运行构建、
自动化测试、CI、打包或实机验收。

### 公共控件归类首轮复核（2026-11-27）

基于 testing 提交 `ac25c680`，确认 `Win11Palette.qml` 与
`FlyoutButton.qml` 同时服务 Calendar 和 Notifications。此前两者
位于 `modules/calendar/ui`，造成 Notifications 依赖 Calendar 功能目录。
现将两份源码原样迁入 `core/controls`，Git blob SHA 保持不变；
`core/source-map.json` 继续将它们生成到 Digital Clock 原有的
`contents/ui` 路径，因此 QML 类型名称、相对导入和运行时包布局不变。
Calendar 与 Notifications 仍共享同一原生通知模型和弹窗宿主。

模块源码由 233 降为 231，公共控件源码增加 2；模块目录的 228 个
直接映射源与 3 个布局渲染输入均保持唯一输出。此轮只处理已确认的
跨功能共享控件，不代表公共控件全量归类或 A10–A12 视觉验收完成。
未修改控件属性、尺寸、颜色、状态或交互；未运行构建、测试、CI、
打包或实机验收。

### 公共控件归类后续复核（2026-11-27）

继续复核 Login 与 LockScreen 两个独立宿主。确认 `WinAvatar.qml` 与
`AccountAvatar.qml` 的图片裁切、圆形遮罩和默认头像回退实现一致，差异仅为
默认尺寸；当前所有调用方均显式传入尺寸，两个宿主的默认值也均为 160。
现由 `core/controls/AccountAvatar.qml` 作为唯一编辑源，source-map 将它分别
生成到原有 `WinAvatar.qml` 与 `AccountAvatar.qml` 路径，保留原 QML 类型名、
包路径、布局输入和资源解析位置。

Login 与 LockScreen 的 `VirtualKeyboardButton.qml` 使用同一
`KWinVirtualKeyboard` 状态和切换动作，差异在不可用时的呈现及标签。
现统一到 `core/controls/VirtualKeyboardButton.qml`，通过
`lockScreenPresentation` 保留 Login 隐藏不可用入口、LockScreen 保留禁用的
Accessibility 入口；继续使用原 `Loader` 隔离可选键盘模块，并保留
`LockText.tr` 中文回退。没有增加服务或后端。

本轮删除 4 份模块内重复实现，新增 2 个 core 唯一编辑源。当前 19 个功能模块
含 227 个源码、配置和资源文件，224 个直接 tree/file 映射，另有 3 个布局
渲染输入。source-map 输出目标唯一。结合既有共享控件映射和模块宿主关系复核，
未发现其他已确认的跨模块控件遗漏。冻结架构清单第 2 项「公共控件归类」完成。
A14 仍为 P，其余公共视觉参数和语义角色统一属于既有独立工作，不在本项结项范围内。

仅做源码和映射静态审查，未运行构建、自动化测试、CI、打包或实机验收。

### 部署副本清理复核（2026-11-27）

基于 testing 提交 `6d7eb215`，重新核对完整 Git tree、`core/source-map.json`、
所有源映射目标、安装入口和归档验证路径。当前映射包含 37 个目录映射、
185 个文件映射和 2 个布局渲染规则，共 613 个部署输出：569 个生成文件、
44 个受校验的相对源码入口。所有输出目标唯一；583 个 core/modules/platform/
packaging 文件均已映射或属于明确的文档元数据豁免，没有未归属源码。

原生输出目录中仍由 Git 跟踪的 105 个文件，分为 44 个映射源码链接和
61 个独立文件。44 个链接均为 Git symlink 条目，逐一核对其 Blob 内容与
source-map 计算出的相对目标一致。569 个生成输出没有被 Git 跟踪的实体副本。
剩余 61 个文件由 4 个保持原生路径的 Nix 表达式、12 个 applet 构建说明/
开发脚本/测试/预览文件，以及 45 个资源采集、研究、Store 发布和开发辅助文件
组成；均不属于重复部署实现。4 个 Nix 表达式保留原路径，以维持相对路径、
构建身份和调用方式。未发现重复的源码代码文件或重复输出目标。

安装链路复核：常规 `install.sh` 在调用组件脚本前执行 `--prepare`；
NixOS 安装入口先准备并在构建后复核；完整包从同一 Git commit 归档，
再将生成输出写为真实文件；owner 包验证拒绝源码软链接。卸载入口使用
稳定源码链接和原生路径，不依赖重新生成文件。

另补齐 materializer 的文件级输出检查：目录映射继续递归拒绝未映射文件；
对独立文件映射的父目录，使用 Git 跟踪清单保留已跟踪的开发文件，并拒绝
未跟踪的多余文件或未声明软链接。检查只报告，不自动删除；归档临时目录
不受此工作区检查影响。这样旧分支留下的 ignored 文件副本不会静默混入
下一次安装或打包。

冻结架构清单第 3 项「部署副本清理」完成。图标主题中同内容的 SVG 命名别名
留在既有第 4 项「SVG 资源统一管理」处理，本项不擅自改动资源语义。
仅进行源码、映射、Git 文件身份和调用链静态审查，未运行构建、测试、CI、
打包或实机验收。

### SVG 资源统一管理复核（2026-11-27）

基于 testing 提交 `50c80309`，逐项盘点完整 Git tree 中的 5,172 个 SVG。
其中 `icons/windows-modern` 有 4,991 个 SVG，识别出 740 组完全相同的
Git blob 内容，涉及 3,524 个文件路径；为每组指定一个 canonical SVG，
其余 2,784 个路径登记为语义别名。1,020 个 Windows 原始资源映射目标中，
存在对应路径的组优先使用原始资源映射目标；其他组使用稳定的通用名称。
保留全部原有 KDE 图标名称和文件路径，不删除图标、不改变 `index.theme`
目录声明，也不改变图标主题 ID。

新增 `icons/windows-modern-aliases.json`，记录 canonical、别名路径和
Git blob SHA-1；新增 `scripts/verify-svg-aliases.py`。`--check` 检查
所有 canonical/alias 文件字节、映射哈希和未登记的重复组；`--sync`
仅从 canonical 同步别名文件并更新哈希，发现新增重复组或组关系变化时停止，
不自动重命名或删除资源。常规图标安装、NixOS 源码安装和完整包制作均执行
只读检查。完整 owner 包保留别名清单与只读检查器；独立图标组件包只包含实际主题资源，全部原有 SVG 文件与名称均保留。

资源所有权明确为：`icons/windows-modern` 管理可安装图标主题；
`platform/plasma/appearance/atlas` 管理 Plasma 桌面主题 atlas，165 个 SVG
由现有源映射与帧生成器维护；Windows 原始素材由 `core/resources/import`
管理，293 个资源映射覆盖 1,020 个语义输出目标，导入器使用内容哈希与硬链接
复用相同输出；`core/resources` 和 `modules/*` 保留各自唯一的共享/功能资源。
其余 16 个 SVG 没有发现跨目录的完全重复内容。

atlas 中 2 组重复文件属于既有 `core/materials/popup-frame.svg.in` 与
`core/materials/popup-frames.py` 的弹窗帧生成结果；另 1 组属于
`modules/taskbar/design/panel-frames.py` 的面板帧生成结果。它们不是独立编辑源。全仓库没有发现需要再迁移的
跨模块重复 SVG 实现。冻结架构清单第 4 项「SVG 资源统一管理」完成。

仅进行 Git 文件身份、源映射、资源生成器和安装/打包消费者静态审查；
未运行构建、自动化测试、CI、打包或实机验收。

### 公共视觉参数统一进展（2026-11-28）

基于 testing 提交 `bc7a7725`，复核快捷中心普通与分体磁贴的等价尺寸公式，
将按钮高度基值、UI 缩放、标题行数及高度、间距、圆角、主图标及标题字号归入
现有 `core/design/panel/trayMetrics.js`。面板、底栏与独立媒体卡片共用水平内容
边距基值；主面板滑块与公共 Slider 共用行高和图标基值。保留各消费者的
取整、最小值、原生 frameInset 扣除、字体度量和窄屏约束。磁贴实际高度
继续在未指定高度时才读取宽度，避免增加布局绑定依赖。

登录与锁屏共用 `core/design/lockMetrics.js` 的头像上限、时钟字号、
时钟垂直位置及凭据遮罩透明度；保留两个宿主的不同头像比例约束、
文本框高度、字体来源、账户切换布局及各自的原生认证流程。

Digital Clock 的日历/通知卡片共用圆角和边框宽度，日历导航按钮与公共 FlyoutButton 共用按钮尺寸和圆角，统一来源为 `core/design/clockMetrics.js`。颜色仍由 `Win11Palette.qml` 管理，几何参数不并入配色层。

开始菜单原 `theme.js` 同时保存颜色/透明度 token 与菜单几何。现将菜单行高及字体扩展、图标尺寸、行圆角、背景圆角/边框、内边距、文本/图标间距、弹出边界与锚点距离、右键菜单宽度/分隔线约束、视图菜单约束及电源菜单宽度约束集中到 `modules/startmenu/ui/code/startMenuMetrics.js`。ContextMenu、PowerOption、ShutdownMenu、StartMenuBackground 和 ViewModeMenu 使用该来源；`theme.js` 继续负责颜色和透明度。原数值、取整、字体度量、弹出定位和窗口约束保持不变。SearchBox 与 StartSearchField 语义不同，未强行合并。测试补充共享参数和边界断言，未运行。

Snap Layouts 的拖顶栏与标题栏预览共用布局表，但原先各自维护相同的 10px 图间距和 1px 描边。现将基础图间距、栏/标题栏尺寸基准、各自的单元格内间距与圆角、共同描边宽度及标题栏预览宽高比收敛到既有 `layouts.js`。保留两种预览不同的圆角和单元格间距、栏的自适应缩放、标题栏的固定间距与屏幕约束。测试补充参数基线断言，未运行。

Alt+Tab 卡片的关闭按钮和预览遮罩原先分别重复计算相同的 4×UI scale 圆角。现共用 `smallCornerRadius`，卡片大圆角保持独立。测试增加关闭按钮圆角与共享参数的一致性断言，未运行。

26H2 的 WinUI 通用资源确认 `ControlCornerRadius=4`、`OverlayCornerRadius=8` 和 `MenuFlyoutThemeMinHeight=32`。现由 `core/design/controlMetrics.js` 唯一维护，并通过 source-map 输出到 Start、Quick Settings、Login 和 LockScreen 包。开始菜单的行圆角/弹出面板圆角、锁屏电源菜单圆角、快捷设置的 ListRow、MoreSettingsLink、FooterButton、FluentSwitch，以及锁屏 StatusIconButton 均读取共享圆角来源；FluentPowerMenuItem 使用共享的 32px 最小行高。保持各控件的边距、尺寸、焦点边框和状态逻辑独立。测试补充跨包参数一致性断言，未运行。

Digital Clock 的通知/日历飞出卡片圆角与按钮圆角原先保存在 `clockMetrics.js`。现分别引用同一 OverlayCornerRadius 和 ControlCornerRadius，`controlMetrics.js` 同时映射到 Digital Clock 的 code 目录。卡片边框宽度与按钮尺寸仍由 clockMetrics 单独管理。 CalendarView 的月份标题按钮也读取 ControlCornerRadius，日历日期圆形标记与紧凑任务栏悬停面保持各自几何。

Clipboard 页签、Start 字母索引磁贴、系统位置快捷按钮和 SearchHome 应用磁贴也使用通用 4px 控件圆角，现改为读取同一参数。Clipboard 历史卡片 6px、SearchHome 非磁贴入口 5px 及圆形快捷搜索 chip 保留各自几何，不合并。AllAppsPage 分类标签、AlphabeticalAppsView 分组标题和 Start 视图切换按钮也接入 ControlCornerRadius；Kirigami 动态 smallSpacing 圆角保持独立。Quick Settings 的 NetworkPage/BluetoothPage 设备行和 MediaCard 传输按钮也使用该参数；DeviceRow 卡片及媒体封面保留独立圆角。Quick Settings 磁贴圆角的缩放基数也改为读取 ControlCornerRadius，拖放焦点框复用同一缩放函数；VolumeMixerSection 设备行接入共享圆角。

继续审查 Clipboard、Run、ShowDesktop 与其他渲染器：Clipboard 历史项圆角 6px、通知卡片圆角 8px 属于不同表面，不合并；RunDialog 保留独立窗口尺寸；ShowDesktop 的面板边距已由 `PanelMargins.qml` 单独维护。Aurorae 窗口装饰、Plasma 九宫格弹窗与 Kvantum 控件各有独立渲染坐标和资源生成器，数值相同不构成相同角色，本轮不跨渲染器强行合并。

所有修改
只收敛现有参数，不改变原值和缩放公式。`clockMetrics.js` 通过 source-map 生成一个包内 JS 资源，不增加第三方依赖，
不改变深浅色、尺寸、状态或动画算法。此轮未确认其他模块的全部视觉参数，
冻结清单第 5 项及 A14 仍为部分完成；原版数值证据归 A02/A08 等既有任务。
仅做完整变更差异及引用路径静态审查，未运行构建、测试、CI 或实机验收。

### 公共视觉参数统一完成复核（2026-11-28）

基于 testing 提交 `e113e4c5`，对 `core/` 与 19 个模块下的全部 QML/JS 视觉参数消费者进行全量复核，补齐剩余同语义参数的唯一维护来源：

1. **开始菜单与搜索**：`AllAppsPage` 分类标签、`AlphabeticalAppsView` 分组标题与 `LetterIndex` 字母磁贴的悬停/按压/选中颜色过渡统一接入 `ControlMetrics.microInteractionDuration`（90ms，保留 `Kirigami.Units.shortDuration > 0` 门控；弹层与分类展开容器动画仍保留 `shortDuration`）。`PinnedPage`、`AlphabeticalAppsView`、`AllAppsPage`、`SearchHome`、`SearchPage` 共用的 84px 网格单元高度（`PinnedListItemHeight`）、32/24px 网格与列表应用图标槽（`AllAppsIconSize_Large` / `AllAppsIconSize_Medium`）及 18px 内嵌滚动预留宽度收敛至 `modules/startmenu/ui/code/startMenuMetrics.js`；分类展开面板的 84px 顶部框体偏移、Recommended 的 28px 图标与 SearchHome 顶栏磁贴 100px 单元高度因语义角色不同保持独立。
2. **快捷中心、系统托盘与剪贴板**：`PageHeader` 详情动作按钮与 `ClipboardPage` 清空按钮接入 `TrayMetrics.detailActionButtonHeight`（30px），剪贴板列表卡片宽度直接读取共享 `FluentScrollBar` 轨道宽度；`Footer` 无原生边框内缩时的外层底角回退半径改为 `ControlMetrics.cardSurfaceRadius * uiScale`，与快捷设置主卡和媒体卡片保持同一表面语义；`ListRow` 默认外边距与 `VolumeMixerSection` 行外边距统一读取 `TrayMetrics.detailRowOuterInset`（8px），`ListRow`、`SectionHeader`、`VolumePage`、`VolumeMixerSection`、`BatteryPage` 的紧凑行内边距（10px）、间距（8px）与前导图标槽（20px），`InputDeviceSection`/`OutputDeviceSection` 的折叠箭头尺寸及旋转/展开时长，以及 `Slider` 的 WinUI 32px 槽高、18px 外手柄和 12/14/10px 内手柄状态尺寸统一归入 `core/design/panel/trayMetrics.js`。`MediaCard` 封面 4px 圆角保持独立。
3. **登录与锁屏**：`MainBlock` 错误提示、`NoPasswordUnlock` 登录按钮文字、`LockScreenUi` 账户切换名称与 `WinStyle.userSwitcherNamePixelSize` 统一读取 `LockMetrics.credentialFontSize`（14px）；两套宿主的无密码 Sign in 按钮宽度（144px）及默认/焦点描边宽度（1/2px）、文本框焦点底边指示条几何（2px 内缩/2px 高度/1px 圆角）、底栏 32px 状态按钮（16px 图标）及 16px 底栏外边距/8px 间距统一归入 `core/design/lockMetrics.js`。两宿主各自的视口缩放公式、输入框高度（30/42px）和电源菜单宿主宽度（150/160px）保持独立。
4. **数字时钟与通知中心**：`NotificationHistory` 勿扰按钮与 `CalendarView` 顶栏高度基线统一读取 `ClockMetrics.flyoutButtonExtent`（28px）；`ExpandedRepresentation` 日历折叠按钮与 `NotificationHistory` 分组展开/关闭按钮统一读取 `ClockMetrics.compactActionButtonExtent`（24px）。

所有改动均复用既有 `core/source-map.json` 生成路径，未新增跨包运行时依赖或额外生成副本，未跨 Aurorae、Plasma 九宫格 SVG、Kvantum 独立渲染器强行合并同数值参数；顺带修正 `scripts/materialize-modules.py` 父目录同级检查中 `relative` 字符串与 `expected`（`Path` 键）类型不一致导致的误判。结论：冻结架构清单第 5 项「公共视觉参数统一」完成。因新 clone/安装/打包及 26H2 原版参数真实性核验仍属既有实机验收与 A02/A08 范围，总账 A14 保持 `P`。仅执行源码、映射与完整差异静态审查，未运行构建、自动化测试、CI、打包或实机验收。

### 模块接口解耦完成复核（2026-11-28）

基于 testing 提交 `56fd0d8b`，对 `core/` 与 19 个功能模块的全部 182 个规范 QML 源码进行跨文件隐式 ID、父链假设与状态所有权静态排查，收敛剩余隐式接口：

1. **开始菜单与搜索**：`SearchPage` 新增显式 `appLookup`、`favoritesModel`、`appsModel` 输入，移除对 `rootItem`、`kicker`、`sortedAppsModel` 的跨文件访问；`PinnedPage` 新增 `applicationActivated` 与 `appContextMenuRequested` 信号并补齐 `favoritesList.activateRow`（仅在 `trigger` 返回成功时通知宿主关闭）；`AlphabeticalAppsView`、`AllAppsPage` 分类网格与 `MenuRepresentation` 首页最近项网格统一接入显式 `contextHandler`；`ListItemDelegate` 移除对 `root`、`kicker`、`sharedContextMenu` 的回退查找并改为发出 `activated` 信号；`main.qml` → `CompactRepresentation` → `MenuRepresentation` 显式传递 `anchorButton`、`launcherApplet`、`launcherRootModel` 与 `launcherFavorites`。
2. **任务栏（Icon Tasks）**：`main.qml` 显式暴露 `windowViewAvailable`、`mpris2Source`、`virtualDesktopInfo`、`activityInfo`、`busyIndicatorComponent`、两套 `ToolTipDelegate`、`scheduleGeometryPublish` 及 `startTaskDrag`/`stopTaskDrag`；`Task` 接收显式 `hostTaskList` 并通过 `tasksRoot` 访问宿主能力，不再直接解析 `effectWatcher`、`taskInitComponent`、`dragHelper`、`busyIndicator` 或假设 `parent.animationsRunning`；`ContextMenu`、`ToolTipDelegate`、`ToolTipInstance`、`ToolTipWindowMouseArea`、`PulseAudio`、`PlayerController`、`MouseHandler` 改为显式输入并消除 `pragma ComponentBehavior: Bound` 下的外层自由 ID 引用；`TaskProgressOverlay`、`TaskBadgeOverlay`、`GroupExpanderOverlay`、`PipeWireThumbnail` 补齐 `Bound` 与 `required` 属性，并通过 `Loader.setSource` 保留按需懒加载与可选模块隔离。
3. **系统托盘与快捷中心宿主**：`ExpandedRepresentation`、`HiddenItemsView`、`PlasmoidPopupsContainer`、`ExpanderArrow`、`CurrentItemHighLight`、`ItemLoader`、`AbstractItem`、`PlasmoidItem`、`BackgroundAppItem` 统一补齐 `pragma ComponentBehavior: Bound` 及显式 `trayRoot`、`trayState`、`popupDialog`、`preloadHost`、`popupContentItem`、`overflowGridView` 与系统组边距输入，消除对 `root`、`systemTrayState`、`dialog`、`expandedRepresentation`、`preloadedStorage` 及 `parent.GridView.view` 的隐式外层依赖。
4. **锁屏与登录**：`LockScreen` 向 `LockScreenUi` 显式传入 `lockScreenHost`，`MainBlock` 暴露 `clearPassword`/`pulseError` 方法取代跨两层连接外层 `root`，`MediaControls` 通过 `interactionStarted` 信号通知宿主停止淡出计时器；`Login` 密码框 Esc 直接恢复自身焦点，不再跨文件引用 `mainStack`。

所有真实 KDE 模型、服务后端与包边界保持唯一，未新增后台进程或兼容包装层，`core/source-map.json` 生成目标数量不变。结论：冻结架构清单第 6 项「模块接口解耦」完成；总账 V07 保持 `P`，待维护者完成构建与实机交互验收。仅执行源码、作用域引用与完整差异静态审查，未运行构建、自动化测试、CI、打包或实机验收。

### 全局功能生命周期分离完成复核（2026-11-28）

基于 testing 提交 `eefee7ac`，对 Corona 全局能力、面板级弹窗协调/模糊宿主及可选组件移除/重建/卸载回退路径完成解耦与收口：

1. **无系统托盘冷启动与跨插件安全单例**：`ShellAppearanceMonitor` 与 `ShellShortcutRouter` 标记为 `Q_DECL_HIDDEN`，完全移除 `shellshortcutrouter` 对 `systemtray.h` 的头文件依赖，改由 `Corona` 直接子对象名称查找（`findChild<QObject *>`）配合 `QMetaObject::invokeMethod` 槽调用跨独立 `.so` 插件共享同一会话实例，消除 `RTLD_LOCAL` 下 `staticMetaObject` 地址不等导致的重复注册风险。`System Tray`、`Icon Tasks`（`Backend`）与 `Desktop Context Menu`（`NativeDesktopMenu`）任一原生插件加载即可幂等启动 `ShellAppearanceMonitor` 与 `ShellShortcutRouter`；`Icon Tasks` 同步转发 `Kirigami.Theme` 调色板变化至同一 350ms 防抖同步器。冷启动无就绪托盘时，`ShellShortcutRouter` 通过 `KGlobalAccel::globalShortcut` 仅认领已存在的 `Win+R`/`Win+V` 迁移绑定并走原生 KRunner/Klipper 回退，不抢占新装无托盘环境的原生绑定，也不会重复注册全局动作。
2. **面板级稳定弹窗协调与 Split Blur 宿主**：新增 `platform/plasma/popup/panelpopuphost.{h,cpp}`（`PanelPopupHost`），由 `Corona` 级管理器自动为所有现有及新增 `Panel`/`CustomPanel` Containment 挂载隐藏内部动作 `windowsModernPanelPopups`，将 `PanelPopupController` 与 `PopupEffects` 的所有权从托盘实例上移至面板 Containment。`core/logic/panelCapabilities.js` 新增 `findPanelCapability` 优先解析同面板 `windowsModernPanelPopups`（保留旧 applet 列表回退），`Start` 与 `Digital Clock` 监听 `Plasmoid.containment` 的 `internalActionsChanged`/`appletsChanged` 事件驱动刷新，无需轮询；`System Tray` 自身也将 `prepareShellPopup`、`restoreShellPopupFocus`、`setNotificationPopupSlide`、`setSplitPopupBlur` 与 `popupBlurPreferencesChanged` 委托至同一面板 `PanelPopupHost`（独立预览无面板时回退本地宿主），保证有无托盘或次屏纯 QML 面板均具备一致的焦点组与分体圆角模糊能力。
3. **组件移除、Undo 恢复、跨面板迁移与卸载回退**：针对 Plasma 6 移除组件时的延迟销毁（`Applet::destroyed()` undo 期），`ShellShortcutRouter::target()` 与 `Icon Tasks` `Backend` 快捷键分发跳过 `destroyed()` 实例，Undo 恢复后无需重建即可自动恢复路由；面板销毁时 `PanelPopupHost` 主动收起同面板弹窗；`Start`、`Digital Clock`、`System Tray` 与 `Icon Tasks` 在 `destroyedChanged`/`containmentChanged` 时立即关闭已打开弹窗或分组浮层，且 `Start` 在 `destroyed` 期间禁用 `windowsModernSearch` 动作使同面板 `Search` 立即清空镜像状态。同时为 `windows-shortcuts.py` 补齐与 `run-release` 对称的 `clipboard-release` 并接入 `uninstall.sh systray`，避免单独卸载托盘组件时遗留空的 `Win+V` 绑定；顺带补齐 `systemtray` 与 `icontasks` `CMakeLists.txt` 中 `controlMetrics.js` 的 QRC 资源登记。

未新增任何常驻进程、后台服务或轮询定时器，`nix/test-runtime.nix` 构建配方保持原样，`core/source-map.json` 增加 22 个原生编译目录生成目标（共 645 个输出）。结论：冻结架构清单第 7 项「全局功能生命周期分离」完成；总账 V08 保持 `P`，待维护者完成编译与多屏/重建/会话实机验收。仅执行源码、映射、CMake QRC 清单与完整差异静态审查，未运行构建、自动化测试、CI、打包或实机验收。

### 配色与材质内部解耦完成复核（2026-11-28）

基于 testing 提交 `9d33a9b3`，完成配色算法、渲染绑定、桌面宿主发现与文件事务的职责分离，并明确非 Kvantum 场景的支持边界：

1. **算法、渲染与刷新回执职责拆分**：新增 `core/palette/accent-algorithms.py` 独立承载 48 组预设色阶、饱和自定义 CIELAB / 近灰精确有理数 HSL 分支、对比前景色、手动捕获报告比对，以及受界静态壁纸解码、`wallpaper-icc.py` 采样前固定点预变换、WIC 候选双线性重采样、加权 RGB 种子提取与自动色阶归一化（无 KDE、Kvantum 或事务依赖）；新增 `core/palette/accent-renderers.py` 独立承载 KDE `.colors` 角色渲染、Kvantum `.kvconfig`/`.svg` 行级强调色绑定生成与校验，以及内容寻址 `live-reload.json` 刷新回执发布；`core/palette/sync-accent.py` 收敛为轻量 CLI 协调器与兼容导出门面，完整保留原有函数名、内部测试符号及命令行参数。
2. **桌面宿主控制接口解耦（消除跨入口 `runpy` 字典调用）**：新增 `platform/plasma/appearance/appearance-host.py` 统一持有 KDE 配置读取、当前主题模式/渲染器判别、实时壁纸 D-Bus 桥接快照（含符号链接 `source_path` 与文件指纹校验）及调色板通知；`accent-control.py`、`window-frames.py`、`appearance-packages.py`、`sync-accent.py` 与 `accent-algorithms.py` 全部通过 `importlib` 显式加载相邻模块，彻底移除外观管线内部相互执行脚本的 `runpy.run_path` 调用，`window-frames.py` 不再加载 `accent-control.py` 或 `sync-accent.py`。
3. **非 Kvantum 场景支持边界规定与落实**：在共享全局主题（`org.kde.windowsmodern.dark`）及 `WindowsModernDark`/`WindowsModernLight` 配色下，若 Qt `widgetStyle` 非 Kvantum（如 Breeze/Fusion）或系统未安装用户级 `~/.config/Kvantum/Windows-modern` 目录，`accent-control.py` 与 `switch-mode.sh` 正常完成 KDE `.colors` 方案写入、`plasma-apply-colorscheme` 应用、在位角色核验与 `[WindowsModernAccent]` 状态持久化，不发送多余 Kvantum `StyleChanged` 广播；`window-frames.py` 与 `switch-mode.sh` 在 Aurorae `windows-modern-{dark,light}-aurorae` 激活时独立更新标题栏静态壁纸 tint 与 Plasma 弹窗/面板透明选择器；当用户实际启用 Kvantum 或存在本地 `~/.config/Kvantum/Windows-modern` 目录时，继续执行完整的模式/主题匹配检查、双模式 `.kvconfig`/`.svg` 原子写入、`live-reload.json` 回执发布，并在本地 Kvantum/Aurorae 目录不完整、被外部修改或含符号链接时严格拒绝写入并回滚。

Windows 取色/色阶算术、ICC 查表重放、`WALLPAPER_ANALYSIS_REVISION=11` 与 `MATERIAL_SAMPLE_REVISION=1` 缓存契约、`windows-modern-appearance.lock` 排他锁及 `core/transactions/theme-files.py` 原子替换/逆序回滚保持完全不变。`core/source-map.json` 新增 3 个源码相对链接映射（共 648 个输出：601 个生成文件、47 个源码链接），`appearance-packages.py`、`verify-owner-bundle.py`、`verify-integration-bundle.py` 与 `verify-all.sh` 同步纳入全部新增模块，并补充模块接口与非 Kvantum 边界单测断言。结论：冻结架构清单第 8 项「配色与材质内部解耦」完成，维护者确认的 **8/8 项架构改革任务全部完成**；总账 D20 保持 `P`，后续随 D17/M02 等功能还原推进并由维护者执行实机验收。仅执行源码、映射、模块导入图与完整差异静态审查，未运行构建、自动化测试、CI、打包或实机验收。

### 已具备的合理边界（保留）

| 层 | 源码依据与结论 |
| --- | --- |
| 组件与平台 | plasma/applets 下 7 个独立 applet，托盘/任务管理器/桌面菜单各有 CMake 目标；KWin scripts 与 switcher 独立。保持 Qt/KDE 的必要 ABI 依赖。分包不等于所有能力运行时独立 |
| 外观生成 | scripts/theme/appearance-packages.py 的 desktoptheme、aurorae、lookfeel、color_schemes、kvantum、materialize 与 palette.json/模板：已有单一深浅源码及输出边界，A13 保持 I |
| 真实后端 | FlyoutRouter.qml、components/、lib/、SystemTrayState.qml；NetworkPage/PlasmaNM、BluetoothPage/BluezQt、volume/VolumeModels.qml；Start/Kicker、Search/Milou、Icon Tasks/TasksModel、clock 原生通知模型。保留真实模型和动作，不重写后端 |
| 原版素材 | scripts/native_assets_input.py、native_assets_index.py、native_pe_resources.py、native_pri_resources.py、两个导入器与 native-assets-map.json：输入、解析、验证及角色映射已有分层，不复制导入器 |
| 窗口与应用 | Konsole captionsnapbridge.cpp、chromeshadow.cpp，KWin Snap Layouts 使用短时受校验请求；nix/konsole-chrome.nix、dolphin-chrome.nix 版本门控和隔离应用。保留原生窗口管理、会话与文件操作 |
| 安装与回滚 | install-nixos.sh、scripts/nixos-test-state.py、nix/test-runtime.nix；常规安装使用 install-lib.sh/config-backup.sh；两者共用 appearance-packages.py。保持独立 ABI、备份与安装边界 |

### 已确认的耦合与处理方案

| 任务 | 直接源码证据 | 影响与处理 |
| --- | --- | --- |
| A14 公共源 | Plasma 283 个代码文件按 Git blob SHA 分组，18 组共 45 份完全相同；verify-all.sh L271–313 有 29 对比较（含 2 对 SVG）。Start CompactRepresentation、Search/Task View TaskbarButton、Icon Tasks Task.qml 原先分别写入 30px 画布逻辑，第八批统一到 core/design/taskbarGeometry.js | 图标画布复用现有生成/安装路径，保持四个独立包完整；继续统一其他同语义参数，不能仅凭相同数值合并不同角色 |
| V07 隐式依赖 | 第七批消除 AllAppsPage/SearchPage 对外层 root 的直接访问，通过 applicationActivated 信号和 searching 输入连接 MenuRepresentation；SystemTrayState 通过明确的展开输入和信号连接 tray main.qml。第八批将 LayoutMetrics.js 的 tasks/taskFrame 依赖改为宿主提供的实时几何与配置属性；TaskList、Task、GroupDialog、MouseHandler、AudioStream 使用显式输入，动态创建者传递相应对象 | 保留原有应用激活条件、搜索筛选可见性、托盘展开同步及任务栏几何公式；继续核对其他隐式依赖，不以文件行数认定问题 |
| V08 弹窗 | Start MenuRepresentation.qml、clock main/CompactRepresentation.qml 共用 panelCapabilities.js 查找同面板协调器，协调与 split blur 独立选择；协调器更换时关闭已映射 popup | PanelPopupController 持有面板弹窗注册与焦点计时器，PopupEffects 持有模糊设置观察和 KWin 效果接口；托盘仍为面板能力入口。tray/clock 互斥、Start 独立及外部焦点关闭规则保持，关闭回调中替换注册项不再破坏遍历；仍需明确稳定宿主及验证重建/缺失回退 |
| V08 全局事件和快捷键 | platform/plasma/appearance/shellappearancemonitor.cpp 将既有 WallpaperAccentSource、配置/文件观察及防抖执行集中到 Corona；platform/plasma/shortcuts/shellshortcutrouter.cpp 持有 Win+R/V QAction 并通过 QPointer 跟踪就绪表示 | 已分离单个 tray 的对象生命周期与重复执行，保留原 D-Bus 路径、动作 ID、350ms 防抖及退出码 75 的三次重试。当前会话移除 tray 后仍有监听和原生回退路径，但未加载托盘二进制的冷启动未解决；多屏、注销、卸载及事务退出待验收 |
| V08 可选组件 | Start 根对象持有打开及状态动作，Search 监听同面板候选的 internalActionsChanged、destroyedChanged 及打开动作的 enabledChanged，点击时同步重查，状态与打开动作来自同一就绪提供者；clock 独立查找协调与模糊能力 | 保留共用 Start 真实模型、编辑器与原动作 ID，无就绪 Start 时清空镜像状态并警告返回；需实机验证任意启动顺序、重建/移除、跨面板及新旧包，clock 的独立宿主仍未解决 |
| D20 外观管线 | sync-accent.py 仍负责色阶/解码、scheme/SVG 绑定及刷新回执，通用文件事务已提取至 core/transactions/theme-files.py，原四个函数名继续由同步入口提供；accent-control.py/window-frames.py 仍经 runpy 访问同步入口；switch-mode.sh 要求对应 Kvantum/KDE scheme 并统一调度 | 复用现有算法，但逐步明确计算、宿主控制、渲染输出与事务接口；保持缓存、原子性、锁和回滚。非 Kvantum 边界需要规定；当前完整主题安装的明确限制不等同于已发生的 bug |
| V04 静态覆盖 | verify-all.sh 有副本比较但也运行测试；static-check.yml 含格式检查、QML parser、部分 qmllint、图标审查和 Konsole 语义检查，不覆盖全部 native applet 类型检查 | 按改动核查实际消费者、资源和包边界，复用已有静态机制。未经授权不改动 CI。未执行工具的检查不能标为通过 |

18 个相同代码组及份数：滚动条 3、colorType 3、dateformat 3、popupGeometry 3、Search/Task View Glyph 2、SearchGlyph 2、TaskbarButton 2、默认头像 3、NativeGlyph 4、BatteryGlyph 3、batteryState 3、BatteryStatusIcon 2、FluentPowerMenuItem 2、NetworkStatusIcon 2、SignInProgress 2、StatusIconButton 2、lockMetrics 2、lockText 2。共 27 个额外位置，不代表全部重复逻辑或无用文件。保留锁屏、登录前及独立 applet 必需的部署副本；不跨包创建不安全链接，不增加强制运行时依赖。

### 批次与架构验收

1. A14 与 A01–A12 同步推进。先确认原版参数和角色，再统一真正共用的逻辑；每处修改明确编辑源、消费者和所有安装路径。生成产物必须仍然自包含。
2. V07 随各页面实际修改处理，接口可读、状态所有权明确；不为了零依赖或拆短文件而重构。
3. V08 随 Q15、D13、W09、Q09 处理。先确认既有协调接口、生命周期与回退，再决定是否调整宿主；避免重复注册、额外进程和轮询。
4. D20 随 D17/M01/M02 等实际功能工作收敛。不可改变已经验证的原版算术、事务和版本缓存；同一 renderer 文件的必要同步不能硬拆。
5. V04 记录受影响文件和相关静态核验，缺工具/版本匹配时据实记录；所有实机行为由维护者验收。

架构完成要求是职责明确、单一所有权、必要依赖显式、可选模块边界可验证、修改不产生无关模块回归。并不要求完全零依赖。已有 KDE 后端、共享窗口协调、深浅生成和同一事务的同步均应保留。

## 实机验收登记

下列矩阵由维护者执行，属于独立验收门槛。记录版本/提交、原版参考和 KDE 版本、分辨率、逻辑缩放、深浅模式、语言、壁纸/强调色、透明度、输入方式、截图或观察结果。不使用不同放大倍数的截图直接比较物理像素。优先 150% 的目标设备，再覆盖 100/125/200%、窄屏和多显示器，保留其他实际受支持配置。

| 工作块 | 必须覆盖的场景 |
| --- | --- |
| 01–03 | 同一缩放下的坐标、文字、边距、可见图形、实际点击区域、控件各状态、滚动、RTL/IME、深浅切换 |
| 04 | 手动/自动强调色、已测 ICC/格式及未知输入、壁纸变更、模式切换、透明开关、已打开应用、窗口活动状态、事务竞争 |
| 05–07 | 任务/托盘状态、实际设备热插拔、Win+A/N/V/K、Start/Search、弹窗互斥和独立关系、通知与媒体、日历时区、键盘/鼠标/触控板 |
| 08 | Win+Tab、Alt+Tab、Snap、Win+R、OSD、各窗口生命周期、最大化/贴靠/多屏、动效及无障碍 |
| 09 | Win+L、凭据与错误、会话切换、可选系统登录/启动、恢复和安全解锁提示；使用现有安全测试流程 |
| 10 | Dolphin/终端真实导航和会话、标签、多窗口、各布局及最小窗口、撤销可选定制 |
| 11 | 安装、增量升级、备份回滚、卸载、ABI、不同版本、长期稳定性及性能；可选组件缺失/重建、主面板变化与全局事件/快捷键生命周期；记录实际测量 |

按任务编号追加真实结果：提交 / 环境 / 任务 ID / 状态 / 证据或缺口。当前没有本基线的 Pass 或 Fail 记录。失败时保留现象与复现条件，关联原编号，并重新打开对应源码任务。若实现更新影响已通过的场景，重置受影响的验收记录，不沿用旧通过结果。

## 文档职责与维护规则

- 本文件：唯一任务状态和进度总账；工作编号、统计、待解决差距与验收记录统一更新。每个开发批次关联任务 ID，记录修改、来源、静态审查结果及遗留项。只影响本账的整理工作不增加源码完成数量。
- [WINDOWS11_FIDELITY.md](WINDOWS11_FIDELITY.md)：视觉和功能目标、原版对比要求及历史研究。[PANEL_UI_CONTRACT.md](PANEL_UI_CONTRACT.md)：现有面板布局/交互合同；暂定参数不是原版确认值。[STYLE.md](STYLE.md)：组件实现与历史技术说明。旧研究步骤不代表当前任务状态。
- [NATIVE_COVERAGE.md](NATIVE_COVERAGE.md)、[NATIVE_ASSETS.md](NATIVE_ASSETS.md)、[原始布局/参数 JSON](windows11-26h2-ui-parameters.json)、[ICC 研究](windows11-26h2-icc-investigation.md)：原版证据、来源、适配差异和详细诊断；不得据旧章节推翻当前已记录的实现状态。
- [APP_WINDOW_CHROME.md](APP_WINDOW_CHROME.md)：应用窗口定制边界与运行方式。[CONTRIBUTING.md](CONTRIBUTING.md)、[AGENTS.md](../AGENTS.md)：开发、静态检查、分支及维护者验收规则。
- 发现文档冲突时核对当前源码及原版证据，在同一批修正总账与受影响的技术文档；不删除有价值的历史观测。任何拟增加或排除的目标功能都须明确记录并获维护者确认。

### 基线变更记录

- 2026-11-27：将原 12 项 Phase A、19 项动态配色记录纳入统一工作块，保留编号/状态（动态配色新增 D01–D19 编号）；其他工作块从已有技术和验收文档补充。未修改桌面运行时代码；总账加入现有开发文件打包排除清单，避免混入安装包。未将历史测试当作本基线实机通过结果。

- 2026-11-27 架构复核：检查重点源码、目录及同 SHA 文件，增加 A14/D20/V07/V08；根据 ActionPanel 与既有静态检查范围将 Q11/V04 调为 P，细化历史反馈的源码事实。仅改总账和开发指引；无运行时代码修改，未运行构建、自动化测试、CI 或实机检查。

- 2026-11-27 模块迁移首批：基于 745749c71a6d，建立 20 个公共编辑源、71 个模块专属源文件，对应 120 个原生镜像文件；原生文件 Git blob SHA 完全不变。覆盖五个纯 QML 包，拆出搜索及通知专属页面。新增源码物化入口，复用现有静态检查，打包排除仅开发使用的 core/modules 和生成器。所有功能完成度不变；未运行构建、测试、CI 或桌面验收。

- 2026-11-27 模块迁移第二批：基于 f0049a8b2c5b9，归类七个 applet、各功能模块、公共配色/材质、原始资源导入、平台适配和安装工具。公共头像及许可统一，两种任务栏入口共用一个布局正文；现有控件创建/配置、屏幕选择及原生 ID 保留。映射检查增加权限位、唯一输出及未映射源检查，写入使用单文件原子替换，NixOS 源码安装在桌面变更前执行一致性检查。源文件仍以原生镜像供旧工具消费；尚未实现源树无跟踪镜像、所有接口解耦、配色内部拆分或完整 SVG/资源所有权。功能完成度不变，未运行构建、自动化测试、CI 或实机验收。

- 2026-11-27 模块迁移第三批：基于 828baf15840f，删除 91 个受版本控制的原生部署副本，其唯一编辑源保留；其余 345 个映射输出暂保留跟踪。统一生成器增加 --prepare 与指定提交 ZIP 追加模式，现有 NixOS/常规安装、打包、QML 解析、图标覆盖、健康检查、原生编译入口、QML 测试入口接入生成流程。原生插件 ID、相对导入、真实功能保持不变；源码 checkout 直接调用底层工具前须先生成，旧输出有漂移时拒绝继续。未运行构建、测试、CI 或实机验收，安装包生成路径尚未实机验证。功能完成度不变。

- 2026-11-27 模块迁移第四批：基于 7ba4d6b0474b，取消 241 个额外部署文件的 Git 跟踪，累计 332/436 个生成输出（76.1%）；保留唯一编辑源。全部已映射 Plasma 原生源码均通过映射生成；补充独立 applet、锁屏、greeter 安装与开发入口的准备步骤，Store 元数据读写及 PLM 补丁更新指向规范源。保留 104 个其他原生镜像和现有静态工作流，未改动 UI/运行时功能。未执行构建、测试、CI 或实机验收；完整新 clone、安装包与独立底层工具调用仍需验证。

- 2026-11-27 模块迁移第五批：基于 a36ccf49a7d1，取消 50 个额外部署文件跟踪，累计 382/436（87.6%），保留 54 个镜像（7 个 Konsole 原生文件、4 个 Nix 表达式、43 个启动/恢复/配色/资源/打包工具与配置）。窗口装饰默认再生成写入规范源；应用配置、Plymouth 和 Dolphin 独立入口使用规范源，安装 ZIP 仍用原生布局；常规卸载使用明确的三个自有 KWin 脚本 ID，greeter 补丁恢复不要求生成整个工作树。主安装器先准备组件脚本，依赖安装与恢复入口保留；直接运行低层生成工具或组件脚本前须 --prepare。NixOS 主构建表达式保持原样，避免纯架构整理改变插件构建身份。未修改原版算法或 UI；未执行构建、测试、CI、打包或实机验收。待收敛启动、恢复和独立命令的兼容路径及模块间实际接口。

- 2026-11-27 模块迁移第六批：基于 51eceacce414，完成已盘点的 436 个部署位置的重复编辑源清理（382 个按需生成、43 个源码相对链接、11 个保留原生唯一源码），映射降为 425 个输出，未保留受 Git 跟踪的实体镜像实现。保留现有 Nix 构建身份与 Konsole 独立静态检查路径，删除相应 11 个重复模块/平台文件。源映射只允许明确声明的 scripts/ 相对链接，拒绝错误目标；完整 ZIP 排除源码链接并按归档提交恢复真实文件，现有归档验证拒绝脚本符号链接。该指标不等于项目架构或功能完成度。未运行构建、测试、CI、打包或实机验收；后续处理公共视觉规范、实际依赖接口及全局能力归属。

- 2026-11-27 模块迁移第七批：基于 7ed76dee5ab6，Plasma atlas 的 166 个原生文件整体迁入 platform/plasma/appearance/atlas，原路径只由源映射生成；更新默认再生成路径与健康检查提示，保留显式目录参数及旧部署布局。AllAppsPage/SearchPage 的宿主关闭动作改为信号，SearchPage 显式接收模式；托盘的展开状态改由宿主传值及接收信号，保留原有同步与激活条件。V07、A14 仍为 P；V08/D20 未改动。未运行构建、测试、CI、打包或实机验收；继续核对任务栏几何、全局能力归属和配色职责，未增加功能完成数。

- 2026-11-27 模块迁移第八批：基于 2809c1fcec2d，任务栏 LayoutMetrics.js 接收显式几何/配置输入，TaskList、Task、GroupDialog 共享宿主实时绑定，窗口组创建、拖放和音频状态不再依赖原有的隐式几何/宿主 ID；音频模型尚未加载时忽略音量滚轮操作。30 逻辑像素画布及 4 像素总内缩由 core/design/taskbarGeometry.js 统一供四个 applet 使用，保持各自资源独立，补充 Icon Tasks CMake 注册。未改动现有尺寸、任务模型、动画或已加载音频行为。A14/V07 保持 P，V08/D20 未改动，源码完成任务数不变。未运行构建、自动化测试、CI、打包或实机验收。

- 2026-11-27 模块迁移第九批：基于 d97590a192ad，新增 Corona 所有的外观监听器与快捷键路由器，将每个 tray 的配置/文件观察、350ms 防抖和同步执行收敛为单一会话控制器，保留原算法、事务锁、D-Bus 路径和退出码 75 重试上限；全局动作保留原组件名和 ID，路由到就绪主屏或次屏托盘，无就绪托盘时走原生 Klipper/KRunner 路径。用 QPointer 区分重建前后的 UI 表示。Start/clock 共享面板能力查询并在协调器替换时关闭旧弹窗；窗口组显式传递父模型索引，修正第八批创建期间依赖宿主尚未赋值的风险。映射增加 6 个输出。未解决不加载托盘二进制的冷启动、稳定弹窗/模糊宿主及 Search 生命周期，V08、V07、A14、D20 保持 P，功能完成任务数不变。未执行构建、自动化测试、CI、打包或实机验收；环境无 Qt/KF6 开发头文件和 QML 检查工具。

- 2026-11-27 模块迁移第十批：基于 f6b495b63de9，提取 platform/plasma/popup/panelpopupcontroller.{cpp,h} 和 platform/plasma/appearance/popupeffects.{cpp,h}，不依赖托盘模型。保留面板级焦点策略、180ms 外部失焦防抖、KWin 原生效果、模糊偏好通知和原 QML 接口。关闭时遍历 QPointer 快照并跳过已替换的注册项，避免同步 QML 回调使迭代器失效；不改变逻辑像素、圆角、模糊区域或动作身份。原生输出增加 4 个，仍由原 CMake 目标编译。V08/A14 保持 P，功能完成任务数不变；独立面板宿主、冷启动和多屏/重建验收尚未解决。仅做源码及映射静态审查，未执行构建、自动化测试、CI 或实机验收。

- 2026-11-27 模块迁移第十一批：基于 5838d900603f，Start 的两个原生 Search 动作迁至 PlasmoidItem 根对象，使用框架表示属性追踪实际弹窗；搜索入口监视候选的原生动作列表与就绪状态，不轮询，点击同步解析同一提供者的动作，保留原动作名称、真实搜索模型、锚点及交互。将 owned_file、atomic_write、restore_pending、write_pending 原样迁入 core/transactions/theme-files.py，经同步入口提供原命名接口；新增 1 个受源映射校验的相对链接，安装外观包复制实体文件，现有完整包校验和外观静态入口包含此依赖。保持既有锁、文件模式、竞争检查、回滚顺序、色阶、ICC 与材质算法。V08/D20/A14 仍 P，功能完成任务数不变；托盘无加载冷启动、独立弹窗宿主、渲染职责及实机生命周期仍待处理。未运行构建、自动化测试、CI、打包或实机验收。

- 2026-11-27 功能模块归类复核：基于 01ad5c1f，完整核对 19 个模块目录及 233 个模块源码、配置及资源文件，确认 source-map 已覆盖 230 个直接映射源和 3 个布局渲染输入，未发现未归属模块源或重复输出目标。明确 System Tray、Digital Clock、Start 三个共享宿主的功能所有权和跨模块接口；将 NotificationHistory 复用的两个 Calendar 控件列入既有公共控件归类范围。八项冻结清单第 1 项完成；V07/V08/A14 及第 2 项不因此结项。仅更新架构文档，未修改运行时代码，未运行构建、测试、CI、打包或实机验收。

- 2026-11-28 公共视觉参数统一批次：基于 73277b54dbc4，日历紧凑时钟悬停、搜索筛选与分类标题、托盘隐藏图标与快捷设置组、登录用户切换列表，以及快捷设置滑块的图标/详情操作按钮改为读取 `core/design/controlMetrics.js` 的 `ControlCornerRadius`。保留通知/媒体/剪贴板卡片、任务预览卡片及其他专用表面几何。共享指标源与现有 source-map 输出不变，未新增部署副本。仅做源码和提交 diff 静态审查，未运行构建、测试、CI、打包或实机验收；A14 仍为 P。

- 2026-11-28 任务栏预览控件参数收敛：基于 4b7c17e94953，任务栏窗口预览关闭按钮的交互背景改为读取公共 `ControlCornerRadius`，并将 `controlMetrics.js` 映射到 Icon Tasks 的唯一生成目录。保留预览卡片自身圆角和关闭按钮的红色悬停/按压状态。更新 A14 记录；未运行构建、测试、CI、打包或实机验收。

- 2026-11-28 WinUI 菜单行高统一：基于 08673f168c25，Start ContextMenu 与 ViewModeMenu 的 32px 最小行高改为读取 `ControlMetrics.menuItemMinimumHeight`，与锁屏/登录 `FluentPowerMenuItem` 共用 `MenuFlyoutThemeMinHeight`。补充两个菜单消费者的一致性断言，并更新 core 所有权说明。未改变菜单宽度、文本高度扩展、分隔线、内边距、键盘导航或弹出定位；未运行测试、构建、CI 或实机验收。

- 2026-11-28 登录按钮圆角归一：基于 24284e2ff305，Login 与 LockScreen 的无密码 Sign in 按钮将相同的 6px 圆角收敛到 `core/design/lockMetrics.js`，由 WinStyle 和 NoPasswordUnlock 分别消费。保留两个宿主不同的按钮高度、宽度、字体及状态反馈；补充共享参数断言。未运行构建、测试、CI、打包或实机验收。

- 2026-11-28 登录与锁屏电源菜单半径统一：基于 80acbf25612f，LockScreen 原生电源菜单从独立 6px 圆角改为读取 `LockMetrics.menuRadius`，与 Login 电源菜单共用 26H2 `OverlayCornerRadius=8`。依据 `CommonStyles.xbf` 中 `DefaultMenuFlyoutPresenterStyle` 对该资源的实际引用。菜单内容、尺寸、锚点和交互不变；未运行构建、测试、CI、打包或实机验收。

- 2026-11-28 A14 部署与资源审计：检查 testing 的 5,851 个跟踪文件及精确 SHA 重复组，未发现 icons/Plasma SVG atlas 之外的重复 QML、JS、Python 或 C++ 文件。壁纸包共 4 个文件，哈希无重复。静态核对 `materialize-modules.py`、普通安装、NixOS 安装、独立组件安装及完整 ZIP 生成入口，均有对应的源码准备/映射检查或归档物化步骤。发现 3 组 Plasma SVG atlas 文件跨 solid/translucent 目录字节相同，留在既有 SVG 资源统一工作块，本项不修改。未执行新 clone、安装、打包、构建或测试。

- 2026-11-28 Start/Search 卡片参数统一：基于 dc477f735d9e，SearchHome 快捷搜索容器、All Apps 分类卡片和分类展开面板共用 `ControlMetrics.cardSurfaceRadius`。该 8px 参数保留现有显示，不与数值相同但语义不同的 `OverlayCornerRadius` 混用。为三类消费者增加对象标识与 QML 一致性断言；source-map 已有的 Start package 输出覆盖 SearchHome 子树，无需新增映射或部署副本。未运行测试、构建、CI、打包或实机验收。

- 2026-11-28 Start 控件圆角统一：基于 628c51e70641，Start 列表项悬停背景、焦点边框及 AToolButton 从依赖 `Kirigami.Units.smallSpacing` 改为读取 `ControlMetrics.controlCornerRadius`，避免控件圆角随 KDE 间距设置漂移。保留列表高度、内边距、焦点状态和拖放指示线；增加 QML 断言覆盖三个圆角消费者。未运行测试、构建、CI、打包或实机验收。

- 2026-11-28 Alt+Tab 公共圆角接入：基于 82d9d50aac78，窗口切换器卡片半径改为 `ControlMetrics.cardSurfaceRadius`，关闭按钮与预览遮罩的小圆角改为 `ControlMetrics.controlCornerRadius`，继续乘以原有 `unit`，不改变现有 UI/DPI 缩放关系。将公共指标映射到 Alt+Tab 唯一包路径，并补充对应参数断言。未改变卡片尺寸、排布、焦点环宽度或缩略图行为；未运行测试、构建、CI、打包或实机验收。

- 2026-11-28 RunDialog 按钮圆角统一：基于 f67285c1101c，RunDialog 的标准 Run 操作按钮从独立 5px 圆角改为读取 WinUI `ControlCornerRadius`（4px）。该 Run 模块由现有 source-map 物化到 System Tray 包，复用已部署的 `controlMetrics.js`，无需新增生成副本。保留按钮尺寸、边框、悬停/按压状态及命令执行逻辑；增加 QML 参数断言。未运行测试、构建、CI、打包或实机验收。

- 2026-11-28 Quick Settings 媒体卡片圆角统一：基于 4aef4a00071e，MediaCard 外层卡片从独立 `8 * uiScale` 改为 `ControlMetrics.cardSurfaceRadius * uiScale`，与 Start/Search/Alt+Tab 卡片共用语义参数。保留 UI scale 乘数和内部传输按钮/封面 artwork 的独立圆角；增加 100% 与 125% UI scale 参数断言。无需新增 source-map 输出；未运行测试、构建、CI、打包或实机验收。

- 2026-11-28 Quick Settings 详情页按钮高度统一：基于 583e347427e9，将 Bluetooth 与 Network 详情页的 Connect/Disconnect/Cancel/Next 及密码显隐操作按钮统一读取 `TrayMetrics.detailActionButtonHeight`（30 logical px）。同步统一 Network 展开态中为按钮预留的同高布局槽；Bluetooth 分组标题高度、设备列表行高及其他非操作布局保持独立。新增 trayMetrics 参数断言；未运行测试、构建、CI、打包或实机验收。

- 2026-11-28 Quick Settings 详情页行布局参数统一：基于 28ec2fc59a4f，将 Wi-Fi、Bluetooth 与安全移除设备列表的 8px 行外边距收敛到 `detailRowOuterInset`；Wi-Fi/Bluetooth 行内 12px 内容边距与图标文本间距分别收敛到 `detailContentInset` 和 `detailRowSpacing`。保留 section header、ListView 行高、Network 展开动画和设备操作布局。扩展 trayMetrics 参数断言；未运行测试、构建、CI、打包或实机验收。

- 2026-11-28 Quick Settings 设备列表图标槽统一：基于 768335d5171b，将 Bluetooth、Network 与 Device Notifier 设备列表的 24px 前导图标槽收敛到 `detailRowIconExtent`。保留图标源、绘制边界、文字布局及各列表自身行高；扩展 trayMetrics 参数断言。未运行测试、构建、CI、打包或实机验收。

- 2026-11-28 Digital Clock 通知卡片语义拆分：基于 04090e995d40，NotificationHistory 内部消息卡片从复用外层 `ClockMetrics.flyoutCardRadius` 改为读取公共 `ControlMetrics.cardSurfaceRadius`。外层通知/日历飞出面板继续使用 overlay 半径；两者当前均为 8px，视觉数值不变，但语义来源分离。复用 Digital Clock 已有的 controlMetrics 生成输出，无新增部署副本。未运行测试、构建、CI、打包或实机验收。

- 2026-11-28 Search 列表控件圆角统一：基于 d88cb0977670，SearchHome 建议列表按钮、Top Apps 磁贴及 SearchPage 结果悬停背景统一读取 `ControlMetrics.controlCornerRadius`，消除建议项 5px 与其余列表控件的分叉，并移除对 KDE `smallSpacing` 的视觉依赖。保留 Top Apps 磁贴尺寸、建议行高度、搜索结果布局和交互；为 SearchHome 两类按钮增加参数断言。未运行测试、构建、CI、打包或实机验收。


- 2026-11-28 Login/LockScreen 公共几何参数收敛：基于 33842d43894e，将两处时钟的行距比例及电源菜单内边距移入 `core/design/lockMetrics.js`；登录与锁屏菜单宽度改为具名宿主参数，保留当前 150/160 逻辑像素，未在缺少 26H2 模板证据时强行统一数值。两个菜单继续共用现有 OverlayCornerRadius 和菜单项组件。移除 `WinStyle.powerMenuItemHeight=36` 未使用参数。更新布局参数断言与核心所有权说明；未运行构建、测试、CI、打包或实机验收，A14 仍为 P。

- 2026-11-28 公共交互参数与详情行圆角收敛：基于 8132062808a7，Start/Search 的悬停颜色、焦点/拖动透明度过渡统一读取 `ControlMetrics.microInteractionDuration`（保留现有 90ms，不宣称为原生 XAML 参数）。Quick Settings 的 Device Notifier 行卡片改用 `ControlMetrics.controlCornerRadius`，与 Wi-Fi/Bluetooth 详情行保持同一圆角语义，保留行高、内边距、展开状态和设备动作。新增设备行圆角参数断言；复用现有 source-map，无新增部署副本。未运行构建、测试、CI、打包或实机验收，A14 仍为 P。


- 2026-11-28 System Tray 溢出箭头圆角统一：基于 1943f0f55d15，隐藏图标溢出箭头的悬停/展开背景从独立 4px 改为读取 `ControlMetrics.controlCornerRadius`。与托盘普通图标悬停控件使用同一 WinUI 控件圆角；保留背景颜色、可见状态、点击行为和旋转动画。复用现有 source-map 输出，无新增部署副本。静态核对完成，未运行构建、测试、CI、打包或实机验收，A14 仍为 P。


- 2026-11-28 剪贴板与任务栏预览卡片参数收敛：基于 48d8469730a5，剪贴板历史可交互条目圆角改为读取 `ControlMetrics.controlCornerRadius`，与系统详情列表控件共用标准控件半径；任务栏窗口预览整卡悬停表面改为读取 `ControlMetrics.cardSurfaceRadius`，与其他卡片表面共用独立卡片半径。保留卡片尺寸、边框、选择状态、缩略图和悬停反馈；为剪贴板条目增加参数断言。两个宿主均已有 controlMetrics 生成路径，无新增部署副本。未运行构建、测试、CI、打包或实机验收，A14 仍为 P。


- 2026-11-28 Windows Taskbar Search 圆角参数归一：基于 a251f246463f，依据 Windows 11 26H2 `TaskbarResources.xbf` 的 `SearchBoxRoundCornerRadius=16`，新增 `ControlMetrics.searchBoxCornerRadius`，Search applet 的 SearchBox 改为读取共享参数并保留高度约束下的 `min(height / 2, token)` 行为。将 controlMetrics.js 加入 Search applet 唯一生成输出，并把原测试中的字面值断言改为共享参数断言。未触碰 shy-taskbar 的独立 30px 资源参数；未运行构建、测试、CI、打包或实机验收，A14 仍为 P。


- 2026-11-28 Start 电源菜单微交互参数收敛：基于 testing 基线 `a4952d69`，`PowerOption.qml` 的悬停/焦点透明度过渡由独立 80ms 改为读取 `core/design/controlMetrics.js` 的 `microInteractionDuration`（90ms），与 Start 列表、按钮及关闭菜单的同类短时反馈统一。仅调整同语义状态过渡，不改菜单行高、圆角、颜色、可见条件、键盘导航或动作；现有 source-map 已输出 `controlMetrics.js` 到 Start 包，无新增映射或部署副本。完成源码引用、路径与变更差异静态审查；未运行构建、测试、CI、打包或实机验收，第 5 项与 A14 仍为部分完成。


- 2026-11-28 Start 搜索框微交互参数收敛：`modules/search/startmenu/components/StartSearchField.qml` 的悬停背景与焦点边框动画统一读取 `ControlMetrics.microInteractionDuration`（90ms），并保留 `Kirigami.Units.shortDuration > 0` 的动画关闭门控。两种状态反馈与 Start 列表、按钮、电源菜单选项使用同一项目级微交互参数；未改搜索框高度、胶囊圆角、内边距、颜色、RTL、键盘输入或搜索行为。现有 source-map 已输出 `controlMetrics.js` 到 Start 包，无新增映射或部署副本。完成导入路径与变更差异静态审查；未运行构建、测试、CI、打包或实机验收，A14 仍为 P。


- 2026-11-28 公共视觉参数统一收口与复核：基于 testing 基线 `e113e4c5`，完成全仓 QML/JS 剩余同语义视觉参数收敛。Start/Search 的分类标签、字母分组标题及字母索引磁贴交互过渡统一读取 `ControlMetrics.microInteractionDuration`（保留动画关闭门控），网格单元高度（84px）、大/中应用图标槽（32/24px）与内嵌滚动条预留槽（18px）集中至 `startMenuMetrics.js`；Quick Settings/Clipboard 的 `PageHeader` 与清空按钮接入 `detailActionButtonHeight`，剪贴板卡片宽度直接绑定 `FluentScrollBar` 宽度，`Footer` 底角回退半径接入 `cardSurfaceRadius * uiScale`，`ListRow`/`SectionHeader`/`VolumePage`/`VolumeMixerSection`/`BatteryPage` 紧凑行参数、音量设备折叠区箭头/动画参数及 WinUI `Slider` 槽高/内外手柄状态尺寸归入 `trayMetrics.js`；Login/LockScreen 的凭据与列表 14px 字号、无密码登录按钮宽度与描边、焦点底边指示条、32px 底栏状态按钮与 16px 底栏边距归入 `lockMetrics.js`；Digital Clock/Notifications 的 28px/24px 飞出操作按钮尺寸归入 `clockMetrics.js`。同步补充静态测试断言并更新 `core/README.md`，同时修正 `scripts/materialize-modules.py` 父目录检查的 `Path`/字符串键比较缺陷。复用现有 `source-map.json`，无新增部署副本，保留全部独立视觉角色、宿主缩放公式与独立渲染器边界。冻结架构清单第 5 项「公共视觉参数统一」完成；A14 保持 P（新 clone/安装/打包及原版参数真实性待维护者验收），未运行构建、自动化测试、CI、打包或实机验收。

- 2026-11-28 模块接口解耦收口与复核：基于 testing 基线 `56fd0d8b`，完成全仓 182 个规范 QML 文件的跨组件隐式 ID 与父链耦合清理。Start/Search 的 `SearchPage`、`PinnedPage`、`AlphabeticalAppsView`、`AllAppsPage`、`ListItemDelegate`、`CompactRepresentation` 与 `MenuRepresentation` 全部改为显式属性、回调与信号通信；Icon Tasks 的 `Task`、`ContextMenu`、`ToolTipDelegate`、`ToolTipInstance`、`ToolTipWindowMouseArea`、`PulseAudio`、`PlayerController`、`MouseHandler` 及四个懒加载覆盖层（`TaskProgressOverlay`、`TaskBadgeOverlay`、`GroupExpanderOverlay`、`PipeWireThumbnail`）统一通过 `tasksRoot`/`hostDelegate`/`setSource` 接收显式输入并补齐 `Bound` 作用域约束；System Tray 的 `ExpandedRepresentation`、`HiddenItemsView`、`PlasmoidPopupsContainer`、`ExpanderArrow`、`CurrentItemHighLight`、`ItemLoader`、`AbstractItem`、`PlasmoidItem`、`BackgroundAppItem` 统一显式接收 `trayRoot`/`trayState`/`popupDialog`/`preloadHost`；LockScreen（`LockScreenUi`、`MainBlock`、`MediaControls`）与 Login（`Login.qml`）移除跨文件外层 ID 引用。补充 `PinnedPage` 独立作用域测试断言并更新 `modules/README.md`。保持真实 KDE 模型唯一且无新增生成副本；冻结架构清单第 6 项「模块接口解耦」完成，V07 保持 P（待实机验收），未运行构建、自动化测试、CI、打包或实机验收。

- 2026-11-28 全局功能生命周期分离收口与复核：基于 testing 基线 `eefee7ac`，消除全局外观监听、Win+R/V 路由、同面板弹窗协调及分体模糊对系统托盘二进制存活的耦合。`ShellAppearanceMonitor` 与 `ShellShortcutRouter` 改为 `Q_DECL_HIDDEN` 并通过 `QObject` 子对象名 + `QMetaObject` 槽跨插件调用，由 `System Tray`、`Icon Tasks`、`Desktop Context Menu` 任一已加载插件幂等初始化；冷启动无托盘时认领已迁移的 `Win+R`/`Win+V` 绑定走原生 KRunner/Klipper 回退，单独卸载托盘时新增 `clipboard-release` 与既有 `run-release` 同步归还原生绑定。新增 `PanelPopupHost` 将 `PanelPopupController` 与 `PopupEffects` 挂载到每个 `Panel`/`CustomPanel` Containment 的 `windowsModernPanelPopups` 内部动作，`Start`、`Digital Clock` 与 `System Tray` 共享面板级宿主并在组件移除（含 Plasma undo 期）、恢复或跨面板移动时自动收起弹窗、跳过 `destroyed()` 实例。补齐 `systemtray`/`icontasks` 的 `controlMetrics.js` CMake QRC 注册及面板能力/剪贴板释放测试断言，更新 `core`/`modules`/`platform` 文档。未新增常驻进程或轮询，Nix 构建配方不变；冻结架构清单第 7 项「全局功能生命周期分离」完成，V08 保持 P（待实机验收），未运行构建、自动化测试、CI、打包或实机验收。

- 2026-11-28 配色与材质内部解耦收口与复核：基于 testing 基线 `9d33a9b3`，新增 `core/palette/accent-algorithms.py`（纯色阶/对比色/批次比对/壁纸解码与加权取色算法）、`core/palette/accent-renderers.py`（KDE `.colors` 渲染、Kvantum 强调色绑定与 `live-reload.json` 刷新回执）及 `platform/plasma/appearance/appearance-host.py`（KDE 会话配置读取、模式/渲染器判别与实时壁纸 D-Bus 快照校验），`sync-accent.py` 保留原有 CLI 与兼容导出门面，`accent-control.py`、`window-frames.py`、`appearance-packages.py` 全部改为 `importlib` 显式模块加载，消除外观管线内部 `runpy` 字典调用。明确并落实非 Kvantum 边界：非 Kvantum `widgetStyle` 或缺失用户目录 `~/.config/Kvantum/Windows-modern` 时正常同步 KDE `.colors`、`[WindowsModernAccent]`、Plasma 调色板、Aurorae 窗口装饰 tint 与 Plasma 透明选择器，启用 Kvantum 或存在本地 Kvantum 资源时维持严格完整性与回滚保护。保留全部原版取色算术、ICC 重放、锁与缓存版本，同步更新 `source-map.json`（新增 3 个源码相对链接，共 648 个输出）、外观包脚本清单、归档校验器、测试断言与文档。冻结架构清单第 8 项「配色与材质内部解耦」完成（架构改革 8/8 全部收口），D20 保持 P（待功能演进与实机验收），未运行构建、自动化测试、CI、打包或实机验收。

- 2026-11-28 工作块 01（全局视觉规范、PRI/Photon 证据、RTL/DPI 与系统排版）推进与复核：基于 testing 基线 `38c39f1e`，将本地私有 `26H2/` 解包目录加入 `.gitignore` 与 `verify-owner-bundle.py` 开发排除清单，并为总账 11 个工作块补齐规范源码目录归属。只读复核 `26300.9974` 的 19 个原始布局来源与 1,481 个有效 XBF，证实 `StartMenuExperienceHost` + `StartDocked.dll` 原生 XAML 持有 Start 主外框、固定网格、全部应用与电源菜单，而 `MicrosoftWindows.Client.Photon` 的 `Windows.Shell.StartMenu` wsxpack 仅承载嵌入的 Recommended 推荐流；扩充并逐字节核验 `windows11-26h2-ui-parameters.json` 至 22 个 XBF 来源（补齐 `21h1_themeresources` 字号/控件/滚动条/菜单/动画时长、`StartDocked\TileStyles`、`TaskbarSearchPageThemeResources`、`Styles.Win11`、`JumpViewUI\RefreshedStyles` 与 `LockApp\StandardStyles`）。修复 `MediaControls` 硬编码 `"Segoe UI"` 字体及 `NoPasswordUnlock`/`SearchHome` 字体绑定；补齐 `TaskbarButton`、`TaskbarGlyph`、`AccountAvatar`、`MediaControls`、Start 头像与预览封面的非零整数 DPR `sourceSize` 守卫；补齐 Login 电源菜单、剪贴板动作菜单、Start/Search 列表/建议/折叠箭头/底栏位置栏/`AToolButton`/视图选择器、RTL 顶边任务栏 Search 锚点、锁屏用户切换、`MoreSettingsLink`、`NativeButtonContent` 与 Alt+Tab 的 RTL 镜像，以及多处 `Text.PlainText`/省略截断与 `RunDialog`/`MoreSettingsLink`/`SearchHome` 的系统字号扩展。A01–A04 保持 P（待下游消费者细节收口与实机验收），未运行构建、自动化测试、CI、打包或实机验收。

- 2026-11-28 工作块 02–06（原始图标/原版光标、基础控件/桌面右键菜单、动态配色/材质、任务栏/系统托盘、开始菜单/搜索）依次推进与提交（`03ad323`、`74c2db1`、`ef88d75`、`ef0cfdc`、`64eee79`）：完成 26H2 原版光标导入器（`A09` `P→I`）、桌面右键菜单完整动词顺序与双色强调图标/终端启动（`C01` `P→I`）、`uxtheme.dll`/`windowsudk.shellcommon.dll` 48 组 336 色阶逐字节复核与 `ConfigColors.qml` 颜色设置界面（`D01`/`D15` `P→I`、`M04` `U→P`）、任务栏启动器/搜索/任务视图/显示桌面入口及跳转列表 294px/捕获隐私指示器/预览高亮收口（`T06` `P→I`），以及 Start/Search `642×750` 与 `834×890` 原版 CP3 几何、8 列网格、搜索清除按钮、账户/电源菜单分离与 `OpenKeySpline`/`CloseKeySpline` 曲线对齐（`S01`/`S03`/`S05`/`S06` `P→I`）。仅做源码、26H2 只读解析与完整差异静态审查，未运行构建、自动化测试、CI、打包或实机验收。

- 2026-11-28 工作块 07（快捷中心、剪贴板、通知中心与日历 `Q01`–`Q15`）推进与复核：基于 testing 基线 `64eee79e`，按 26H2 `ActionCenter/Styling/Styles.Win11.xbf` 与 `styles.xbf`（`NotificationCenterFlyoutWidth = 360`、`NotificationCenterFlyoutMargin = 12,8,12,0`、`NotificationCenterFlyoutActualWidth = 312`、`GroupHeaderMinHeight = 32`、`AppLogoIconSize = 16`）将通知/日历飞出卡片默认宽度由 `320` 对齐为 `336px`（内层 `312px`），补齐通知分组头 `32px` 最小高度、`16px` 非整数缩放应用图标、内联回复框 `32px` 最小高度与勿扰横幅 RTL 对齐；补齐 `CalendarView` 月视图左右方向键与月份标题 RTL 镜像及 `CalendarGrid`/`CalendarZoomGrid` 减弱动画无闪烁守卫；补齐 `ActionPanel` 空屏守卫、`Tile`/`SplitTile` 键盘菜单键入口、`Page`/`DetailPage` `Alt+Left`（RTL `Alt+Right`）/ `Back` 返回快捷键、`Footer` RTL 继承、`NetworkPage` 非主动断开连接失败反馈（`Can't connect to this network`）、`BluetoothPage` 分组头截断与 RTL、`VolumeMixerSection` 单应用图标点击/键盘静音切换、`InputDeviceSection` 麦克风音量/静音滑块、`BatteryPage` 无电池台式机动态标题（`Power Mode`）与电量条 RTL、`MediaCard` 封面圆角遮罩与 DPR `sourceSize`、`ClipboardPage` 上下方向键/`Delete` 键与图片预览 DPR `sourceSize`、`EmojiPicker` 清除搜索按钮与网格键盘导航、`windows-shortcuts.py` 检测到 `org.gnome.NetworkDisplays` 时的条件 `Win+K` 绑定/备份恢复，以及 `Win+V` 关闭时的 `restoreShellPopupFocus()` 焦点组恢复。`Q01`/`Q02`/`Q04`–`Q07`/`Q09`/`Q11`/`Q13`–`Q15` 由 `P` 更新为 `I`（已实现 32/94 = 34.0%），`Q03`/`Q08`/`Q10`/`Q12` 因宿主边界与实机比例复核要求保持 `P`；未运行构建、自动化测试、CI、打包或实机验收。
