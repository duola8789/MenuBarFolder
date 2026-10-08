## Context

现状 pin 体系：`BasePin`（状态栏图标 + MenuBarFolder ▸ 应用子菜单骨架）之下
只有 `FolderPin`（一目录一图标，下拉含 listing，经 `FolderMenuDelegate` 懒加
载）与 `BookmarksPin`。`AppDelegate.pins: [BasePin]` 启动时由
`FolderStore`（UserDefaults 存 plain bookmark 数组，key `pinnedFolders`）/ 
`BookmarkStore` 逐个重建；关闭走 `closePin` 按类型分派 remove。

group pin 是第三种 pin：一个图标、N 个手挑成员目录、**无 listing**——因此完
全不经过 `FolderMenuDelegate` 的目录读取链路（无 background Task、无
Loading 占位、无缓存失效问题），菜单构建是纯同步的。成员增删、改名、缺失检
测都发生在「每次打开都整树重建」的现有菜单机制上（`menuNeedsUpdate` → 重
build），天然即时生效。

## Goals / Non-Goals

**Goals:**

- GroupPin 作为 `BasePin` 的第三个子类接入现有 pin 体系（启动重建 / close /
  notifyPinsChanged 全部复用）
- 菜单构建纯同步：每次打开 resolve 成员 bookmark → 逐行 `ActionRowView` +
  悬停 palette，无磁盘 listing
- 复用不改：ActionRowView、QuickActions、StatusIcon.iconLetters、
  InstancePrefs per-path 别名、FolderAliasWindow（仅参数化文案）
- 新文件 `GroupPin.swift` + `GroupStore.swift`，其余改动收敛在 BasePin /
  main.swift 的接线处

**Non-Goals:**

- 普通 FolderPin 的 per-pin contents toggle（BACKLOG #2，标 superseded，见
  proposal）
- 菜单内的拖拽排序——NSMenu tracking loop 接管鼠标，无公开重排 API，硬做
  必与悬停 palette/cancelTracking 冲突；拖拽需求由设置窗口承担（决策 10）
- 成员批量操作、group 间共享成员的去重提示（跨 group 重复是
  允许的，去重只在同一 group 内）
- 书签 pin、普通文件夹 pin 的任何行为变化

## Decisions

### 1. GroupStore：单个 UserDefaults key 存聚合 JSON，成员用 plain bookmark

新 key `folderGroups`，JSON 编码 `[GroupRecord]`，其中
`GroupRecord: Codable { id: UUID, name: String, members: [Data] }`。
成员 bookmark 用 plain（非 security-scoped），与 FolderStore 的既有结论一
致（非沙盒二进制里 scoped bookmark 解析必失败，plain 可用且已有全盘访问）。

- 备选「每个 group 一个 key」：save 时要遍历 key、删除要清 key，徒增一致性
  负担；聚合 JSON 一次读写原子完成
- 备选「成员存路径字符串」：放弃 bookmark 的「目录被移动后仍可解析」能力，
  违背 FolderStore 采用 bookmark 的初衷
- 与 FolderStore 的一处**刻意分歧**：FolderStore.load 会丢弃 resolve 失败
  的条目；GroupStore MUST 保留 resolve 失败成员的原始 Data（缺失成员要显示
  "(missing)" 行而非消失，见 spec「缺失目录的呈现」）。save 时只对可解析成
  员重新 mint bookmark（与 FolderStore 的 normalize 同法），不可解析成员原
  样回写

### 2. GroupPin：每次 layout 从 store 现读 group，不缓存成员列表

`GroupPin` 只持有 `groupID: UUID`，`menuNeedsUpdate` → `layout(menu)` 每次
从 `groupStore` 按 id 现取 `{name, members}`。Add / Remove / Close 修改
store 后，下一次打开必然读到新值——与 FolderPin「每次打开重读目录」的机制同
构，无需任何主动失效广播。

- 备选「GroupPin 持成员副本」：Add/Remove 后要双向同步，引入第二个事实来
  源；现读 store 是唯一事实来源，代码更少
