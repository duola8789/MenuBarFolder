# Proposal: default-group-name

## Why

创建 folder group 时名字必填是一道多余的门槛：用户只想快点把几个常用目录归拢到
一个状态栏图标下时，起名是纯开销。允许留空直接创建（后台回落到默认组）能把创
建路径缩短一步；同时默认组只有一个，需要一个明确的拒绝通道而不是静默产生第二
个无法区分的图标。

## What Changes

- 创建 group 时名字留空：若当前不存在默认组，直接创建一个默认组——后台
  name 存 `"default"`，新增 `isDefault` 标志；状态栏图标复用应用图标
  （与空态 setup 菜单同源同规格），tooltip / 菜单 header / 设置窗口显示名
  均为 `default`。
- 名字留空但默认组已存在：弹 `NSAlert` 提示已存在默认组、不创建，命名窗口
  保持打开（用户可填名或取消）。
- 默认组可经既有 `Rename…` 改名：改名后 `isDefault` 翻回 false、释放默认槽，
  此后留空可再创建新的默认组；留空确认仍保持原名（既有规则不变）。
- `GroupRecord` 新增 `isDefault` 字段（Codable 解码默认 false，旧持久化数据
  无需迁移）。
- 手动命名的组（包括恰好叫 `default` 的）是普通组，不占用默认槽；本变更不
  引入组名查重（同名普通组仍允许并存，现状不变）。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `group-pin`: 「Group 的创建与命名」requirement 由"名字必填、空输入不创
  建"改为条件语义——留空时首个默认组直接创建（folder 图标、name 回落
  `default`），默认组已存在时留空确认 SHALL 弹窗拒绝且不创建；默认组改名
  释放默认槽。其余 requirement（成员行、悬停面板、持久化等）不变。

## Impact

- `Sources/MenuBarFolder/main.swift`：`createNewGroup()` 回调——留空分支改为
  条件创建 / 弹 `NSAlert`；窗口保持打开需要 `FolderAliasWindow` 暴露确认后
  不关闭的路径（或等效机制）。
- `Sources/MenuBarFolder/GroupStore.swift`：`GroupRecord` 加 `isDefault`；
  `addGroup(name:isDefault:)`；`rename` 翻标志；默认组占位查询。
- `Sources/MenuBarFolder/GroupPin.swift`：图标渲染分支——`isDefault` 时用
  应用图标（同空态 setup 菜单的 `AppIcon` 来源与规格），否则走现有
  `StatusIcon.iconLetters`。
- `Sources/MenuBarFolder/Settings.swift`：无行为变更（显示名回落
  `default`，无特例）。
- 持久化：`UserDefaults` 的 `folderGroups` JSON 增加字段，向后兼容。
