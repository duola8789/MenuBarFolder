# folder-alias Specification

## Purpose
为固定在菜单栏的文件夹提供纯展示层的自定义名称（别名），覆盖菜单栏图标、tooltip 与下拉菜单标题，不触碰真实文件系统。

## Requirements

### Requirement: 别名仅影响展示层

系统 SHALL 在固定文件夹存在别名时，将该别名用于菜单栏图标字母、状态栏按钮 tooltip、下拉菜单中该文件夹的标题及其菜单项 tooltip；磁盘上的真实目录名 MUST NOT 受任何影响。别名不存在时，系统 SHALL 回落到目录原始显示名；名称类展示（tooltip、菜单标题）MUST 与本能力引入前一致，图标取字遵循「图标字母对宽字符的适配」要求。

#### Scenario: 设置别名后各展示点更新
- **WHEN** 用户为固定文件夹 `~/project` 设定别名「代码库」
- **THEN** 菜单栏图标字母、按钮 tooltip、菜单标题、菜单项 tooltip 均显示「代码库」
- **THEN** 磁盘上该目录仍名为 `project`，其内容与路径不变

#### Scenario: 无别名文件夹名称展示保持原行为
- **WHEN** 用户从未为某固定文件夹设置别名（或已清除）
- **THEN** tooltip 与菜单标题显示目录原始显示名，与本能力引入前行为一致

#### Scenario: 宽字符名文件夹的图标取字顺带修复
- **WHEN** 某固定文件夹名为「项目」且从未设置别名
- **THEN** 图标字母显示「项」（引入本能力前为「项目」，2 个 11pt 汉字约 22pt，溢出 22×18pt 图标画布）

#### Scenario: 超长别名在菜单标题截断
- **WHEN** 别名长度超过 30 字符
- **THEN** 菜单标题按现有标题截断逻辑省略号化展示，不撑破菜单布局

### Requirement: 别名即时生效

系统 SHALL 在别名设定或清除后无需重启应用，立即更新菜单栏图标与按钮 tooltip；菜单标题在下次打开菜单时显示新值。

#### Scenario: 设定别名后图标立即刷新
- **WHEN** 用户在别名编辑窗口确认新别名
- **THEN** 菜单栏上的图标字母与 hover tooltip 立即反映新别名，无需重启应用

### Requirement: 别名持久化

系统 SHALL 将别名与该文件夹的其余显示选项（排序、分组）一同按文件夹路径持久化。应用重启后别名 SHALL 保留。已存在的、不含别名字段的旧持久化数据 SHALL 能被正常读取，既有的排序与分组设置 MUST NOT 丢失。

#### Scenario: 重启后别名保留
- **WHEN** 用户设定别名后退出并重新启动应用
- **THEN** 该文件夹的菜单展示仍使用该别名

#### Scenario: 旧数据无损升级
- **WHEN** 应用升级到含本能力的版本，且 UserDefaults 中已存在该文件夹不含别名字段的旧显示选项数据
- **THEN** 旧数据正常解码，排序与分组设置保持原值，别名视为未设置

### Requirement: 别名编辑入口

系统 SHALL 在每个固定文件夹的「MenuBarFolder ▸」应用子菜单内的显示设置小节中提供「Rename…」入口，点击后弹出独立文本编辑窗口；窗口打开时 SHALL 预填当前生效的别名（未设置为空）。确认后别名生效；用户提交仅含空白字符的输入时，系统 SHALL 视为清除别名（回落原始显示名）。取消编辑 MUST NOT 改变当前生效的别名。

#### Scenario: 通过菜单入口设定别名
- **WHEN** 用户在该文件夹菜单「MenuBarFolder ▸」子菜单的显示设置小节点击「Rename…」，在弹出窗口输入「代码库」并确认
- **THEN** 别名按上文要求生效并持久化

#### Scenario: 编辑窗口预填当前别名
- **WHEN** 别名已为「代码库」的用户再次打开「Rename…」窗口
- **THEN** 文本框预填「代码库」

#### Scenario: 取消编辑不改变别名
- **WHEN** 用户在编辑窗口修改了文本但点击「取消」
- **THEN** 当前生效的别名保持不变

#### Scenario: 清空输入清除别名
- **WHEN** 用户在编辑窗口清空文本（或仅输入空格）并确认
- **THEN** 别名被清除，各展示点回落目录原始显示名

### Requirement: 图标字母对宽字符的适配

当用于图标字母的显示名以宽字符（如 CJK 表意文字）开头时，系统 SHALL 取 1 个字符作为图标字母；以窄字符（如拉丁字母）开头时 SHALL 取 2 个字符，以避免字母溢出 22×18 pt 的图标画布。

#### Scenario: 中文别名取单字
- **WHEN** 别名为「代码库」
- **THEN** 菜单栏图标字母显示「代」

#### Scenario: 拉丁别名取两字母
- **WHEN** 别名为 `Codebase`
- **THEN** 菜单栏图标字母显示「Co」

### Requirement: 别名参与排序

目录内容排序 SHALL 使用「显示名」作为名称类排序键：条目有别名时取别名，无别名时
取目录原始显示名（后者行为与本能力引入前一致）。Sort by name 模式 SHALL 按显示
名升序排列；date added / date modified / size 模式的名称平局回退 SHALL 同样按
显示名排列。folders on top 分组、组间分隔线与 maxItems 截断 SHALL 按显示名排
序后的顺序生效。别名设定或清除后，菜单下次打开的目录刷新完成时，条目顺序 SHALL
按最新显示名排列（无需重启应用；打开首帧沿用上次快照属正常）。

#### Scenario: Sort by name 按别名排序

- **WHEN** pin 目录下存在子目录 `api-server`（别名 `gateway`）与 `blog`、
  `chinasource-server`，排序为 Sort by name
- **THEN** 该行按显示名 `gateway` 参与排序，位于 `blog` 之后、
  `chinasource-server` 之前，而非按原始名 `api-server` 排在最前

#### Scenario: 平局回退按显示名

- **WHEN** 排序为 date modified 且两个子目录修改时间相同（如 `api` 设别名
  `zeta`，与 `beta` 同 mtime），两者显示名先后关系与原始名相反
- **THEN** 平局回退按显示名排列两者（`beta` 在前，显示名为 `zeta` 的行在后）

#### Scenario: folders on top 分组与截断跟显示名走

- **WHEN** folders on top 开启且 Sort by name，有别名的子目录因别名排位变化越
  过截断边界
- **THEN** 文件夹组内顺序与「+N more」截断均按显示名排序后的顺序生效

#### Scenario: 清除别名后回落原位

- **WHEN** 用户清除某子目录的别名并重新打开菜单
- **THEN** 该子目录按目录原始显示名重新参与排序，顺序回落

#### Scenario: 别名变更后重开菜单顺序更新

- **WHEN** 用户为某子目录设定（或修改）别名后关闭并重新打开菜单
- **THEN** 菜单打开后目录刷新完成时，条目顺序按新显示名排列，无需重启应用
