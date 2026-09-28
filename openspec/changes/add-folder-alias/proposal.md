## Why

用户把实际目录名（如 `project`、`Downloads`）固定到菜单栏后，菜单里显示的名字无法反映用途。目录本身不能随便改名（路径被脚本、IDE 配置等引用），需要一个纯展示层的别名（如「代码库」），覆盖菜单栏图标、tooltip 和下拉菜单中的显示，而不触碰真实文件系统。

## What Changes

- `DisplayOptions`（`Prefs.swift:30`）新增可选字段 `var alias: String?`，随现有的 per-folder UserDefaults 持久化（`InstancePrefs`，key 为文件夹路径）一起存取。
- `FolderPin` 中所有顶层展示点从 `url.displayName` 切换为 `alias ?? displayName`：
  - 状态栏图标字母（`FolderPin.swift:30`）
  - 状态栏按钮 tooltip（`FolderPin.swift:31`）
  - 菜单标题（`FolderPin.swift:68`）
  - 菜单项 tooltip（`FolderPin.swift:73`）
- 新增别名后的即时刷新路径：重设 statusItem 按钮的 image 与 toolTip（现状只在 `init` 设置一次，改别名后不刷新是本变更修复的缺口）。
- 别名编辑入口：`FolderPin.displaySectionItems()`（`FolderPin.swift:89`）新增 "Rename…" 菜单项，点击弹出带 `NSTextField` 的独立小窗口（模式参考 `BrowserBookmarksWindow.swift`），确认后生效。
- 无别名的文件夹名称类展示（菜单标题、tooltip 等）与现状一致（alias 为 nil 时回落 `displayName`）。
- **顺带的行为修复（有意为之）**：图标取字的宽字符适配对**所有**固定文件夹全局生效——名为「项目」的文件夹（无论有无别名）图标字母从「项目」（2 个 11pt 汉字 ≈22pt，溢出压住文件夹图形）修正为「项」。名称展示不受影响。

## Capabilities

### New Capabilities

- `folder-alias`: 为固定的文件夹提供纯展示层的自定义名称——存储、编辑入口（Rename… 窗口）、菜单栏图标/tooltip/菜单标题的展示替换、以及修改后的即时刷新。

### Modified Capabilities

（无——项目尚无已归档 spec，本变更是首个能力。）

## Impact

- **代码**：`Sources/MenuBarFolder/Prefs.swift`（DisplayOptions 结构）、`FolderPin.swift`（展示替换、Rename… 入口、刷新方法）、新增一个小窗口类型（独立文件，模式抄 `BrowserBookmarksWindow.swift`）。
- **数据兼容**：老用户已存的 `DisplayOptions` JSON 不含 `alias` 字段。Swift 合成 Codable 对 Optional 属性自动使用 `decodeIfPresent`，旧数据可正常解码，无迁移代码需求（已验证持久化路径为整字典 `[String: DisplayOptions]`，解码失败会整表回落默认值，故此兼容性是安全前提而非可选优化）。
- **不改动**：真实目录名、文件系统、排序/分组逻辑（`SortMode`/`foldersOnTop`）、`FolderMenu` 子项的 displayName 用途（`FolderMenu.swift:207/236` 是子内容，不涉及）。
- **依赖**：零新依赖。macOS 13+，Swift 6 并发（Action 方法置于 `@MainActor` 的 `FolderPin` 内）。
