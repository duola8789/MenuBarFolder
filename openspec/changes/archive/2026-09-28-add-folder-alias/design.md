## Context

见 proposal.md（动机）与 specs/folder-alias/spec.md（行为契约）。当前代码事实（勘察结论）：

- 每个 pin 的展示由 `FolderPin` 控制：图标字母/按钮 tooltip 在 `init` 设置一次（`FolderPin.swift:30-31`），菜单标题在每次 `menuNeedsUpdate` → `layout()` 重建（`FolderPin.swift:68`），因此菜单标题天然跟随数据、按钮 chrome 不会——后者是必须补的刷新路径。
- per-folder 持久化管线已存在：`DisplayOptions` 经 `InstancePrefs` 以 `[String: DisplayOptions]` 整字典存 UserDefaults（`Prefs.swift:64-92`），key 为 `instanceDisplay`。
- `StatusIcon.make(letters:)` 画布 22×18 pt，字母 11pt heavy 右下角（`StatusIcon.swift:16-54`，32-54 为文字与 notch 部分）。
- 项目已有独立 NSWindow 先例 `BrowserBookmarksWindow.swift` 可作窗口模式参考。
- 约束：macOS 13+，Swift 6 并发，零新依赖。

## Goals / Non-Goals

**Goals:**

- 别名端到端落地：存储 → 编辑 → 展示替换 → 即时刷新 → 重启保留。
- 旧持久化数据零丢失升级。
- 无别名路径的**名称类**展示（tooltip、菜单标题）与现状一致（回落 displayName）；图标取字的宽字符适配对所有文件夹全局生效，属于对存量溢出 bug 的有意修复（用户已拍板，见 specs 回归场景的改写）。

**Non-Goals:**

- 不改真实文件/目录名，不提供 Finder 同步改名。
- 不做 Settings.swift 里的集中别名管理（编辑入口只在 pin 自己的菜单小节里）。
- 不为 `FolderMenu` 的子文件夹内容项提供独立改名（`FolderMenu.swift:207/236` 维持现状）。
- 不做别名排重/校验（同名别名允许，仅展示层）。

## Decisions

**D1: 编辑入口 = pin 菜单显示设置小节中的「Rename…」菜单项 + 独立小窗口。**
备选一是 Settings.swift 集中列表编辑：交互路径更长，且需要一条「改名后通知 Settings 刷新列表」的额外通信。备选二是 `menuItem.view` 内联 NSTextField：菜单跟踪循环中 text field 拿不到键盘焦点（AppKit 已知限制），不可行。选菜单项 + 小窗口：与 Sort by / Folders on top 同节（`displaySectionItems()`，`FolderPin.swift:89`），语义一致（同属「这个文件夹自己的显示设置」），上下文内完成。窗口实现参考 `BrowserBookmarksWindow.swift` 的 NSWindow 模式，新建 `FolderAliasWindow.swift`（`NSPanel` 级别的轻量面板 + NSTextField + 确认/取消按钮）。

**D2: `alias: String?` 直接加入 `DisplayOptions`，不写自定义 `init(from:)`。**
Swift 合成 Codable 对 Optional 属性自动使用 `decodeIfPresent` / `encodeIfPresent`：旧 JSON（无 alias 字段）正常解码，alias 为 nil 时不出现在编码结果里。自定义 init 属于无害冗余，省掉以减小 diff。风险背景：`InstancePrefs.load` 用 `try?` 整字典解码，失败即整表回落默认值——正因如此才确认了 Optional 语义的兼容性是安全前提（已在 proposal Impact 记录）。

**D3: 刷新路径 = `FolderPin` 新增 `refreshChrome()`，由别名 setter 调用。**
现状 `persistOptions()`（`FolderPin.swift:124`）只做存盘 + 同步 contentDelegate + 清 listing，不触 statusItem 按钮。新增：

