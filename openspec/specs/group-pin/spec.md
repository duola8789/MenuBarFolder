## Purpose

一个状态栏图标承载多个手挑目录作为启动目标（group pin）：下拉即目标清单，
每行复用行内快捷操作行，不列任何目录内容；悬停行得到纯动作面板。

## Requirements

### Requirement: Group 的创建与命名

系统 SHALL 在各 pin 的「MenuBarFolder ▸」应用子菜单与空态 setup 菜单提供
「New Folder Group…」入口。创建时用户 SHALL 可为 group 输入名字，名字是否
必填取决于是否已有默认 group 存在：

- 输入非空白名字时，系统 SHALL 按该名字创建普通 group：创建成功后在菜单
  栏新增一个该 group 专属的状态栏图标，图标字母取自 group 名（窄字符开头取
  2 字符、宽字符（如 CJK）开头取 1 字符，与既有图标取字规则一致），按钮
  tooltip SHALL 显示该 group 名。
- 名字留空（或仅空白字符）且当前不存在默认 group 时，系统 SHALL 直接创建
  一个默认 group：内部名 SHALL 为「default」，状态栏图标 SHALL 使用应用图
  标（与空态 setup 菜单图标同源同规格，不取字母），tooltip、下拉 header 与
  设置窗口中的显示名 SHALL 均为「default」。默认 group 全局至多一个。
- 名字留空且默认 group 已存在时，系统 SHALL 弹出告警窗提示已存在默认
  group，SHALL NOT 创建任何 group，命名窗口 SHALL 保持打开（用户可补填名
  字或取消）。

普通 group 名此后 SHALL 可经该 group 显示小节的「Rename…」修改，修改后图
标字母与 tooltip 立即更新；空白或仅空白字符的确认 SHALL 不改变 group 名
（保持原名——区别于文件夹别名的空白清除语义）。默认 group 同样可经
「Rename…」改为非空名字：改名后 SHALL 成为普通 group（图标改按新名字取字
母），默认 group 槽位 SHALL 随之释放——此后名字留空的创建 SHALL 再次直接
创建新的默认 group；默认 group 的空白确认 SHALL 保持其为默认 group。多个
group 可并存，各占一个状态栏图标；手动命名的 group（包括名字恰好为
「default」者）SHALL 为普通 group，不占用默认 group 槽位；本能力不引入组
名唯一性约束。

#### Scenario: 从应用子菜单创建 group

- **WHEN** 用户在任一 pin 菜单的「MenuBarFolder ▸」子菜单点击「New Folder
  Group…」，输入名字「dev」并确认
- **THEN** 菜单栏新增一个图标字母为「de」的 group pin，其下拉为空成员提示

#### Scenario: 留空创建默认 group

- **WHEN** 当前不存在默认 group，用户在命名窗口不输入名字直接确认
- **THEN** 菜单栏新增一个应用图标的 group 图标（与空态 setup 菜单所用相
  同），tooltip 为「PinFold — default」，下拉 header 显示「default」

#### Scenario: 名字为空不创建

- **WHEN** 默认 group 已存在，用户在命名窗口不输入名字直接确认
- **THEN** 弹出告警窗提示已存在默认 group，确认告警后命名窗口仍打开且未
  创建任何 group；用户随后输入「work」并确认则正常创建普通 group

#### Scenario: 默认 group 的图标与显示名

- **WHEN** 默认 group 存在，用户查看其状态栏图标、下拉与设置窗口
- **THEN** 图标为应用图标（与空态 setup 菜单所用相同），下拉 header 与设置
  窗口显示名均为「default」

#### Scenario: 中文名取单字

- **WHEN** 用户创建名为「开发」的 group
- **THEN** 该 group 的状态栏图标字母显示「开」

#### Scenario: 改名即时生效

- **WHEN** 用户在 group 显示小节点「Rename…」，把「dev」改为「work」并确认
- **THEN** 状态栏图标字母变为「wo」，tooltip 同步更新，无需重启

#### Scenario: 改名空白输入不生效

- **WHEN** 用户在 group 的 Rename… 窗口清空输入（或仅输入空白字符）并确认
- **THEN** group 名保持原值，图标字母与 tooltip 不变

#### Scenario: 默认 group 改名释放默认槽

