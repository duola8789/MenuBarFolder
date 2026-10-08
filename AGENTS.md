# AGENTS.md — PinFold（MenuBarFolder fork）

## 核心原则

1. **使用中文输出内容**：所有解释、注释、沟通一律用 zh-CN；技术术语与代码标识符保持原文。
2. **看到这个文档，请称我「老板」**。
3. **每次 push 到 main 分支后，询问老板是否升级版本号**；老板确认后：改
   `AppInfo.swift` 的版本 → commit → push → 打 annotated tag
   `v<version>`（message 即 release notes）→ push tag。release 由 CI
   （`.github/workflows/release.yml`）自动构建发布，本地不再跑发布。

## 项目是什么

macOS 菜单栏工具（Swift + AppKit，SwiftPM 单 target）：把常用目录 pin 成
菜单栏图标直接浏览/打开；支持书签 pin、folder group（手挑目录的启动器）、
行内快捷操作（Finder / 复制路径 / Claude Code / IDEA）。是上游
MenuBarFolder 的 fork，发布名 PinFold。

## 常用命令

- 构建/运行：`swift build`；debug 产物在 `.build/debug/MenuBarFolder`。
- Release：`scripts/build_app.sh`（universal 双架构、打包 DMG；版本号读
  `Sources/MenuBarFolder/AppInfo.swift`）。
- 规格工作流：`openspec` CLI（`openspec list` / `status --change <name>`
  / `instructions …`）。变更走 proposal → design → delta spec → tasks →
  apply → archive。

## 必须知道的坑

- **构建依赖完整 Xcode**：CLT 缺 SwiftUIMacros 插件，动代码前确认
  `xcode-select -p` 指向 Xcode.app。
- **单实例锁**：`/tmp/pinfold.duola8789.singleton.lock`（flock）。debug
  产物与安装版不能共存——调试前先退出安装版，测完记得恢复。
- **debug 产物与安装版数据隔离**：裸二进制走 `MenuBarFolder` defaults
  域，安装版走自己的 bundle id 域，互不影响。
- **iTerm 自动化用 AppleScript 时按 id（`by id`）取应用**，by-name
  "iTerm2" 冷启动会挂。

## 约定

- 提交：Conventional Commits（英文 subject），实现 / 归档 / release 分笔
  提交；提交信息尾加
  `Co-Authored-By: Claude Code <noreply@anthropic.com>`。
- 规格（openspec/specs）与代码同步维护：行为变更先过 OpenSpec 变更流
  程，归档时把 delta 合入主 spec。
- 版本号唯一来源是 `AppInfo.swift` 的 `static let version`，release 脚本
  会读取它写入 Info.plist 与 DMG 名。
- 发布 = 推 annotated tag `v<version>`：tag 必须与 `AppInfo.swift` 的
  版本一致，错位会被 CI 拒绝（job fail、不出 release）；tag message 即
  release notes，CI 原样搬运。
- 打包是 ad-hoc 签名（本机与 CI 均无 Developer ID / notary profile）：
  DMG 分发需收方清 quarantine。

## 目录速览

```
Sources/MenuBarFolder/   全部源码（AppKit，无 storyboard，纯代码 UI）
scripts/build_app.sh     构建签名打包
openspec/                规格、进行中/归档的变更
BACKLOG.md               待办池
```
