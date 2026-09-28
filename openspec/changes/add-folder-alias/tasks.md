## 1. 数据层

- [x] 1.1 `Prefs.swift`：`DisplayOptions` 新增 `var alias: String?`，`swift build` 通过且不写自定义 Codable init（依赖合成 decodeIfPresent，见 design D2）
- [x] 1.2 手动验证旧数据兼容：先用旧版本（当前 HEAD）运行并改动某文件夹排序，再切到新构建运行，确认该文件夹排序设置未丢、别名视为未设置（specs「旧数据无损升级」场景）

## 2. 展示替换与刷新

- [x] 2.1 实现 `iconLetters(for:)` 宽/窄字符取字 helper（首 scalar > 0x2E80 取 1 字，否则取 2 字），`FolderPin.swift:30` 的 init 图标字母改用「显示名 + helper」，全局生效；运行确认名为「项目」的无别名文件夹图标显示「项」（specs「宽字符名文件夹的图标取字顺带修复」场景）
- [x] 2.2 `FolderPin` 展示点全部切换为 `alias ?? displayName`：按钮 tooltip（`FolderPin.swift:31`）、菜单标题（`:68`）、菜单项 tooltip（`:73`）
- [x] 2.3 新增 `refreshChrome()`（重设 button.image 与 toolTip），运行 app 设别名后肉眼确认图标字母与 tooltip 立即变化、无需重启（specs「设定别名后图标立即刷新」场景）
- [x] 2.4 重启 app 确认别名仍在（specs「重启后别名保留」场景），并确认从未设置别名的文件夹名称类展示（tooltip、菜单标题）与改动前完全一致

## 3. 别名编辑窗口

- [x] 3.1 新建 `FolderAliasWindow.swift`：轻量 NSPanel + NSTextField + 确认/取消，纯 AppKit 控件（仅弹出与焦点处理参考 `BrowserBookmarksWindow.swift:105-127` 的 activate + makeKeyAndOrderFront 模式，不抄其 SwiftUI hosting）；确认/取消经 target-action 直连 `FolderPin` 的 `@objc` 方法（design D6，注意 weak target 语义）
- [x] 3.2 `displaySectionItems()`（`FolderPin.swift:89`）追加「Rename…」菜单项触发窗口；每次 show 时以 `options.alias ?? ""` 预填文本框；确认后走 `options.alias = trimmed（空→nil）` → `persistOptions()` → `refreshChrome()`（design D3/D6）
- [ ] 3.3 验证输入「代码库」→ 图标显示「代」、菜单显示「代码库」；再开窗口确认预填「代码库」；改文本后点「取消」确认别名不变（specs「取消编辑不改变别名」场景）；输入空串/空格确认 → 别名清除回落原名（specs「清空输入清除别名」场景）

## 4. 收尾

- [ ] 4.1 `swift build -c release` 通过，逐一验证 spec 全部场景（设置别名后各展示点更新 / 无别名名称展示不变 / 宽字符图标顺带修复 / 即时刷新 / 重启保留 / 旧数据无损升级 / 超长别名截断 / 预填当前别名 / 取消不变 / 清空清除 / CJK 取单字 / 拉丁取两字母），提交 `feat(alias): per-folder display alias for pinned folders`（Conventional Commits，尾部 `Co-Authored-By: Claude Code <noreply@anthropic.com>`）
