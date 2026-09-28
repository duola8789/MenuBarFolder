## 1. 实现

- [x] 1.1 `QuickActions.swift` 新增 `static func openInIDEA(_ url: URL)`：按 D1 依次探测 bundle id `com.jetbrains.intellij` → `com.jetbrains.intellij.ce`，命中则按 D2 用 `NSWorkspace.shared.open([url], withApplicationAt:configuration:)` 打开，都缺失则 `NSSound.beep()` 返回（D3，照 `openClaude` 的 guard 模式）；同步更新文件头注释，`swift build -c release` 通过（构建失败先查 `xcode-select -p` 是否指向 /Applications/Xcode-27.0.0.app）
- [x] 1.2 `ActionRowView.swift` 加第 4 按钮：`onIDEA` 回调、`ideaView`、`ideaFrame`（D4：20pt 第 4 槽最左，`x = width - buttonWidth * 4 - 16`）、`init` 宽度公式尾部 `buttonWidth * 3 + 12` → `buttonWidth * 4 + 16`（尾隙随 `-4n` 间距模式同步 +4）、`layout()` 的 `titleW` 上界改用 `ideaFrame.minX - 10`、`init` 按钮数组加 `curlybraces`、hover 转白数组加 `ideaView`、`mouseDown` hit-test 在 claude 分支后加 idea 分支、文件头与 `init` 内 "three trailing buttons" 注释 three→four；`swift build -c release` 通过
- [x] 1.3 接线两处：`FolderPin.layout()` 标题行（`FolderPin.swift:89` 旁）与 `FolderMenu.buildItems()` 子目录行（`FolderMenu.swift:247` 旁）各加 `row.onIDEA = { QuickActions.openInIDEA(url) }`；同步更新两处接线点的按钮枚举行内注释（`FolderPin.swift:81` 现存 "two inline buttons" 系历史陈旧，一并修正）；`swift build -c release` 通过

## 2. 验证

- [x] 2.1 Quit 正在运行的 MenuBarFolder 实例（避免菜单栏图标叠加），运行 `.build/release/MenuBarFolder ~/projects`，打开 pin 菜单确认：标题行单行呈现四个按钮、四行按钮列纵向对齐（specs「单行结构」「按钮列纵向对齐」场景）
- [x] 2.2 点击标题行花括号按钮：`~/projects` 在 IntelliJ IDEA 中作为项目打开，菜单自动关闭；首次弹 Trust Project 则信任后续免弹（specs「行内按钮打开 IDEA」场景）
- [x] 2.3 点击某子目录行（如含别名行）的花括号按钮：该子目录在 IDEA 中打开；悬停子菜单仍正常展开；hover 行时四个按钮随标题转白（specs「子目录行打开 IDEA」「子目录悬停子菜单不受影响」场景）
- [x] 2.4 「IDEA 未安装降级」场景（specs `IDEA 未安装时按钮降级`）无法在本机实测（已装 IDEA），以代码审查确认：guard + beep 分支与 `openClaude`（`QuickActions.swift:32`）同构即视为通过
- [ ] 2.5 Conventional Commits 提交（如 `feat(actions): open-in-idea inline row action on folder pins`），尾部 `Co-Authored-By: Claude Code <noreply@anthropic.com>`