```
@objc setAlias 流程
   ├─ options.alias = 输入.trimmed（空 → nil）
   ├─ persistOptions()          // 复用：存盘 + 同步 delegate
   └─ refreshChrome()           // 新增：button.image = StatusIcon.make(letters: 显示名取字)
                                //       button.toolTip = "MenuBarFolder — 显示名"
```

菜单标题/菜单项 tooltip 不需处理——`layout()` 每次开菜单重跑。别名不影响目录内容与排序，`persistOptions()` 清 listing 对改名是多余的一次重读，可接受（复用现成方法优于拆变体）。

**D4: 图标字母取字启发式——首个字符为宽字符（CJK 等）取 1 个，否则取 2 个，全局应用于所有固定文件夹。**
判据 `displayingName.unicodeScalars.first.map { $0.value > 0x2E80 }`（覆盖 CJK 部首/表意/假名等区块）。两个 11pt CJK 字符约 22pt 宽，恰好占满 `StatusIcon` 22pt 画布并压住文件夹图形，故 CJK 必须取 1 字。作用域经评审后定为全局（而非仅别名路径）：无别名的中文名文件夹同样受益于溢出修复，specs 回归承诺相应改写为「名称展示不变」。提取为小工具函数（如 `iconLetters(for:)`）供 init 与 `refreshChrome()` 共用。

**D5: `Settings.swift:111` 的文件夹列表维持显示真实 `displayName`；`FolderPin.swift:73` 的菜单项 tooltip 替换为别名。**
设置窗口语义是「实际固定的路径」，菜单是「用户可见的展示名」，两者分工明确；且免去 Settings ↔ FolderPin 的刷新联动。`:73` 的 "Open … in Finder" tooltip 按原始需求一并替换为别名（展示一致性优先；评审建议过显示真名或「别名（真名）」作 UX 备选，未采纳，留待实现后实际体验再议）。

**D6: 窗口生命周期——每个 `FolderPin` 懒持有（可选属性）一个 `FolderAliasWindow`。**
`FolderPin` 是 `@MainActor`，Action 方法在其内实现，窗口确认/取消经 target-action 指向 pin 的 `@objc` 方法（NSControl 对 target 为 weak 引用，不会成环；若改用闭包回调则须 `[weak self]`），无跨 actor 问题。窗口关闭即隐藏（orderOut）而非销毁、实例复用，但**每次 show 时以 `options.alias ?? ""` 重置文本框**——编辑器语义是预填当前生效值，而非保留上次草稿。

## Risks / Trade-offs

- [小窗口与菜单的焦点竞争：菜单关闭时才弹窗，若时机处理不当窗口可能不获焦点] → 弹窗在 action 触发后经 `DispatchQueue.main.async` 或直接在 action 内 `makeKeyAndOrderFront` + `NSApp.activate(ignoringOtherApps: true)`，验证清单覆盖。
- [Swift 6 并发：NSPanel/NSTextField 回调若不慎脱离 MainActor] → 全部控件回调走 target-action 指向 `FolderPin` 的 `@objc` 方法（类本身 `@MainActor` 隔离），不引入 Task/Sendable 边界。
- [别名过长导致菜单标题溢出] → 已由现有 `ellipsizedMenuTitle()`（`FolderPin.swift:68` 在用）处理，无需新增逻辑。
- [宽字符判定不精确（如组合字符、emoji）] → 启发式按首个 scalar 判断即可；错误命中最坏效果是取 1 个字符，视觉可接受，不追求完善 Unicode 分类。
- [引用环：pin 持有窗口、窗口回调指向 pin] → target-action 下 NSControl 对 target 是 weak 持有（安全）；若用闭包则 `[weak self]`。避免 pin 被 `closePin` 移除后窗口与 pin 双双泄漏。

## Migration Plan

无部署迁移。数据兼容由 D2 的 Optional 解码语义保证（specs「旧数据无损升级」场景）。回滚：还原 commit 即可。若 UserDefaults 中残留 alias 字段，旧版本代码的合成解码会忽略未知键，不影响旧版本运行。
