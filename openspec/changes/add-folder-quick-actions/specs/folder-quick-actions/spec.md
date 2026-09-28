## Purpose

为固定在菜单栏的文件夹提供一键快捷操作：复制其 POSIX 路径、以及在 iTerm2 中打开该目录并启动 Claude Code 会话。

## ADDED Requirements

### Requirement: Copy Path 操作

每个固定文件夹 pin 的下拉菜单中、标题正下方 SHALL 提供「Copy Path」菜单项。点击后系统剪贴板 SHALL 含该文件夹的 POSIX 路径字符串（先 clearContents 再写入，粘贴结果即路径本身）。该操作 MUST NOT 对文件夹本身产生任何副作用。

#### Scenario: 复制后粘贴得到路径
- **WHEN** 用户在 pin 菜单点击「Copy Path」，随后在任意文本框执行粘贴
- **THEN** 粘贴内容恰为该文件夹的 POSIX 路径（如 `/Users/admin/project`）

#### Scenario: 路径含空格时不受损
- **WHEN** 固定文件夹路径含空格（如 `/Users/admin/My Project`）
- **THEN** 剪贴板中的路径与磁盘路径逐字符一致

### Requirement: Open with Claude Code (iTerm2) 操作

每个固定文件夹 pin 的下拉菜单中、标题正下方 SHALL 提供「Open with Claude Code (iTerm2)」菜单项。点击后系统 SHALL 让 iTerm2 新建窗口（iTerm2 未运行时先启动它），在新窗口的 shell 中将工作目录切换到该文件夹并执行 `claude`。命令字符串 SHALL 对路径中的单引号、双引号、反斜杠做正确的双层转义（shell 层 + AppleScript 字符串层）。iTerm2 未安装时点击 MUST NOT 崩溃，用户得到可感知的提示（系统提示音），不执行任何 shell 命令。

#### Scenario: 打开后在新窗口中启动 claude
- **WHEN** 用户点击「Open with Claude Code (iTerm2)」
- **THEN** iTerm2 出现新窗口，shell 工作目录为该文件夹，`claude` 会话启动

#### Scenario: iTerm2 未运行时先启动
- **WHEN** iTerm2 当前未运行，用户点击该操作
- **THEN** iTerm2 被启动并新建窗口执行上述命令

#### Scenario: 特殊字符路径仍正确 cd
- **WHEN** 文件夹路径含单引号或空格（如 `/Users/admin/it's a test`）
- **THEN** iTerm2 中 shell 仍切换到正确目录，无转义错误

#### Scenario: iTerm2 未安装
- **WHEN** 机器上未安装 iTerm2
- **THEN** 点击该菜单项播放系统提示音，不执行 osascript，不崩溃

### Requirement: 操作项的位置与只读性

两个操作项 SHALL 出现在该 pin 菜单中文件夹标题项之后、目录内容列表之前，并缩进一级以示归属。两个操作 MUST NOT 修改文件夹名称、内容或任何磁盘状态（纯读路径）。

#### Scenario: 菜单结构
- **WHEN** 打开任一文件夹 pin 的菜单
- **THEN** 标题项之后紧跟缩进的「Copy Path」与「Open with Claude Code (iTerm2)」，其后是分隔线与目录内容
