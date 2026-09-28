## 1. 实现

- [x] 1.1 `FolderPin.layout()`：在标题项与分隔线之间插入「Copy Path」「Open with Claude Code (iTerm2)」两个菜单项（`indentationLevel = 1`，target = self），实现 `@objc copyPath()`（`BookmarksPin.swift:214` 模式：clearContents + setString 路径），`swift build` 通过
- [x] 1.2 实现双层转义 helper（shell 单引号包裹 + AppleScript 字符串转义）与 `@objc openWithClaude()`：iTerm2 存在性预检（bundle id `com.googlecode.iterm2`）→ 缺失 beep；存在则 `Process` 执行 `/usr/bin/osascript -e` 两步式脚本（`create window with default profile` + 对 current session `write text "cd '<path>' && claude"`，design D1/D2/D3；D1 的两步式已在本机端到端验证，AppleScript 层复用该验证结论）

## 2. 验证（需可用的构建环境）

- [x] 2.1 普通路径：pin 一个无空格目录，Copy Path 后在文本框粘贴，逐字符比对路径（specs「复制后粘贴得到路径」场景）
- [x] 2.2 含空格/特殊字符路径：pin `/tmp/it's a "test" 目录` 之类目录，Copy Path 粘贴比对；Open with Claude Code 确认 iTerm2 正确 cd 并启动 claude（specs「路径含空格时不受损」「特殊字符路径仍正确 cd」场景）
- [x] 2.3 iTerm2 未运行时点击操作，确认先启动再开窗执行（specs「iTerm2 未运行时先启动」场景）——端到端验证结论见 QuickActions.openClaude 注释与 d9a1a6f 提交记录
- [x] 2.4 首次点击出现 macOS Automation 授权弹窗，允许后正常工作；菜单结构确认两项缩进位于标题后、内容前（specs「菜单结构」场景）——已随 0a1aad0 行内按钮重构落地
- [x] 2.5 `swift build -c release` 通过 + 全场景过，提交 `feat(actions): copy path and open-with-claude quick actions on folder pins`（Conventional Commits，尾部 `Co-Authored-By: Claude Code <noreply@anthropic.com>`）——对应提交 80fa8ea