- 附带效果：`clearCache()` 无需 override（没有可清的缓存）

### 3. 缺失检测在渲染时做，两档呈现，廉价且自愈

layout 时对每个成员 resolve bookmark；resolve 成功再做
`FileManager.fileExists(path, isDirectory:)` 校验。呈现分两档：resolve 成
功但目录不存在 → 「<显示名> (missing)」（tooltip 带最后已知路径）；resolve
彻底失败 → 「(missing)」。两档缺失行均以「无 action 的常规行」呈现禁用语
义（`isEnabled` 保持 true + `action = nil`，点击无任何效果）——AppKit 的
禁用项不响应悬停、不展开子菜单，若真设 `isEnabled = false`，spec 要求的
「悬停展开移除面板」将无法发生。目录被移动/重命名时 bookmark 解析
到新路径（FolderStore 采用 bookmark 的既有能力），行照常可用，**不视为缺
失**；目录恢复可访问后下次打开自愈，无需任何状态机。缺失行悬停挂仅含
「Remove from Group」的最小面板（缺失成员的唯一移除通道，行本身不接任何
动作）。成员数是个位数到十位数级别，每次菜单打开同步做一次完全无感。

### 4. 悬停 palette 是普通 NSMenuItem 小菜单，不经 FolderMenuDelegate

每个正常成员行挂一个**构建即完成**的小 submenu（Rename…、可选的 Restore
Original Name、四个文字动作、Move Up / Move Down、Remove from Group，加分
隔线），无 NSMenuDelegate（没有懒加载需求）、无 childDelegates 保留问题。
文字动作直接闭包调
`QuickActions`，与行内按钮同一入口，天然共享降级行为（未装 IDEA beep 等）。
palette 内 Rename… 复用 `FolderMenuDelegate.renameWindow` 的模式：GroupPin
持一个懒创建的 `FolderAliasWindow`，在多个成员行间共用，show 时按该行路
径 prefill、callback 走既有 InstancePrefs 写入（空白 → nil 的清除语义照
抄——这是 per-path 别名的语义，与 group 名改名的空白不生效不同，见决策
5）。缺失行挂仅含 Remove from Group 的最小面板（见决策 3）。

条件项在构建时按位置裁剪（palette 每次 layout 重建，无状态负担）：Restore
Original Name 仅当该路径已有别名（点击 = 清除别名，空白确认清除的显式入
口，实机验证反馈的可发现性问题）；Move Up 仅当非首个成员、Move Down 仅当
非末个成员（成员顺序手动语义，见决策 8）。

两个刻意设计，实现时勿被既有惯例带偏：

- **onTitle 与 submenu 并存**：ActionRowView 顶部注释明写惯例「拥有
  submenu 的行 onTitle 置 nil」，本 change 反之——成员行同时设置 onTitle
  （点击标题 = 开 Finder 并关菜单）与 submenu（悬停 = palette）。这是
  launcher 语义的刻意选择：标题点击是高频即时动作，不应让位于悬停面板
- **Remove from Group 按成员在 group 记录中的下标移除**，不按 URL——
  resolve 失败的成员没有可用的路径身份（决策 1 保留其原始 Data）。菜单点
  击即关闭、store 是唯一事实源，单次 layout 内捕获的下标不存在并发失效
  问题

- 备选「palette 也走 FolderMenuDelegate 加 palette 模式参数」：为几个静态
  项引入目录读取机器的全部耦合，不值
- NSMenuItem.target 弱引用问题不存在：GroupPin 由 `AppDelegate.pins` 强持
  有，target 指向 self 是安全的（与 FolderPin 同构）

### 5. 命名窗复用 FolderAliasWindow，参数化文案；group 名空白不生效

`FolderAliasWindow` 现有文案固定为 "Rename Folder" / "Rename"，用于**创建**
group（输入新名字）语义不符。给它加可配置的 window title 与 confirm 按钮
标题（`show` 或 init 带默认参数，两个既有调用点 FolderPin.renameFolder 与
FolderMenuDelegate.openRename 不改），group 创建传 "New Folder Group" /
"Create"。一个窗口类服务多个场景，避免再造一个几乎相同的 panel。

