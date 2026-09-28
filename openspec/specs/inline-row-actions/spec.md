# inline-row-actions Specification

## Purpose
以单行 custom view 菜单行同时承载名称主操作与行内快捷操作（复制路径、启动 Claude Code），覆盖 pin 标题行与子目录行，并为子目录行提供别名展示与改名入口。

## Requirements

### Requirement: 行内快捷操作呈现

固定文件夹 pin 菜单的标题行 SHALL 以单行呈现：文件夹图标、显示名（超长截断），以及右侧四个行内图标按钮（Finder 打开、复制路径、启动 claude、IDEA 打开）。标题区点击 SHALL 打开 Finder（保留原主操作语义）；四个按钮点击 SHALL 分别对该文件夹执行 Finder 打开、复制路径、iTerm 启动 claude 与 IDEA 打开；任一按钮执行后菜单 SHALL 自动关闭。同一菜单内的行 SHALL 使用统一行宽，使按钮列纵向对齐（名称左对齐、按钮组右对齐）。标题行 MUST NOT 再出现独立的整行快捷操作菜单项。IDEA 按钮点击时 SHALL 使用已安装的 IntelliJ IDEA 打开该文件夹；未安装任何 IntelliJ IDEA 时 SHALL 仅播放系统提示音，不启动其他应用。

#### Scenario: 单行结构
- **WHEN** 打开任一文件夹 pin 的菜单
- **THEN** 标题行为单行：图标 + 名称 + 四个行内按钮，其后是分隔线与目录内容，无整行操作项

#### Scenario: 按钮列纵向对齐
- **WHEN** 菜单中存在多行（标题行与多个子目录行）
- **THEN** 所有行同宽，四个按钮在各行的相同横向位置上对齐成列

#### Scenario: 行内按钮复制路径
- **WHEN** 点击标题行的复制按钮
- **THEN** 剪贴板含该文件夹 POSIX 路径，菜单关闭

#### Scenario: 行内按钮启动 claude
- **WHEN** 点击标题行的终端按钮
- **THEN** iTerm2 新建窗口、cd 到该文件夹并启动 claude，菜单关闭

#### Scenario: 行内按钮打开 Finder
- **WHEN** 点击标题行或任一子目录行的 Finder 按钮
- **THEN** 该目录在 Finder 窗口中打开，菜单关闭

#### Scenario: 行内按钮打开 IDEA
- **WHEN** 点击标题行的花括号按钮且本机装有 IntelliJ IDEA
- **THEN** 该文件夹在 IDEA 中作为项目打开，菜单关闭

#### Scenario: IDEA 未安装时按钮降级
- **WHEN** 本机未安装任何 IntelliJ IDEA 且点击花括号按钮
- **THEN** 播放系统提示音，不启动任何应用，菜单关闭

### Requirement: 子目录行的操作与别名

pin 菜单中的子目录行 SHALL 同样以单行呈现（图标 + 显示名 + 四个行内按钮），显示名优先取该子目录路径已设置的别名；行内按钮以该子目录路径执行 Finder 打开、复制、claude 与 IDEA 打开操作；子目录行悬停 SHALL 照常展开其内容子菜单。

#### Scenario: 子目录行复制路径
- **WHEN** pin `~/projects` 后在下拉中点击某子目录行的复制按钮
- **THEN** 剪贴板含该子目录的 POSIX 路径

#### Scenario: 子目录行打开 IDEA
- **WHEN** pin `~/projects` 后点击某子目录行的花括号按钮
- **THEN** 该子目录在 IDEA 中打开，菜单关闭

#### Scenario: 子目录行显示别名
- **WHEN** 某子目录经 Rename… 设置别名后重新打开菜单
- **THEN** 该子目录行显示别名而非目录名

#### Scenario: 子目录悬停子菜单不受影响
- **WHEN** 悬停任一子目录行
- **THEN** 该子目录的内容照常以子菜单展开

### Requirement: 子目录改名入口

每个子目录行的悬停子菜单顶部 SHALL 提供「Rename…」项，点击后弹出别名编辑窗口（预填当前别名，空白确认清除、取消不变，语义与 pin 级 Rename… 一致）。别名按子目录路径持久化。

#### Scenario: 为子目录设定别名
- **WHEN** 用户悬停 `chinasource-server` 行，在其子菜单点 Rename…，输入「中台服务」并确认
- **THEN** 重开菜单后该行显示「中台服务」，真实目录名不变

#### Scenario: 清除子目录别名
- **WHEN** 用户在该子菜单的 Rename… 窗口中清空输入并确认
- **THEN** 该行回落显示真实目录名

### Requirement: 大目录全量展示

pin 一个含大量子目录的文件夹（如 44 个子目录的 `~/projects`）时，菜单 SHALL 全量列出（现行 `maxItems=250` 上限内），每行的别名读取 SHALL 在单次菜单构建内一次性完成，不随行数线性放大持久化解码次数。

#### Scenario: 44 个子目录全量列出
- **WHEN** pin `~/projects` 并打开菜单
- **THEN** 44 个子目录各占一行（含行内按钮），无「+N more」截断