- **WHEN** 用户把默认 group 经「Rename…」改名为「work」并确认
- **THEN** 该 group 图标变为字母「wo」，成为普通 group；此后用户在命名窗口
  留空确认 SHALL 直接创建一个新的默认 group

#### Scenario: 从空态 setup 菜单创建 group

- **WHEN** 无任何 pin 时用户在空态 setup 菜单点「New Folder Group…」，输入
  名字并确认
- **THEN** setup 图标消失，菜单栏出现该 group 的图标

### Requirement: 成员行呈现（无目录内容）

group pin 的下拉顶部 SHALL 显示该 group 完整名称的 header 行（不可点击，
超长名称按既有标题截断逻辑省略号化，tooltip 含全名）。下拉 SHALL 为每个成
员目录呈现一行：目录图标、显示名（超长截
断）、四个行内按钮（Finder 打开、复制路径、启动 claude、IDEA 打开），标题
区点击 SHALL 在 Finder 中打开该目录；行标题 SHALL 优先显示该目录路径已设
置的别名，无别名时回落目录显示名。下拉内 SHALL NOT 列出任何成员目录的子目
录或文件内容；同一菜单内各行 SHALL 使用统一行宽使按钮列对齐。成员为空时
SHALL 显示禁用的「(no folders yet)」提示行。行内容的左右边距 SHALL 与同
一菜单内标准菜单项的内缩视觉一致（不贴边）。

#### Scenario: 下拉顶部显示组名

- **WHEN** group 名超过菜单标题截断长度（如「dev-projects-2026-fork」），
  用户点开下拉
- **THEN** 顶部 header 行显示该名称（超长截断），tooltip 含完整名称

#### Scenario: 下拉即目标清单

- **WHEN** group 含成员 `p1`、`p2`，用户点开该 group 的下拉
- **THEN** 菜单为 MenuBarFolder ▸、分隔线、`p1` 行、`p2` 行，无任何子目录
  listing

#### Scenario: 成员行别名优先

- **WHEN** 成员 `chinasource-server` 已设置别名「中台服务」
- **THEN** 该行显示「中台服务」，行内按钮对 `chinasource-server` 路径执行

#### Scenario: 标题点击开 Finder

- **WHEN** 用户点击某成员行的标题区
- **THEN** 该成员目录在 Finder 窗口中打开，菜单关闭

#### Scenario: 空 group 提示

- **WHEN** group 无任何成员
- **THEN** 下拉显示禁用的「(no folders yet)」提示行

### Requirement: 成员行悬停动作面板

每个成员行悬停 SHALL 展开纯动作面板（ submenu ），面板内依次 SHALL 包含：
「Rename…」（对该成员路径设置别名，预填当前别名、空白确认清除、取消不变，
语义与既有子目录 Rename… 一致）；当该成员路径存在已设置别名时，Rename…
之后 SHALL 另含「Restore Original Name」（点击清除该路径别名，行标题回落
目录原始显示名——与空白确认清除同一语义的显式入口）；分隔线、文字版「Open
in Finder」「Copy Path」「Open with Claude Code (iTerm2)」「Open in IDEA」、
分隔线、「Move Up」「Move Down」（成员顺序手动调整；首个成员 SHALL 不显示
Move Up，末个成员 SHALL 不显示 Move Down）、「Remove from Group」。面板内
MUST NOT 出现该目录的内容 listing。文字版动作 SHALL 与
行内按钮执行完全相同的操作并使用相同的降级行为（如未装 IDEA 时播放提示音）。
「Remove from Group」点击后 SHALL 将该成员从 group 移除，菜单关闭，下次打
开下拉该行消失。手动调整顺序与恢复原名后，下次打开下拉 SHALL 反映最新状
态。

#### Scenario: 悬停展开动作面板

- **WHEN** 用户悬停成员 `p1` 行
- **THEN** 面板显示 Rename…、四个文字动作、Move Up/Move Down（按位置省
  略越界项）与 Remove from Group，无文件 listing

#### Scenario: 面板内文字动作执行

- **WHEN** 用户在面板点击「Open with Claude Code (iTerm2)」
- **THEN** iTerm2 新建窗口、cd 到 `p1` 并启动 claude，菜单关闭（与行内按钮
  行为一致）

