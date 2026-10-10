## MODIFIED Requirements

### Requirement: 行内快捷操作呈现

固定文件夹 pin 菜单的标题行 SHALL 以单行呈现：文件夹图标、显示名（超长截断），以及右侧四个行内图标按钮（Finder 打开、复制路径、启动 claude、IDEA 打开）。标题区点击 SHALL 打开 Finder（保留原主操作语义）；四个按钮点击 SHALL 分别对该文件夹执行 Finder 打开、复制路径、iTerm 启动 claude 与 IDEA 打开；任一按钮执行后菜单 SHALL 自动关闭。同一菜单内的行 SHALL 使用统一行宽，使按钮列纵向对齐（名称左对齐、按钮组右对齐）。标题行 MUST NOT 再出现独立的整行快捷操作菜单项。

IDEA 按钮点击时 SHALL 以命令行方式（IDEA 可执行文件 + 目录参数，等效 JetBrains Toolbox 的 `idea <dir>` 启动）打开该文件夹，而非经由系统「打开文稿」通道：IDEA 已在运行且存在窗口态的项目窗口时，被打开的项目 SHALL 以 tab 形式并入该现有窗口的 tab 栏（不恢复项目记忆的全屏状态）；不存在可并入的宿主窗口时（IDEA 未运行、仅有全屏窗口等），SHALL 保持与现状一致的打开兜底——冷启动 IDEA 直接打开该项目，或按 IDEA 自然行为呈现。任何情况下该按钮 MUST 保证「项目最终在 IDEA 中被打开」，不因并入 tab 的尝试失败而失败。未安装任何 IntelliJ IDEA 时 SHALL 仅播放系统提示音，不启动其他应用。

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
- **WHEN** IDEA 已运行且有一个非全屏的项目窗口（tab 栏就绪），点击标题行的花括号按钮打开一个未打开的文件夹
- **THEN** 该文件夹作为项目以新 tab 出现在该现有窗口的 tab 栏中，无独立新窗口，菜单关闭

#### Scenario: 打开记忆为全屏的项目不再恢复全屏
- **WHEN** 某项目上次以全屏关闭（IDEA 记忆了全屏状态），IDEA 运行中存在窗口态宿主窗口，经 PinFold 打开该项目
- **THEN** 该项目以窗口态并入现有窗口 tab 栏，不创建独占桌面的全屏窗口

#### Scenario: IDEA 未运行时冷启动打开
- **WHEN** IDEA 未运行，点击花括号按钮
- **THEN** IDEA 被启动并直接打开该文件夹为项目（不出现欢迎页），菜单关闭

#### Scenario: 命令行打开失败时回退
- **WHEN** IDEA 已安装，但其可执行文件以命令行方式启动失败
- **THEN** 仍以系统打开方式（原行为）打开该文件夹，用户不感知失败

#### Scenario: IDEA 未安装时按钮降级
- **WHEN** 本机未安装任何 IntelliJ IDEA 且点击花括号按钮
- **THEN** 播放系统提示音，不启动任何应用，菜单关闭
