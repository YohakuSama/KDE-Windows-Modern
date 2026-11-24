Windows 11 资源索引

三份 MUN 共 713 个图标组，5,405 帧。共有两个名称型图标组。完整扫描与独立 PE 解析结果一致。未发现缺失或损坏的图标组及帧。

将目录下载到本地后，打开 icon-index.html 浏览和筛选图标。icon-index.csv 按帧记录组 ID、语言 ID、帧资源 ID、尺寸、色深和对应文件。

KDE 映射沿用项目现有前缀。i 对应 imageres.dll.mun，x 对应 imagesp1.dll.mun，s 对应 shell32.dll.mun。名称型图标组使用清单中的原始名称。

ico 目录按原始顺序打包图标组，帧使用 MUN 中的原始字节。png 目录按帧提供原尺寸预览。原生 PNG 直接提取，DIB 帧转换为 PNG。

original 目录包含源压缩包中的全部 467 个文件。resource-manifest.json 记录路径、SHA-256、资源 ID 和源压缩包指纹。原压缩包中的空目录也列在清单里。

verification.json 记录缺失、损坏和重复资源。内容完全相同的 ICO 有 123 组重复记录。帧原始字节相同的记录有 959 组。尺寸与 RGBA 像素均相同的记录有 964 组。原始文件有 3 组内容重复。各原始路径和资源 ID 均保留。