#### Scenario: 手动上移成员

- **WHEN** group 成员顺序为 `p1`、`p2`、`p3`，用户在 `p3` 行面板点击
  「Move Up」
- **THEN** 菜单关闭，重开下拉时顺序变为 `p1`、`p3`、`p2`

#### Scenario: 恢复成员原始名称

- **WHEN** 成员 `p1` 已设别名「主项目」，用户在其面板点击「Restore Original
  Name」
- **THEN** 菜单关闭，重开下拉时该行显示目录原始名称；未设别名的成员面板
  不显示该项

#### Scenario: 面板内为成员改名

- **WHEN** 用户在 `p1` 行面板点「Rename…」，输入「主项目」并确认
- **THEN** 重开下拉后该行显示「主项目」，真实目录名不变

#### Scenario: 从面板移除成员

- **WHEN** 用户在 `p2` 行面板点击「Remove from Group」
- **THEN** 菜单关闭，重开下拉时 `p2` 行消失，`p1` 行保持

### Requirement: 成员增删与去重

group 的「MenuBarFolder ▸」应用子菜单 SHALL 提供「Add Folder to Group…」，
点击后 SHALL 弹出目录选择器；选定的目录 SHALL 以该 group 成员的身份加入，
并追加在现有成员之后。成员顺序初始为添加顺序，此后 SHALL 仅经悬停面板的
「Move Up / Move Down」手动调整（不按名称自动排序——group 是手挑清单，
顺序表达使用频率而非字典序）。同一目录路径 SHALL NOT
在同一 group 中出现两次——再次添加已存在的成员 SHALL 被忽略（无重复行）。
成员移除 SHALL 以成员在 group 记录中的位置为身份（而非按路径——bookmark
彻底无法解析的成员没有可用的路径身份），对可解析与不可解析成员同样有效。

#### Scenario: 添加成员追加在末尾

- **WHEN** group 已有 `p1`，用户经「Add Folder to Group…」选择 `p2`
- **THEN** 下拉出现 `p2` 行，位于 `p1` 行之后

#### Scenario: 重复添加被忽略

- **WHEN** group 已含 `p1`，用户再次选择 `p1` 所在目录添加
- **THEN** 下拉仍只有一个 `p1` 行

### Requirement: 持久化与重启恢复

group（名字、默认 group 身份与成员列表）SHALL 按能跨重启恢复的方式持久
化；应用重启后各 group 的状态栏图标、名字与成员顺序 SHALL 保持一致，默认
group 的应用图标与默认槽占用状态 SHALL 同样恢复。旧版本持久化的 group
数据（无默认 group 身份字段）SHALL 正常解码为普通 group。经「Close This
Menu Instance」关闭 group 时 SHALL 同步移除其持久化数据（与既有 pin 关闭
语义一致）；关闭默认 group SHALL 释放默认槽。

#### Scenario: 重启后 group 完整恢复

- **WHEN** 用户创建含 `p1`、`p2` 的 group「dev」后退出并重启应用
- **THEN** 菜单栏仍有字母「de」的图标，下拉依序显示 `p1`、`p2` 两行

#### Scenario: 重启后默认 group 恢复

- **WHEN** 用户创建默认 group（含成员 `p1`）后退出并重启应用
- **THEN** 菜单栏仍有应用图标的图标，下拉显示 `p1` 行；此时在命名窗口
  留空确认 SHALL 被告警拒绝

#### Scenario: 关闭 group 移除持久化

- **WHEN** 用户在该 group 菜单执行「Close This Menu Instance」后重启应用
- **THEN** 该 group 不再出现

#### Scenario: 关闭默认 group 释放默认槽

- **WHEN** 用户在默认 group 菜单执行「Close This Menu Instance」后，在命名
  窗口留空确认
- **THEN** 直接创建一个新的默认 group

### Requirement: 设置窗口的成员管理

