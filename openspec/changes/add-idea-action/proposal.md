## Why

pin 的菜单行已有 Finder/复制路径/claude 三个行内按钮，但日常高频的「用 IDEA 打开该项目目录」仍需手动切应用再找目录。补第 4 个行内按钮，让 pinned 项目目录一键进 IDE，与现有三个高频动作同级。

## What Changes

- `ActionRowView` 增加第 4 个行内图标按钮（SF Symbol `curlybraces`），照现有 20pt 模式排在按钮组最左（内侧）一槽；行宽公式（`buttonWidth * 3` → `* 4`）、标题可宽计算、hover 转白数组、`mouseDown` hit-test 同步扩展。
- `QuickActions` 新增 `openInIDEA(_:)`：按 bundle id 依次探测 `com.jetbrains.intellij`（Ultimate）与 `com.jetbrains.intellij.ce`（Community），命中则以 `NSWorkspace.shared.open([url], withApplicationAt:configuration:)` 打开该目录；两者都未安装则 `NSSound.beep()` 并返回（照 `openClaude` 的 guard 模式）。
- `FolderPin.layout()` 标题行与 `FolderMenu.buildItems()` 子目录行都接线 `row.onIDEA`。
- 悬停子菜单暂不加 IDEA 文字版——那是后续「不展示子目录」change 的一部分，本次不做。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `inline-row-actions`: 「行内快捷操作呈现」与「子目录行的操作与别名」两条 requirement 中「三个行内按钮」扩展为四个——新增 IDEA 打开按钮（图标、位置、探测与打开语义、菜单自动关闭），按钮列纵向对齐的行数与槽位描述随之更新。

## Impact

- `Sources/MenuBarFolder/ActionRowView.swift`：新增 `ideaView`/`ideaFrame`/`onIDEA`，宽度与 hover、hit-test 扩展，头注释 three→four。
- `Sources/MenuBarFolder/QuickActions.swift`：新增 `openInIDEA(_:)`，头注释同步。
- `Sources/MenuBarFolder/FolderPin.swift`、`Sources/MenuBarFolder/FolderMenu.swift`：各加一行 `onIDEA` 接线。
- 无新依赖、无 Breaking Change；未装 IDEA 的机器上按钮仍在，点击 beep（与 claude 按钮对 iTerm2 缺失的行为一致）。
