## Context

见 proposal.md 与 specs/inline-row-actions/spec.md。已提交的基础（`80fa8ea`）：Copy Path 的 pasteboard 写入、iTerm2 两步式 AppleScript（`create window` + `write text`）与双层转义、`InstancePrefs` 按路径的 alias 持久化、`FolderAliasWindow` 编辑面板。本变更全部复用，核心新增只有 `ActionRowView` 一个组件。代码事实：

- `FolderPin.layout()`（`FolderPin.swift`）当前以两个整行菜单项呈现快捷操作——本变更替换为行组件。
- 子目录行由 `FolderMenu.buildItems` 的 folder 分支构建（`FolderMenu.swift:200-219`），目录行挂惰性子菜单（各自的 `FolderMenuDelegate`）。
- `InstancePrefs.load` 每次调用都做一次整字典 UserDefaults 解码（`Prefs.swift:79-83`）——44 行 × 每行一次不可接受，需快照。
- `FolderAliasWindow` 当前以 target-action 对接 `FolderPin.applyAlias`；子目录改名需要另一条对接路径。

## Goals / Non-Goals

**Goals:**

- 单行呈现（名称主操作 + 行内按钮）覆盖 pin 标题行与子目录行。
- 子目录别名（展示 + Rename… 入口 + 持久化）。
- `~/projects`（44 子目录）全量、流畅。
- 已验证的操作语义（剪贴板内容、AppleScript 命令串）逐字不变。

**Non-Goals:**

- 不改 Sort by / Folders on top / maxItems / 子菜单内容加载等既有行为。
- 不做行内第三个以上按钮（保持 ⧉ + >_ 两个，留扩展位）。
- 不做子目录行的右键菜单（macOS 菜单无右键语义）。
- pin 级与子目录级的 Rename 窗口不合并管理（各自持有窗口实例）。

## Decisions

**D1: 行组件不用真实 NSButton，mouseDown 手动 hit-test。**
菜单跟踪会吞掉控件的常规事件回路（这是 AppKit 已知行为），custom view 行内的"按钮"用 `NSImageView` 纯展示，`ActionRowView.mouseDown(with:)` 里按 rect 命中分发：命中按钮 → 执行对应闭包并 `menuItem.menu?.cancelTracking()`；未命中 → 走主操作（标题区点击）。

**D2: 点击分派按行的存在形态区分。**
pin 标题行（无子菜单）：未命中按钮 = 打开 Finder。子目录行（有子菜单）：未命中区域不做特殊处理——交给菜单跟踪的自然行为（悬停/点击展开子菜单），避免与子菜单语义打架。Finder 打开同时提供为行内按钮（用户验收后补充：子目录行也需要直达 Finder，与复制/终端并列成三按钮组）。

**D3: hover 高亮自绘。**
`NSTrackingArea(mouseEnteredAndExited)` 切换高亮态：背景 `selectedContentBackgroundColor`、文本与模板图标转白色；离开恢复。custom view 行不享受系统高亮，必须自画，否则行"死"在菜单里没有反馈。

**D4: 快捷操作抽到 `QuickActions`（enum + static）。**
`copyPath(_ url: URL)` 与 `openClaude(_ url: URL)`（含 shell/AppleScript 双层转义与两步式脚本）从 `FolderPin` 平移。pin 与子目录行都以 URL 调用。操作行为零改动（纯搬家），已提交的两条验证链继续有效。

**D5: 子目录别名走单次快照。**
`InstancePrefs.aliasSnapshot() -> [String: String]`：一次解码整字典，抽出 `path → alias`。`buildItems` 开头取一次，行构建 O(1) 查表。设置/清除仍走既有 `InstancePrefs.set`。

**D6: `FolderAliasWindow` 回调改闭包。**
`show(prefill:onConfirm:)`，`onConfirm: (String) -> Void` 由调用方弱捕获自身（`[weak pin]` / `[weak delegate]`）。窗口强持闭包、调用方强持窗口，弱捕获断环。pin 级与子目录级共用同一窗口类。

**D7: 子目录 Rename… 放其子菜单顶部。**
由持有该子菜单的 `FolderMenuDelegate` 提供（菜单项 + 懒持有的窗口实例 + confirm 闭包写 `InstancePrefs`）。子菜单每次打开经 `menuNeedsUpdate` 重建，别名生效天然即时（重开菜单即见）。

**D8: 行几何与统一行宽。**
高度 24pt；行内按钮三个（Finder 打开 `folder`、复制 `doc.on.doc`、终端 `terminal`，各 20pt，父目录与子目录行皆有）；宽度按内容计算后，同一菜单内所有行经 `setCommonWidth` 统一为各行最大需求（下限 260pt，上限 400pt）——否则各行宽度随各自标题变化，按钮列无法纵向对齐（用户验收时提出）。夹取后；标题 `NSTextField`（`lineBreakMode = .byTruncatingTail`，`cell.truncatesLastLine = true`）替代 `ellipsizedMenuTitle()` 的 30 字符截断（视图内自然截断更平滑）。整行 tooltip 显示完整路径。

## Risks / Trade-offs

- [custom view 行与菜单跟踪的边缘行为（点击不落、子菜单不开、菜单不关）] → 验收场景逐项覆盖：pin 行点击/按钮、子目录行悬停子菜单、按钮后菜单关闭；异常则回退点明确（D1 hit-test 或 D2 分派）。
- [44 行 × 每次 `menuNeedsUpdate` 全量重建视图的内存/CPU] → 行视图轻量（两 image view + 一 text field），250 行上限内可接受；别名快照 D5 已消掉解码放大。
- [Swift 6：闭包跨 @MainActor 对象] → 所有组件 @MainActor，闭包无跨隔离捕获。
- [高亮态残留（菜单关闭时 tracking area 未清）] → 高亮仅影响绘制，行视图随菜单释放；无状态外泄。
- [真实 NSButton 的可达性/键盘操作缺失] → Non-Goal（与仓库现状一致——菜单本就以鼠标为主）。

## Migration Plan

纯 UI 呈现层重构 + 增量，无数据迁移。别名持久化格式不变（同一 `InstancePrefs` 键空间）。回滚 = revert 单个 commit；回滚后回到整行菜单项呈现，操作功能仍在。