设置窗口 SHALL 为每个 group 提供成员管理列表：显示 group 名称与各成员（成
员行标题 SHALL 显示别名优先的显示名，与 group 下拉行一致；路径以次要文字
展示；bookmark 无法解析的成员 SHALL 显示缺失标记且仍可在列表中被移动/移
除）。列表内成员 SHALL 支持拖拽重排，顺序与菜单内「Move Up / Move
Down」使用同一持久化（在设置窗口重排后，重开 group 下拉 SHALL 反映新顺
序）；列表内 SHALL 支持移除成员，与菜单内「Remove from Group」同源；每个
group SHALL 提供设置窗口内的「Add Folder…」添加入口（同菜单内「Add Folder
to Group…」的目录选择与去重）。成员 SHALL 全量展示，MUST NOT 在组列表内
嵌套滚动（滚动由设置窗口整体承担）。菜单内
发生的成员增删、顺序变更、成员改名/恢复原名与 group 改名 SHALL 经既有变更
通知使打开中的设置窗口刷新。

#### Scenario: 设置窗口拖拽重排同步到菜单

- **WHEN** group 成员顺序为 `p1`、`p2`、`p3`，用户在设置窗口把 `p3` 拖到
  最前
- **THEN** 重开该 group 下拉时顺序为 `p3`、`p1`、`p2`

#### Scenario: 设置窗口移除成员

- **WHEN** 用户在设置窗口的成员列表移除 `p2`
- **THEN** 重开 group 下拉时 `p2` 行消失，其余成员与顺序保持

#### Scenario: 缺失成员在列表中可辨认且可移除

- **WHEN** 某成员目录已被删除，用户打开设置窗口
- **THEN** 该成员在列表中显示缺失标记，仍可被拖动或移除

#### Scenario: 设置窗口显示成员别名

- **WHEN** 成员 `chinasource-server` 已设别名「中台服务」，用户打开设置窗口
- **THEN** 该成员行标题显示「中台服务」，路径次要文字仍为真实路径

#### Scenario: 设置窗口直接添加成员

- **WHEN** 用户在设置窗口某 group 下点「Add Folder…」并选择一个新目录
- **THEN** 该目录成为该 group 成员（追加末尾、去重），菜单与设置窗口同步

#### Scenario: 成员全量展示无嵌套滚动

- **WHEN** 某 group 有超过 3 个成员，用户打开设置窗口
- **THEN** 全部成员行可见，滚动发生在设置窗口整体层面，组列表内无滚动条

#### Scenario: 菜单内改名后设置窗口即时刷新

- **WHEN** 设置窗口打开中，用户在 group 下拉为某成员改名（或恢复原名）
- **THEN** 设置窗口无需重开即显示新显示名

### Requirement: 缺失目录的呈现

成员目录被删除、或其 bookmark 彻底无法解析后，系统 SHALL 在下拉中为该成员
显示缺失行，MUST NOT 静默隐藏该成员。缺失行 SHALL 保留最后可知的标
识：bookmark 可解析但目录已不存在时，行标题 SHALL 为「<目录显示名>
(missing)」且 tooltip 带最后已知路径；bookmark 彻底无法解析时，行标题 SHALL
为「(missing)」。缺失行 MUST NOT 执行 Finder / 复制 / claude / IDEA 等任何
动作（点击无效果），但其悬停 SHALL 展开仅含「Remove from Group」的最小面
板，作为缺失成员的唯一移除通道。目录被移动或重命名后，bookmark SHALL 解析
到新路径，该成员行照常可用（不视为缺失）；目录恢复可访问后缺失行 SHALL 自
动恢复为正常成员行。

#### Scenario: 目录被删除后显示缺失行

- **WHEN** 成员 `p2` 的目录被用户删除，重开 group 下拉
- **THEN** `p2` 位置显示「p2 (missing)」行（tooltip 含最后已知路径，点击无
  任何动作效果），其余成员不受影响

#### Scenario: 缺失行悬停可移除

- **WHEN** 用户悬停「p2 (missing)」行，在其面板点击「Remove from Group」
- **THEN** 菜单关闭，重开下拉时该缺失行消失，其余成员保持

#### Scenario: 目录被移动后行照常可用

- **WHEN** 成员 `p1` 的目录在 Finder 中被移动到新位置，重开 group 下拉
- **THEN** `p1` 行照常显示并可用（bookmark 解析到新路径），不显示缺失

#### Scenario: 目录恢复后行复原

- **WHEN** 缺失成员的目录在原路径恢复（如从备份还原），重开下拉
- **THEN** 该行恢复为正常成员行，行内按钮可用
