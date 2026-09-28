## Why

固定到菜单栏的文件夹最常用的后续动作是「把路径发给别人/贴进终端」和「在该目录里起一个 Claude Code 会话」。现在这两个动作都要手动完成（Copy 菜单层级深；终端要开窗、cd、敲 `claude`），而菜单栏 pin 本来就是为高频访问而生——把动作收到 pin 自己的菜单里，一键直达。

## What Changes

- 每个固定文件夹 pin 的下拉菜单中、文件夹标题正下方新增两个操作项：
  - **Copy Path**：把该文件夹的 POSIX 路径写入系统剪贴板（写法沿用 `BookmarksPin.swift:214` 的 `copyBookmarkURL` 模式）。
  - **Open with Claude Code (iTerm2)**：通过 AppleScript（`/usr/bin/osascript`）让 iTerm2 新建窗口，在新 shell 中 `cd` 到该目录并启动 `claude`。
- 两个操作对真实文件夹零副作用（只读路径，不改名/不动内容）。
- 无新增持久化、无新增设置项。

## Capabilities

### New Capabilities

- `folder-quick-actions`: 固定文件夹 pin 菜单中的一键操作——复制 POSIX 路径到剪贴板、在 iTerm2 中打开目录并启动 Claude Code。

### Modified Capabilities

（无。）

## Impact

- **代码**：`Sources/MenuBarFolder/FolderPin.swift`（`layout()` 插入两个菜单项 + 两个 `@objc` action 方法 + AppleScript 转义 helper）。零新文件、零新依赖。
- **外部依赖**：运行时依赖用户机器上的 iTerm2（bundle id `com.googlecode.iterm2`）与 `claude` CLI 在登录 shell 的 PATH 中；两者缺失时的行为见 specs。
- **不改动**：`FolderMenu.buildItems`（子文件夹悬停子菜单暂不加这两个操作——上层文件夹先做通，后续可作为增量）。
- macOS 13+，Swift 6 并发（action 方法在 `@MainActor` 的 `FolderPin` 内；osascript 经 `Process` spawn-and-forget，不阻塞主线程）。
