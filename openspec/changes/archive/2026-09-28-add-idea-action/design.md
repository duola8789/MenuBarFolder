## Context

现状：`ActionRowView` 以单行承载三个 20pt 行内按钮（finder 最右，向左依次 copy、claude），行宽公式、hover 转白、`mouseDown` hit-test 均按三按钮硬编码；`QuickActions.openClaude` 已确立「bundle id 预检 + 缺失 beep」的应用探测模式；`BookmarksPin.openBookmark` 已确立 `NSWorkspace.shared.open([url], withApplicationAt:configuration:)` 的指定应用打开写法。本 change 完全复用这两条既有路径，无新依赖、无数据模型变化。

## Goals / Non-Goals

**Goals:**

- 第 4 个行内按钮（IDEA 打开）以与现有三按钮完全一致的 20pt 模式接入，标题行与子目录行共用。
- 未装 IDEA 的机器上行为与 claude 按钮对 iTerm2 缺失时一致：按钮保留，点击 beep 降级。

**Non-Goals:**

- 悬停子菜单的 IDEA 文字版（属后续「不展示子目录」change）。
- 其他 IDE（VS Code 等）支持、按钮顺序可配置化。

## Decisions

**D1 应用探测：bundle id 依次探测，Ultimate 优先。**
`NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` 依次试 `com.jetbrains.intellij`（Ultimate）→ `com.jetbrains.intellij.ce`（Community）。理由：LaunchServices 是 macOS 的权威注册表，Toolbox 安装（非 /Applications 固定路径）同样注册，天然免疫安装位置变动；两版并存时优先 Ultimate——付费主力版本是 CE 超集，开错方向的损失更大。备选：硬编码 `/Applications/IntelliJ IDEA.app` 路径（Toolbox 用户直接失效）或 Spotlight 查询（过度设计）。

> **实施期修正（2026-09-28）**：实测本机 IntelliJ IDEA CE 2026.2.3 的 bundle id 即为 `com.jetbrains.intellij`（`~/Applications/IntelliJ-CE.app`），`.ce` 为旧版惯例、现代构建已不再使用——「Ultimate 与 CE 分属两个 bundle id、可按 id 区分优先」的假设不成立。两种版本共用同一 bundle id 时，LaunchServices 决定命中哪个注册项，应用侧无法可靠强制 Ultimate 优先。探测顺序保持不变（本机行为正确：首 id 命中即打开已装的 IDEA），`.ce` 保留为旧版安装的兜底；spec 中「Ultimate 优先」的表述已随实施修正移除。

**D2 打开方式：`NSWorkspace.shared.open([url], withApplicationAt:configuration:)`。**
照抄 `BookmarksPin.openBookmark`，`OpenConfiguration` 用默认值。目录交给 IDEA 后按其自身语义作为 project 打开（首次可能弹 Trust Project 对话框，属 IDE 侧一次性交互，不阻塞）。备选：先 `openApp` 再 AppleScript 传 URL——两步式引入时序问题，无收益。

**D3 失败模式：beep + return，不隐藏按钮。**
照抄 `QuickActions.openClaude` 的 guard 模式。备选：未装时隐藏按钮——会导致行宽随机器环境漂移、`setCommonWidth` 对齐逻辑复杂化，且与 claude 按钮的既有行为不对称，弃用。

**D4 按钮槽位与图标：`curlybraces`，第 4 槽（按钮组最左/内侧）。**
finder/copy/claude 三槽不动，IDEA 追加为第 4 槽，改动最小且与「按钮组右对齐」的既有视觉一致。`curlybraces` 在 16pt 下笔画清晰、代码/IDE 语义最直观（与 `chevron.left.forwardslash.chevron.right` 对比，后者小尺寸下偏密）。同步扩展点：`init` 宽度公式尾部 `buttonWidth * 3 + 12` → `buttonWidth * 4 + 16`（frame 间距为每钮 4pt 的 `-4n` 模式，尾隙随按钮数同步 +4，保持公式与 frame 常量自洽）、`titleW` 上界改用 `ideaFrame.minX - 10`、hover 转白数组、`mouseDown` hit-test（idea 分支置于 claude 之后、onTitle 之前）、`ActionRowView` 文件头与 `init` 内 "three trailing buttons" 行内注释 three→four、`FolderPin`/`FolderMenu` 两处接线点的按钮枚举行内注释（`FolderPin.swift:81` 现存 "two inline buttons" 系历史陈旧，一并修正）。

## Risks / Trade-offs

- [IDEA 首次打开陌生目录弹 Trust Project 对话框] → IDE 侧一次性交互，用户点信任即后续免弹；菜单侧行为不受影响。
- [四个按钮占用行宽 +20pt，超长标题可显示区变窄] → 标题本有 300pt clamp 与截断兜底，实际影响为截断点略提前，可接受。
- [未来 bundle id 变动（JetBrains 更换签名体系）] → 与 iTerm2 bundle id 假设同等风险，届时随版本更新修正即可。
