## Why

子目录设置别名后，菜单行显示了新名字，但 Sort by name 仍按文件系统原始目录名排
序——用户肉眼看到的顺序与显示名不符（如 `api-server` 设别名 `gateway` 后显示名
变了，行序仍停在 a 位置，不落到 g 位置）。
根因：别名在渲染阶段 `buildItems` 才介入，而排序发生在更早的后台 `readListing`
阶段，顺序在渲染层拿到时已定死。排序是用户每天看到的行为，应与显示名一致。

## What Changes

- Sort by name 排序键从「文件系统原始显示名」改为「别名列显示名」：有别名时按
  别名排，无别名时回落原始显示名（行为不变）
- date added / date modified / size 排序的平局回退走同一个 nameAsc 比较，随
  之自动按显示名排——不单独处理，作为同一行为条款
- 无新增缓存失效机制：现有「每次菜单打开都后台重读目录」的机制天然保证改别名
  后重开菜单顺序立即更新（已核实 FolderPin.refreshListing 与
  FolderMenuDelegate.populate 均为每次打开无条件重读）
- foldersOnTop 分组、分隔线位置、maxItems 截断沿用 listing 阶段逻辑，因排序
  在源头别名化而自然正确，无需渲染层重排

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `folder-alias`: 新增「别名参与排序」行为条款——sort 为 name 时按显示名（别
  名优先）排序；date/size 平局回退同样按显示名；别名变更后下次打开菜单顺序即
  更新。既有「别名仅影响展示层」条款的名称类展示语义不变，排序视为菜单展示行
  为的扩展。

## Impact

- `Sources/MenuBarFolder/FolderMenu.swift`：`readListing` 内 `Meta` 构建时以
  `InstancePrefs.aliasSnapshot()`（key 为 `standardizedFileURL.path`，与渲染
  层一致）取别名，别名优先于 `localizedName` 作为排序名；函数签名与两个调用
  点（FolderPin.refreshListing、populate）不变
- 不触碰：渲染层别名套用逻辑（buildItems）、foldersOnTop/separator/maxItems
  截断逻辑、DisplayOptions 持久化结构、书签排序（BookmarkTree，无别名概念）
- 兼容性：无持久化格式变化，无 BREAKING