注意语义分叉：**成员行 Rename…** 是 per-path 别名，空白确认 = 清除（照抄
既有语义）；**group 名 Rename…** 是必填名，空白确认 = 不生效保持原名——
两者共用窗口但 callback 各自处理，窗口类不掺语义。

### 6. 创建入口接线：BasePin 一行 + setup 菜单一行，AppDelegate 收口

- `BasePin.makeAppMenuItem()` 在「Open Another Folder…」旁加「New Folder
  Group…」，action 走 `app?.createNewGroup()`（与 openAnotherFolder 调
  AppDelegate 同法）——三个 pin 类型与 setup 菜单共用一个 AppDelegate 入口
- `AppDelegate.createNewGroup()`：弹命名窗 → 非空则 `groupStore.add(name)` →
  `addGroupPin` → `removeSetupItem`/`notifyPinsChanged`（照抄 addFolderPin
  的两行）
- `closePin` 加一个分支：`pin as? GroupPin → groupStore.remove(id)`；启动循
  环加 `for group in groupStore.groups { addGroupPin(group) }`

### 7. 状态栏图标与 tooltip：完全照抄 FolderPin 的 chrome 路径

`StatusIcon.make(letters: StatusIcon.iconLetters(for: name))` +
`"MenuBarFolder — <name>"` tooltip + 改名后 `refreshChrome()`。多 group 并存
时各图标由各自名字取字区分（用户已确认此命名策略）。

图标只取 1–2 个字母，长组名在下拉内原本无处可看（tooltip 需悬停状态栏图
标）——下拉顶部补一行**禁用的组名 header**（超长走既有
`ellipsizedMenuTitle()` 截断，tooltip 放全名）。这是实机验证反馈的第 5 条。

### 8. 成员顺序 = 手动，不自动排序；双入口调整

实机验证反馈「重命名后期望行归位、且想要手动排序」后与用户确认：group 是
手挑清单，顺序表达的是使用频率而非字典序，选**手动**语义——保持添加顺
序。放弃备选「按显示名自动排序」：与 FolderPin 的 alias-aware 排序不同属
一类对象（那边是浏览目录 listing，这边是手挑目标清单），且自动排序与手动
互斥。

调整入口有两个，共用同一持久化：菜单内 palette 的 Move Up / Move Down（单
步微调，`swapAt`，越界项不显示）；设置窗口的拖拽重排（多步/精细，见决策
10）。

### 9. ActionRowView 边距对齐标准菜单项

实机验证两轮截图反馈。第一轮：成员行内容贴边（左 ~5pt、右 ~4pt），与同菜
单标准项的内缩（~6pt+）不一致——修 `ActionRowView` 自身：leading 5→8pt、
trailing 4→8pt（按钮锚点整体 +4pt）。第二轮像素测量：图标列已对齐（±1px），
剩余偏差在文字列（偏左 2–5px）与图标→文字间距（比标准项窄 ~4-5px）——标题
列 29→32pt（间距 5→8pt）。第三轮放弃估算：由用户以标尺实测标准项左侧边距
为 14pt，按该口径定值后用户再要求微调加大，最终定为 16pt——图标 x=16、
标题 x=40（间距 8pt）、trailing 8pt 不变；同轮验证反馈行上下留白偏小，
行高 24→28pt（内容居中，上下各 6pt）。这是共享 view 的全局修正
——FolderPin 的标题行与子目录行同步获得一致的观感改善；同一菜单内行宽统一
机制不变。两次识图测量互相矛盾时，以与代码几何自洽的一组为准。

### 10. 拖拽排序放设置窗口，不放菜单

