## Context

排序发生在 `FolderMenuDelegate.readListing`（nonisolated static，后台执行）：
读取目录、构建 `Meta`（name 取 `localizedName`）、按 `options.sort` 比较排序，
随后在同一函数内完成 foldersOnTop 分组、separator 计算与 maxItems 截断，产出
已定序的 `DirListing`。别名在渲染层 `buildItems` 才以 `aliasSnapshot()` 套用
（key 为 `standardizedFileURL.path`），顺序此时已定死——这是 bug 根因。

「缓存」现状（本设计的关键前提）：`FolderPin.listing` 与
`FolderMenuDelegate.cache` 都不是长期缓存——每次菜单打开（menuNeedsUpdate /
populate）都无条件 spawn 后台 `readListing` 重读磁盘并覆盖。缓存只承担「打开
瞬间渲染上次结果」的毫秒级占位。因此不存在需要主动失效的长期缓存；只要
readListing 本身感知别名，改别名后重开菜单顺序必然更新。

## Goals / Non-Goals

**Goals:**

- 排序键改为显示名（别名优先），在 listing 构建源头生效，使分组 / 分隔线 /
  截断自然正确
- date/size 平局回退随 nameAsc 一并别名化，语义统一为「显示名即排序名」
- 改动最小：不动函数签名、不动调用点、不动渲染层

**Non-Goals:**

- 渲染层重排（方案 A）——maxItems 截断在 listing 阶段按原始序进行，渲染层
  重排截错行；等于重写半套 listing 逻辑
- 书签排序（BookmarkTree）——书签无别名概念
- 渲染层 `buildItems` 的别名套用逻辑——保持原样，排序别名化后行序与行名天然
  一致
- 新增缓存失效广播机制——现有每次重读机制已覆盖

## Decisions

### 1. 在 readListing 内部取别名快照，而非调用方传参

`readListing` 开头调用 `InstancePrefs.aliasSnapshot()` 一次，构建 `Meta` 时对**目录
条目**以 `aliases[entry.standardizedFileURL.path] ?? localizedName` 作为排序名；
文件条目不查别名（与渲染层 buildItems 的 isDir 分支对齐，避免「目录被同名文件
替换」这类边缘下排序名与显示名分叉）。

- 快照 key 与渲染层（FolderMenu.swift buildItems）完全一致，两处排序名与显示
  名不会分叉
- `InstancePrefs` 是纯 enum + UserDefaults，未隔离，可从后台线程安全调用
  （UserDefaults 本身线程安全）；`readListing` 已是 nonisolated，无需 MainActor
  跳转
- 快照频率不变（每菜单构建一次），44 目录规模下单次 JSON 解码成本已由现有渲染
  层路径证明可接受
- 备选「调用方传入参数」：要改 `readListing` 签名并动两个调用点
  （FolderPin.refreshListing、populate），收益仅是可注入性，项目无测试注入需
  求，不取

### 2. 排序名只影响比较，不改 DirEntry 结构

`DirListing.entries` 携带的 `DirEntry`（url + isDir）不变，渲染层照旧自行查
别名取标题。排序名是 readListing 内 `Meta` 的局部概念。

- 避免 DirListing 结构变化波及缓存字段、Sendable 约束与渲染层
- 轻微重复（两处各查一次别名）换来层间解耦，与现有代码风格一致

### 3. 平局回退不单独处理

`dateDesc` 与 `size` 的平局回退复用同一个 `nameAsc`，nameAsc 别名化后回退自动
按显示名，无需额外代码。spec 的「名称平局回退按显示名」条款即由此满足。

## Risks / Trade-offs

- [后台线程读 UserDefaults 与主线程写入竞态] → UserDefaults 线程安全，最坏情
  况是本次构建读到旧快照，下次打开菜单（必然重读）自愈；且改别名的 Rename 窗
  口回调运行在 MainActor，写发生在读之前的概率极低
- [别名以空串持久化的历史数据] → 该数据无法经 UI 产生（两处 Rename 入口均把空
  白输入转为 nil），仅存在于手工篡改的 UserDefaults。快照处过滤空串后，渲染层
  对这类数据从「显示空串」变为「回落原名」，视为修复；不构成 spec 层行为变化

## Migration Plan

单次提交，无持久化格式变化，直接构建替换即可；回滚即 revert 单个 commit。

## Open Questions

（无）
