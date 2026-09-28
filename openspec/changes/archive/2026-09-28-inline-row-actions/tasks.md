## 1. 共享操作与数据基础

- [x] 1.1 新建 `QuickActions.swift`：`copyPath(_ url:)` 与 `openClaude(_ url:)`（双层转义 + 两步式 AppleScript 从 `FolderPin` 平移，行为零改动），`FolderPin` 的两个 action 改为转调，`swift build` 通过
- [x] 1.2 `Prefs.swift`：`InstancePrefs.aliasSnapshot() -> [String: String]`（单次解码整字典），单元验证：设置 alias 后快照含该映射、未设置为空（复用 /tmp decode 测试模式）

## 2. ActionRowView 组件

- [x] 2.1 新建 `ActionRowView.swift`：NSView 行（图标 + 截断标题 + 两个 20pt 图标按钮区），手动布局（design D8 几何），`NSTrackingArea` hover 高亮（背景 `selectedContentBackgroundColor`、文本/图标转白，D3），`mouseDown` hit-test 分派（D1/D2：按钮 → 闭包 + `cancelTracking()`；标题区按行形态分派），tooltip 显完整路径
- [x] 2.2 `FolderPin.layout()` 标题行改用 `ActionRowView`（主操作 = `openInFinder`，闭包调 `QuickActions`），删除两个整行快捷操作菜单项与 `quickActionItem`/图标静态属性；构建后 SE 点开菜单确认标题区为单行、无整行操作项

## 3. 子目录行接入

- [x] 3.1 `FolderAliasWindow` 回调改闭包 `show(prefill:onConfirm:)`（D6），`FolderPin.renameFolder` 适配（`[weak self]` 断环），pin 级 Rename… 全流程回归（设/清/取消）
- [x] 3.2 `FolderMenu.buildItems` folder 分支改用 `ActionRowView`：标题取 `aliasSnapshot[path] ?? displayName`（D5 快照），按钮闭包调 `QuickActions(该子目录 URL)`；子菜单照常挂接
- [x] 3.3 `FolderMenuDelegate` 子菜单顶部加「Rename…」（D7：懒持窗口、confirm 写 `InstancePrefs`）；为某子目录设别名后重开菜单确认行名变化、清空回落

## 4. 整体验证与提交

- [x] 4.1 `swift build -c release` 通过；自动化验证：pin `~/projects` → SE 枚举菜单（44 行无截断）、子目录行 Copy Path 剪贴板比对、iTerm 动作窗口标题比对、悬停子菜单照常、标题行按钮后菜单关闭
- [x] 4.2 用户验收：行内图标观感与 hover 高亮、`~/projects` 实操（浏览/复制/起 claude/子目录改名）；提交 `feat(actions): inline row action buttons replacing two-row menu items`（Conventional Commits，尾部 `Co-Authored-By: Claude Code <noreply@anthropic.com>`）
