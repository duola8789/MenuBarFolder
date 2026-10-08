## 1. 数据模型（GroupStore）

- [x] 1.1 `GroupRecord` 新增 `isDefault` 字段并保证旧 JSON（无该字段）解
  码为普通组：写好后用一段临时验证（或单测）确认含旧格式 `folderGroups`
  数据的 UserDefaults 能正常加载且所有组 `isDefault == false`
- [x] 1.2 `addGroup` 带 `isDefault` 参数、新增默认组占用查询、`rename` 在
  默认组改非空名时翻转标志：验证调用路径覆盖三个新行为（创建默认组、查询
  占用、改名释放槽）

## 2. 命名窗口确认链（FolderAliasWindow + main.swift）

- [x] 2.1 `FolderAliasWindow.onConfirm` 改为 `(String) -> Bool`，返回
  false 时 `confirmEdit` 不关窗：验证 4 处非创建回调（组改名、成员别名、
  子目录别名、pin 别名）恒返 true、行为与改前一致（确认即关窗）
- [x] 2.2 `createNewGroup()` 回调改为条件语义：非空名→普通创建（现状）；
  留空且无默认组→创建默认组；留空且已有默认组→`NSAlert` 告警并返回 false
  （窗口保持打开）：手动验证三条路径各自的表现

## 3. 图标渲染（GroupPin）

- [x] 3.1 `GroupPin` 图标按 `isDefault` 分支渲染应用图标（同空态 setup
  菜单的 `AppIcon` 来源与 20×18 规格），tooltip 显示 `PinFold —
  default`：验证默认组图标为应用图标、普通组字母图标不变
- [x] 3.2 默认组改名后图标从 folder 图形切为字母（rename 回调内同步刷
  新，即时生效）：验证「默认组改名释放默认槽」scenario 的视觉部分

## 4. 集成验证

- [x] 4.1 对照 delta spec 逐条走查 scenario：留空创建默认组、第二个留空
  告警拒绝、默认组改名释放槽后可再留空创建、关闭默认组后可再留空创建、重
  启后默认组（folder 图形 + 默认槽占用）恢复、旧数据启动正常——全部手动验
  证通过
