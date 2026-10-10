# Tasks: idea-open-as-tab

## 1. 实现命令行打开通道

- [x] 1.1 在 `QuickActions.swift` 的 `openInIDEA(_:)` 中：bundle id 解析成功后，从 `appURL` 读取 `Contents/Info.plist` 的 `CFBundleExecutable`，拼出 `<appURL>/Contents/MacOS/<executable>`；用 `Process` 以 `[url.path]` 为参数执行该二进制（不 wait、不设 terminationHandler）。验证：`swift build` 通过，IDEA 运行中（窗口态宿主）时 debug 产物里点击 IDEA 按钮，项目以新 tab 并入现有窗口 tab 栏
- [x] 1.2 为 1.1 加回退：`Process.run` 抛错时回落现有 `NSWorkspace.open` 通道；两者都不可用（无 bundle）维持现状的 `NSSound.beep()`。验证：临时把 executable 路径改错再点按钮，项目仍能以独立窗口方式打开（回退生效），恢复路径后回归 1.1 行为
- [x] 1.3 保持 IDEA 未安装分支不变（bundle id 均解析失败 → beep）。验证：阅读 diff 确认该分支未动
- [x] 1.4 spawn 前激活运行中的 IDEA 实例（AppKit 仅在前台时自动并组，实测 2026-10-09）：用 `NSRunningApplication.runningApplications(withBundleIdentifier:)` 取运行实例并 `activate()`（macOS 14+ async / 13 `activate(options:)`），未运行时跳过。验证：IDEA 后台时以裸二进制+先激活方式打开 `waimao-trial` 实测进 tab 栏

## 2. 端到端验收

- [x] 2.1 冷启动验证：退出 IDEA，用 PinFold 打开一个项目，确认 IDEA 启动并直接打开该项目（无欢迎页）。再保持 IDEA 运行，用 PinFold 打开第二个项目，确认并入 tab 栏
- [x] 2.2 全屏记忆项目验证：选一个 `recentProjects.xml` 里 `fullScreen="true"` 的项目（IDEA 运行中、有窗口态宿主），用 PinFold 打开，确认它以窗口态并入 tab 栏而非独立全屏 Space
- [x] 2.3 特殊字符路径验证：pin 一个路径含空格的目录并用 IDEA 按钮打开，确认项目正确打开（`Process` arguments 数组传递不经 shell，应天然无转义问题）
- [x] 2.4 构建与既有行为回归：`swift build` 无警告；Finder / 复制路径 / Claude Code 三个行内操作行为不变
