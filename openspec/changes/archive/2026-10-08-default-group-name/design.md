# Design: default-group-name

## Context

见 `proposal.md` 的 Why。现状：`createNewGroup()`（main.swift:76）在回调里
`guard !trimmed.isEmpty else { return }` 静默不创建；`FolderAliasWindow` 的
`confirmEdit()` 无条件 `orderOut(nil)`（FolderAliasWindow.swift:81），即确认
后窗口必然关闭；`GroupRecord`（GroupStore.swift:23）只有
`id / name / members` 三字段，名字不查重；`GroupPin` 图标统一走
`StatusIcon.iconLetters(for:)`（GroupPin.swift:36,51），字母完全来自名字。

## Goals / Non-Goals

**Goals:**

- 留空一键创建默认 group；全局至多一个默认 group，第二个留空尝试被显式
  告警拒绝（不再是静默 no-op）。
- 默认 group 视觉可辨（folder 图形），且与手动命名的同名组天然不混淆。
- 旧持久化数据零迁移成本兼容。

**Non-Goals:**

- 不引入组名唯一性约束（普通组同名仍允许并存）。
- 不改共享 `FolderAliasWindow` 的另外两个使用语境（alias 改名、group 改
  名）的空输入语义。
- 不做默认 group 的成员自动填充（如自动把所有未分组 pin 收进来）。

## Decisions

### D1：默认身份用独立标志，而非名字哨兵

`GroupRecord` 新增 `isDefault: Bool`，`Codable` 解码缺失时回落
`false`（Swift 合成解码对可选缺省需手写 `decodeIfPresent` 或声明默认值的自
定义 `init(from:)`——实现时二选一，行为相同）。

- 备选（否决）：以 `name == "default"` 作哨兵。实现更小，但用户手动建一个
  叫 "default" 的组会占用默认槽，且字母 "de" 与 "dev" 等组视觉撞车；独立
  标志让"手动 default 组"与"默认组"天然可区分。

### D2：默认组图标复用应用图标（与空态 setup 菜单同源）

`GroupPin` 渲染处按 `isDefault` 分支：`AppIcon.make(size: 36)` 再设
`size = 20×18`——与 `showSetupItem()`（main.swift）完全相同的来源与规
格，"默认组 = 应用本尊"语义直观。否则维持现有
`StatusIcon.iconLetters(for: name)` 路径不变。彩色非 template 图标在菜单
栏有既有先例（书签 pin 的 browser badge 图标同样非 template）。

- 备选一（否决，走查反馈）：`StatusIcon.make(letters: "")` 纯 folder
  glyph。零新代码且视觉规格统一，但走查中被反馈"太素、像个默认文件夹"，
  且与普通组（folder+字母）只差一点角标，辨识度不足。
- 备选二（否决）：取 "default" 的字母 "de"。与 "dev" 等组视觉撞车，且手
  动 default 组无法区分。

### D3：告警与"窗口保持打开"放在确认回调链，不动共享窗口的关闭策略

`FolderAliasWindow.confirmEdit()` 目前无条件关窗。方案：把 `onConfirm`
签名从 `(String) -> Void` 改为 `(String) -> Bool`——返回 `false` 表示"拒绝
本次确认"，`confirmEdit` 据此跳过 `orderOut`（窗口保持打开、焦点留在输入
框）。5 处调用语境中只有 create-default-rejected 返回 false；组改名、成
员别名、子目录别名、pin 别名 4 处回调恒返回 true，行为不变。

- 备选（否决）：在 main.swift 弹完 `NSAlert` 后重新调用 `window.show(...)`
  复活窗口。不用改共享组件签名，但复活路径会重置回调与选中态，且"关了又
  开"在视觉上有闪烁；改返回值语义更直白，改动面也小（一个 `if`）。

告警本体：`NSAlert`（warning 样式，单 OK 按钮，文案如 "A default group
already exists. Give the group a name, or cancel."），以命名窗口为
`sheet` 或居中模态呈现——实现时取视觉更自然者，不影响契约。

### D4：GroupStore 提供"默认组查询 + 条件创建"，判定集中在 store

新增 `isDefaultGroup` 查询（`groups.contains { $0.isDefault }`）；
`addGroup(name:isDefault:)` 带标志；`rename(_:for:)` 在目标为默认组且新名
非空时把 `isDefault` 翻为 false。默认槽占用判定只依赖 store，main.swift 的
回调只编排"弹窗 or 创建"，不重复持有判定逻辑。

## Risks / Trade-offs

- [isDefault 与 name 双轨，可能出现 name=="default" 且 isDefault==false
  的普通组] → 这是 D1 的有意设计（不混淆），spec 已明确该组不占默认槽；UI
  上二者图标不同，用户可辨。
- [`onConfirm` 签名变更波及全部调用点] —— 实际共 5 处：创建组
  （main.swift）、组改名 / 成员别名（GroupPin.swift）、子目录别名
  （FolderMenu.swift）、pin 别名（FolderPin.swift）；4 处非创建回调恒返回
  true，行为不变；编译器保证无遗漏。
- [folder/应用图标的视觉粗细与字母图标不一致] → AppIcon 直接复用空态
  setup 图标的现成规格（36pt 渲染、20×18 落位），走查已确认观感可接
  受；如仍需微调只动 size 参数，契约（"应用图标"）不变。
- [告警以 sheet 呈现时窗口已 orderOut 的时序问题] → D3 已把"关窗"延后到
  回调返回之后，sheet 弹出时窗口仍在屏上，时序安全。

## Migration Plan

- 持久化：旧 JSON 无 `isDefault` 字段 → 解码为 false（普通组），无迁移代
  码。回滚：本变更不写任何数据格式破坏性变更，回滚到旧版本二进制后
  isDefault 字段被旧解码器忽略（Swift 默认忽略未知字段），数据无损。