用户追问拖拽可行性后纳入（菜单内拖拽不可行，见 Non-Goals）。设置窗口已是
SwiftUI（`List` + `onMove` 即系统标准拖拽，零自研拖拽逻辑）：新增
「Folder groups」小节，逐 group 列出成员（**别名优先的显示名** + 真实路径
次要文字，缺失成员标记但仍可移动/移除——二轮验证反馈「改了名 Settings 还
显示旧名」，故行标题与菜单行同样走 aliasSnapshot），`.onMove` 重排 + 行移
除按钮。`GroupStore` 相应把 ±1 移动泛化为
`moveMember(from:to:)`（remove + insert，palette 的 ±1 调用改为传相邻下
标）。菜单内的成员增删/移动/改名/恢复原名与 group 改名后 GroupPin 广播既有
`.mbfPinsChanged`，设置窗口照已有监听 live 刷新；窗口内的编辑直接走
AppDelegate 转发方法（同 `removeFolderURL` 的 pattern）。实现期教训（五轮截图定案）：
formStyle(.grouped) 的 section 高度受限，超限内容被垂直居中、两端裁掉——
List（滚动容器）做成员列表会周期性吃掉组名/按钮；最终成员列表为普通
VStack 行 + `.draggable`/`.dropDestination` 系统拖拽（String 载荷），整块自
然生长、Settings 窗口整体滚动，无嵌套滚动无裁剪。终局（9.11）：摊平——组名/成员行/Add 按钮作为 Form section
的**直接子行**，section 内不存在任何高个子单一子节点，裁剪失败类被构造性消
灭（六轮截图证明 List 与打包 VStack 都会中招，独立行是 Form 原生处理的唯一
保证结构）。

### 11. 顺带修复：Start at Login 的双实例（既有 bug，验证中暴露）

`LoginItem.install()` 写完 LaunchAgent plist 后当场 `launchctl load`，而
plist 带 `RunAtLoad: true`——load 瞬间 launchd 把同一二进制又拉起一份，无
单例保护的第二份照常创建全部状态栏图标 → 「切换 Start at Login 图标全部翻
倍」。修法两层：install 只写 plist 不再 load（`~/Library/LaunchAgents` 的
plist 由下次登录的 launchd 自行加载，当场 load 本就多余——当前实例已在跑）；
main 入口加 flock 单例锁（第二个实例拿不到锁即静默退出），兜底包括「登录
时代与手动启动撞车」「连续两次 open」在内的一切双启动路径。

## Risks / Trade-offs

- [group 成员 Rename… 与 FolderPin 别名共用 InstancePrefs keyspace（key =
  standardizedFileURL.path）] → 已知行为而非 bug：别名本就是 per-path 而
  非 per-pin 的（子目录别名同理），给 group 成员设别名会同步影响同路径
  FolderPin 的菜单栏图标与 tooltip。不为此另立 spec 条款
- [多 group 取字撞名（两个 group 都叫 "dev" 开头）] → 图标字母会相同，但
  tooltip 有全名可辨；不在此 change 解决（现状多个同首字母文件夹 pin 已同
  样存在）
- [resolve 失败成员的原始 Data 永久滞留（目录真被删了）] → 移除通道已定：
  缺失行悬停面板的 Remove from Group（按下标，见决策 4）；不主动清除，保
  留「目录恢复自愈」的可能性
- [GroupStore.save 对不可解析成员原样回写，bookmark 可能随系统时间推移彻底
  失效] → 行为与现状一致（仍显示 missing，且可经面板移除），无退化
- [同步 layout 做 bookmark resolve + fileExists，成员很多时理论上变慢] →
  实际规模为手挑个位数目录，无感；不做后台化（避免引入 FolderMenuDelegate
  式的双帧渲染复杂度）
- [FolderAliasWindow 参数化属既有文件改动，波及两个既有调用点] → 全部走
  默认参数保持原行为，build 时编译器兜底
- [ActionRowView 边距修正波及 FolderPin 行观感] → 全局一致改善（原本同样
  贴边，只是无人报告）；行宽统一机制与 hit-test 逻辑不变，仅平移几 pt

## Migration Plan

纯新增 + 少量接线改动，单次构建替换即可；GroupStore 是全新 UserDefaults
key，不触碰 `pinnedFolders` / `instanceDisplay`。回滚 revert 即可，无数据
残留（可选清理 `folderGroups` key）。

## Open Questions

（无）
