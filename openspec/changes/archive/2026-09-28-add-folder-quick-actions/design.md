## Context

见 proposal.md（动机）与 specs/folder-quick-actions/spec.md（行为契约）。代码事实：

- pin 菜单由 `FolderPin.layout()` 全量重建（`FolderPin.swift:60-85`），标题项之后现有一条分隔线，内容区在后——两个操作项插在标题与分隔线之间，`indentationLevel = 1` 表归属。
- 剪贴板先例：`BookmarksPin.swift:214-219`（`clearContents` + `setString`）。
- 仓库惯例：次级动作用 Option-alternate（`FolderMenu.swift:249` 的 Reveal in Finder、`BookmarksPin.swift:180` 的 Copy Link）。本变更不用 alternate——用户明确要求两个常驻可见的操作项（自用工具，发现性优先于菜单密度）。
- iTerm2 官方 AppleScript 支持 `create window with default profile command "<shell 命令>"`。

## Goals / Non-Goals

**Goals:**

- 两个操作端到端可用：菜单项 → action → 剪贴板/iTerm2。
- 路径含空格、单引号、双引号、反斜杠时行为正确（双层转义）。
- iTerm2 缺失时优雅降级（beep，不执行脚本）。

**Non-Goals:**

- 不给子文件夹悬停子菜单加这两个操作（后续增量）。
- 不提供终端 App 选择（写死 iTerm2；Terminal/Kitty 备选不在本变更）。
- 不处理 `claude` 不在 PATH 的情形（新 tab 中会显示 `command not found`，对用户可见且自解释）。
- 不新增持久化/设置项。

## Decisions

**D1: iTerm2 启动走 AppleScript 两步式（create window + write text）+ `Process` spawn-and-forget。**
~~初版设计用 `create window with default profile command "<shell 命令>"`~~——**实测（iTerm 3.6.11）该形式静默失败**：osascript 返回 `missing value`，不建窗口、不执行命令、无错误。已改为两步式：

```applescript
tell application "iTerm2"
    activate
    create window with default profile
    tell current session of current window
        write text "cd '<path>' && claude"
    end tell
end tell
```

两步式已在本机端到端验证通过（含空格+单引号+双引号路径 cd 正确、`claude` 可被找到）。附带收益：`write text` 打进的是**交互式 login shell**（读 `.zshrc`），`claude` 的 PATH 解析问题随之消解——`command` 参数形式走非交互 shell 才有此风险。经 `/usr/bin/osascript -e <source>` 执行，`Process` 启动后不等待（`try? task.run()`），不阻塞主线程。备选（`open -a iTerm` + 临时 `.command` 文件）仍被否：需写临时文件、无法保证执行顺序。

**D2: 双层转义，顺序为 shell 层 → AppleScript 层。**
最终 AppleScript 源里 `command "..."` 的字符串先经 shell 单引号包裹（`'` → `'\''`），再对结果做 AppleScript 字符串转义（`\` → `\\`、`"` → `\"`）。顺序不可颠倒：AppleScript 解码后 shell 收到的才是正确的单引号包裹串。两个 helper 均为纯函数，配转义场景验证。

**D3: iTerm2 存在性预检，缺失时 `NSSound.beep()`。**
`NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2")` 为 nil 时不跑 osascript（否则静默失败、零反馈），播放系统提示音。不弹窗/不跳下载页——自用工具的最小反馈。

**D4: 菜单项为常驻可见项（非 Option-alternate），带 SF Symbol 模板图标。**
与仓库现有 alternate 惯例不同，理由见 Context 第三条。`indentationLevel = 1` 缩进以视觉归属到标题项，不加额外分隔线（标题后已有分隔线隔开内容区）。每项配 15×15 模板 SF Symbol（与 BookmarksPin 图标同规格）：Copy Path 用 `doc.on.doc`，Open with Claude Code 用 `terminal`——用户在验收时提出补图标，属 UI 完善非行为变更。

**D5: `claude` 命令直接拼在 `cd` 之后（`cd '<path>' && claude`）。**
`write text` 把命令敲进 iTerm 的**交互式 login shell**，`claude` 由用户 shell 配置（`.zshrc`）的 PATH 解析——本机已实测 `~/.local/bin/claude` 可见。cd 失败（目录被删）时 `&&` 短路，命令行留在错误信息处，自解释。

## Risks / Trade-offs

- [AppleScript 引擎调用触发首次权限弹窗（Automation: 控制 iTerm2）] → macOS 标准行为，用户授权一次后记住；不做绕行。实测本机 osascript 对 iTerm 的事件已可发送（`get version` 等查询成功）。
- [create window 与 write text 之间的会话就绪竞态] → 实测单脚本内连写即成功（iTerm 脚本接口同步建会话）；若冷启动 iTerm 后偶发失效，症状为命令未敲入，验收阶段确认「未运行时先启动」场景。
- [iTerm2 大版本 AppleScript 字典变更] → 3.6.11 上 `command` 参数已不可用（见 D1），两步式为当前可靠形式；若未来再变，症状为 write text 无效，人工验收可发现。
- [多用户环境的 `claude` 不在 PATH] → 已实证本机无此问题（write text 走交互 shell，`~/.local/bin/claude` 可见）；换机器/新用户时复验。
- [Swift 6：`Process` 与 `NSWorkspace` 在 `@MainActor` action 中使用] → 均为主线程安全 API；`task.run()` 仅 spawn 不等待，无隔离冲突。

## Migration Plan

无数据、无设置变更，纯增量。回滚 = revert commit。
