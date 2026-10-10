# Design: idea-open-as-tab

## Context

见 proposal.md「Why」。当前 `QuickActions.openInIDEA` 用 `NSWorkspace.open([url], withApplicationAt:)` 走 macOS Apple event「open documents」通道。经 IDEA 2026.2.3 源码核查（`MacOSApplicationProvider.kt:118` → `ProjectUtil.openOrImportFilesAsync` 硬编码 `forceOpenInNewFrame=true` → `IdeProjectFrameAllocator.kt:330` 恢复 `recentProjects.xml` 记忆的 `fullScreen` 状态），全屏恢复的窗口独占 macOS Space，无法并入 tab 组。而命令行通道（新进程抢 `DirectoryLock` 失败 → argv 转发运行实例 → `CommandLineProcessor.doOpenFileOrProject`，无 force 标志 → 跳过全屏恢复 → JBR `JavaWindowTabbingIdentifier` 自动并组）打开即窗口态、自动进 tab 栏——已在本机实测验证（Apple event 打开窗口态项目同样能进 tab，全屏恢复才是分叉点）。

IDEA 侧环境前提：`Settings → Appearance & Behavior → System Settings → Open project in = New window`（`confirmOpenNewProject2=0`，老板机器已如此设置）。命令行通道遵循该设置：静默开新窗（窗口态）并入组，无弹窗。

## Goals / Non-Goals

Goals:
- PinFold 的 IDEA 打开在「IDEA 运行中且有窗口态宿主」场景下并入现有窗口 tab 栏。
- 打开永不因本改动失败（回退保证）。

Non-Goals:
- 不处理「宿主窗口全屏」场景（macOS 不把新窗口挂进全屏窗口，系统能力边界；用户退出全屏即可）。
- 不修改任何 IDEA 配置/记忆状态（不碰 `recentProjects.xml`）。
- 不覆盖 IDEA 冷启动时的全屏恢复语义（新 frame 分支 `allocator.kt:350` 无条件恢复，属 IDE「按上次样子恢复」的标准行为）。
- 不影响其他快捷操作（Finder / 复制 / claude）。

## Decisions

### D1: 直接 `Process` 执行 bundle 内二进制，而非 shell 出 `open -na` 或复用 Toolbox 脚本

- 选中：`Process`，executable = `<appURL>/Contents/MacOS/<CFBundleExecutable>`（本机即 `idea`），arguments = `[url.path]`。
- 备选 1：`/usr/bin/open -na <binary> --args <dir>`（Toolbox 脚本原样照抄）。否——多一层 shell + `open` 进程，且 `-n` 语义依赖 LaunchServices。
- 备选 2：PATH 里找 Toolbox 生成的 `idea` 脚本。否——脚本路径随 Toolbox 版本/用户配置漂移，`~/Library/Application Support/JetBrains/Toolbox/scripts` 未必在 PATH。
- 备选 3：改用 IDEA 内建 HTTP 接口激活。否——无打开项目的公开稳定端点。
- 二进制名从 `CFBundleExecutable` 动态读取而非硬编码 `idea`——未来 bundle 更名/多语言不破。

### D2: spawn 前先激活运行中的 IDEA 实例

实测发现（2026-10-09）：AppKit 只在目标应用前台（有 key window）时才把新窗口自动挂进 tab 组；转发路径里 IDEA 的 `focusApp=true` 发生在窗口创建之后，后台时新窗口必然独立。因此 `openInIDEA` 在 spawn 二进制前用 `NSRunningApplication.runningApplications(withBundleIdentifier:)` 找到运行实例并 `activate()`（macOS 14+ 用 async 版本，13 走 `activate(options:)`，避免弃用警告）。IDEA 未运行时跳过激活，冷启动路径不受影响。焦点切换是「打开项目」的预期 UX（旧 NSWorkspace 路径同样会激活），无回归。

### D3: 不等待子进程、不持有引用

新进程要么抢锁成功变成长期运行的 IDE（冷启动），要么转发参数后秒退。PinFold 只 `try p.run()`，不 `wait`、不设 terminationHandler，随用随弃。菜单栏 app 退出不拖累子进程。

### D4: 回退链

`Process.run` 抛错（二进制缺失、无执行权限等）→ 捕获并回落现有 `NSWorkspace.open` 通道。bundle 已经由 bundle id 解析成功才走到这步，所以回退几乎不会触发，但保证「打开永不失败」的规格语义。

### D5: 不感知 IDEA 侧设置

不在 PinFold 里探测/修改 `confirmOpenNewProject2`。用户若把 IDEA 设置改成 Ask，命令行通道会弹「Open Project」对话框——那是用户主动选择，PinFold 不越权。

## Risks / Trade-offs

- [IDEA 未运行时多付出一次进程启动开销：spawn 的进程就是 IDE 本体（抢锁成功），无额外开销；IDEA 运行中时多一个 1–3 秒退出的瞬时 JVM 引导进程] → 接受；与 Toolbox CLI 日常行为一致，无 Dock 常驻图标。
- [JetBrains 未来改动命令行通道语义（如 forceOpenInNewFrame 行为变化、二进制参数不兼容）] → 回退链保证「打开」本身不坏；tab 并组效果退化最多回到现状。
- [非 JetBrains JBR 的 IDEA 发行版（理论上）可能不支持此通道] → 回退链兜底；`Process` 启动失败即走 NSWorkspace。
- [多 IDEA 版本并存（CE + Ultimate）时，bundle id 解析取第一个，与现状一致] → 不变，非本变更引入。

## Migration Plan

单文件改动，无数据迁移。发布走既有 tag-driven release 流程。回滚 = revert 单个 commit。

## Open Questions

无。机制链已在本机双路径对照实测闭环；剩余验证（改后 PinFold 实测进 tab）在 tasks 的验收项里。
