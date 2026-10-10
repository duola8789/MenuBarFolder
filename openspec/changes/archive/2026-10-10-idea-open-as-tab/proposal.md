# idea-open-as-tab

## Why

从 PinFold（以及 Finder / `open -a`）用 IDEA 打开项目时，即使 IDEA 已在运行、窗口 tab 组就绪，也会弹出一个独立窗口；老板常用项目还常以全屏独立桌面（Space）出现，永远无法挂进现有窗口的 tab 栏。根源是 macOS Apple event「open documents」路径在 IDEA 内部硬编码 `forceOpenInNewFrame=true`，触发项目记忆的 `fullScreen` 状态恢复，而全屏窗口独占 Space、物理上无法并入 tab 组。IDEA 自带的命令行路径（二进制 + 目录参数，经 DirectoryLock 转发到运行实例）没有这个标志，打开即窗口态、自动并入现有 tab 组。改动只需让 PinFold 改走这条命令行路径。

## What Changes

- `QuickActions.openInIDEA(_:)` 从 `NSWorkspace.open`（Apple event）改为直接执行 IDEA bundle 内的二进制（`Contents/MacOS/<CFBundleExecutable>`，即 Toolbox `idea` 脚本的等效内联实现），并把目标目录作为唯一参数传入。
- IDEA 未运行时行为不变：冷启动 IDE 并直接打开该项目（无欢迎页）。
- 找得到 bundle 但二进制执行失败时，SHALL 回退到现有 `NSWorkspace.open` 方式，保证打开永不因本改动而失效。
- IDEA 未安装时行为不变：播放系统提示音，不启动任何应用。
- 用户可见效果：IDEA 已运行时，PinFold 打开的项目以 tab 形式挂进现有 IDEA 窗口的 tab 栏（前提：该窗口为窗口态；宿主窗口全屏时 macOS 不会把新窗口挂进全屏窗口，此为系统能力边界，不做处理）。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `inline-row-actions`: 「行内快捷操作呈现」需求中 IDEA 打开按钮的语义扩充——由「用已安装的 IDEA 打开该文件夹」细化为「以命令行路径（二进制 + 参数）打开；IDEA 运行中且存在窗口态宿主窗口时项目作为 tab 并入现有窗口，否则与现状一致（新窗/冷启动）」。

## Impact

- 代码：`Sources/MenuBarFolder/QuickActions.swift`（`openInIDEA` 及新增的执行/回退辅助逻辑）；`ActionRowView.swift` 调用方接口不变。
- 依赖：无新增第三方依赖；`Process` / `Bundle` 读取均系统 API。
- 兼容性：对未装 IDEA、IDEA 冷启动、多版本 bundle id（`com.jetbrains.intellij` / `.ce`）三条路径逐一保留现状语义。
- 环境前提（非本变更可控）：IDEA 侧 `Settings → Open project in` 保持默认「New window」（值 0），命令行路径将遵循该设置静默开新窗并入组；若用户日后改成 Ask 会弹「Open Project」对话框。
