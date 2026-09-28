## Why

pin 的菜单现在为快捷操作增加两个整行菜单项（Copy Path / Open with Claude Code），把文件夹标题区从一行撑到三行——用户明确不接受：原来「一个条目，点击 Finder 打开」的紧凑形态必须保留。同时用户要 pin `~/projects`（44 个子目录）作为单一菜单栏图标，每个子目录行同样需要行内快捷操作与显示别名，而现有行式实现无法扩展到这个规模。

## What Changes

- 新增 `ActionRowView`（custom view 菜单行）：一行内 `[图标][名称……][⧉][>_]`——名称区点击执行主操作，两个行内图标按钮各自触发复制路径 / iTerm 启动 claude，点击后菜单自动关闭。
- pin 的标题行改用该行组件（**替换**现有的两个整行快捷操作项，回到单行形态）；行内按钮复用已提交的 Copy Path / Open with Claude Code 逻辑。
- 子目录行（`FolderMenu.buildItems` 的 folder 分支）同样改用该行组件：显示名优先取该子目录路径的别名（复用 `InstancePrefs`，零新存储）；行内按钮以该子目录路径执行操作。
- 每个子目录的悬停子菜单顶部新增「Rename…」项，打开现有别名编辑窗口为该子目录设定显示名。
- 快捷操作逻辑（pasteboard 写入、AppleScript 两步式、双层转义）从 `FolderPin` 抽到共享入口，pin 行与子目录行共用。
- 别名读取在每次菜单构建时一次性快照（避免 44 个子目录 = 44 次全量 UserDefaults 解码）。

## Capabilities

### New Capabilities

- `inline-row-actions`: 菜单行内的多操作呈现——单个 custom view 菜单行承载名称主操作与行内图标快捷操作（复制路径、启动 claude），并覆盖 pin 标题行与子目录行两层；子目录行接别名展示与 Rename… 入口。

### Modified Capabilities

（无已归档 spec——`folder-quick-actions` 与 `folder-alias` 尚在 in-flight changes 中，其呈现形态由本能力演进，行为契约在各自 change 内保持有效。）

## Impact

- **代码**：新增 `ActionRowView.swift`、`QuickActions.swift`；修改 `FolderPin.swift`（标题行替换、操作转调共享入口）、`FolderMenu.swift`（子目录行 + 子菜单 Rename… + 别名快照）、`FolderAliasWindow.swift`（确认回调由 target-action 改为闭包）、`Prefs.swift`（别名快照 helper）。
- **行为变化**：pin 菜单标题区从三行回一行；两个快捷操作从整行菜单项变为行内图标按钮（原交互语义不变：剪贴板内容、AppleScript 链路逐字保留）。
- **用户数据**：`~/projects`（44 个子目录，`maxItems=250` 全量展示）作为典型用例验收。
- 零新依赖；macOS 13+；Swift 6（全部组件 @MainActor）。
