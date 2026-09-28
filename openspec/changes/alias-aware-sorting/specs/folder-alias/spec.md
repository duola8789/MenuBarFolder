## ADDED Requirements

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
