## MODIFIED Requirements

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
