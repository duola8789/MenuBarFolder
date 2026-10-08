## 1. 存储层：GroupStore

- [x] 1.1 新建 `Sources/MenuBarFolder/GroupStore.swift`：`GroupRecord: Codable
      { id: UUID, name: String, members: [Data] }`，UserDefaults key
      `folderGroups` 存聚合 JSON；照抄 FolderStore 的 plain-bookmark
      resolve/save 逻辑。验证：`swift build` 通过
- [x] 1.2 实现成员增删：`add(member:)` 以 `standardizedFileURL` 判重忽略重
      复、追加末尾；`remove(memberAt:)` 按成员在记录中的下标移除（不按
      URL——resolve 失败的成员没有路径身份，见 design 决策 4）。验证：
      driver 调 `add` 两次同一 URL，`members.count == 1`；对含一个损坏
      Data 成员的记录 `remove(memberAt:)` 能删掉它
- [x] 1.3 缺失成员保留语义：load/save 只对可解析成员重新 mint bookmark，
      resolve 失败的原始 Data 原样回写不丢弃（与 FolderStore 的丢弃行为刻意
      相反，见 design.md 决策 1）。验证：往 `folderGroups` key 构造含损坏
      Data 成员的 GroupRecord 聚合 JSON（注意不是 `pinnedFolders` 那种裸
      [Data] 格式），load 后该成员仍在

## 2. 命名窗参数化

- [x] 2.1 `FolderAliasWindow` 增加 window title 与 confirm 按钮标题的配置
      （默认参数 "Rename Folder"/"Rename"，两个既有调用点
      FolderPin.renameFolder、FolderMenuDelegate.openRename 不改）。验证：
      `swift build` 通过，既有 FolderPin/子目录 Rename 流程行为不变

## 3. GroupPin 核心

- [x] 3.1 新建 `Sources/MenuBarFolder/GroupPin.swift`（`BasePin` 子类，
      NSMenuDelegate）：init 中 `statusItem.menu = NSMenu()` 并
      `menu.delegate = self`（menuNeedsUpdate 触发的前提，照抄
      FolderPin.swift:35-37）；持 `groupID`，`menuNeedsUpdate` → `layout()`
      每次从 GroupStore 现读 group；状态栏图标/tooltip 用
      `StatusIcon.iconLetters` + `StatusIcon.make`（照抄
      FolderPin.refreshChrome 路径）。验证：build 通过
- [x] 3.2 layout 渲染成员行：每成员 resolve bookmark + `fileExists` 校验，
      正常成员 → `ActionRowView`（标题优先 per-path 别名，四按钮接
      QuickActions，onTitle 开 Finder——与 submenu 并存是刻意设计，勿照
      ActionRowView 注释惯例置 nil，见 design 决策 4）；缺失两档呈现
      （resolve 成功但目录不在 → 「<显示名> (missing)」+ tooltip 路径；
      resolve 失败 → 「(missing)」）；全部行 `setCommonWidth` 对齐；空
      group 显示 "(no folders yet)"。验证：build 通过
- [x] 3.3 悬停 palette：正常成员行挂静态 submenu（6 个功能项 + 2 条分隔
      线）——Rename…（共用懒创建 FolderAliasWindow，per-path
      InstancePrefs 写入，空白清除语义照抄）、文字版 Open in Finder /
      Copy Path / Open with Claude Code (iTerm2) / Open in IDEA（闭包直调
      QuickActions）、Remove from Group（`remove(memberAt:)` 按下标）；
      缺失行挂仅含 Remove from Group 的最小面板。验证：build 通过
- [x] 3.4 显示小节 `displaySectionItems`：Rename…（改 group 名，非空才写
      回 GroupStore 落盘，空白确认不生效；回调后 `refreshChrome` 刷新图标
      字母与 tooltip）+ Add Folder to Group…（NSOpenPanel，照抄
      runFolderPicker pattern，选择后 `groupStore.add(member)`）。验证：
      build 通过

## 4. 接线

- [x] 4.1 `BasePin.makeAppMenuItem()` 加「New Folder Group…」项（与 Open
      Another Folder… 并排，action 走 AppDelegate）。验证：build 通过
- [x] 4.2 `AppDelegate`：`createNewGroup()`（弹参数化 FolderAliasWindow
      "New Folder Group"/"Create"，空白不创建，成功后 addGroupPin +
      removeSetupItem + notifyPinsChanged）；启动循环加
      `for group in groupStore.groups { addGroupPin(group) }`；`closePin`
      加 GroupPin 分支；setup 菜单（showSetupItem）加同款创建入口。验证：
      build 通过
- [x] 4.3 空态下创建的 group 成功后 setup 图标让位：从 setup 菜单创建
      group 后 removeSetupItem 生效。验证：实机——删光所有 pin 进空态，从
      setup 菜单建 group，setup 图标消失、group 图标出现

## 5. 构建与实机验证

- [x] 5.1 前置检查 `xcode-select -p` 指向 `/Applications/Xcode-27.0.0.app`
      （否则 swift build 缺 SwiftUIMacros 插件，见项目 memory），然后
      `swift build -c release` 无 warning 通过。验证：构建产物
      `.build/release/MenuBarFolder` 更新
- [x] 5.2 用户实机验证（建议 `! open .build/release/MenuBarFolder` 无参启动
      恢复既有 pin；如用 `--args ~/projects` 记得该参数会把目录持久加入
      `pinnedFolders`，验证完需在 Settings 移除；先 Quit 旧实例）：创建
      group 命名/图标字母（中文名取单字）、空态 setup 菜单创建、添加两个成
      员、下拉仅两行无 listing、悬停 palette 全项可用、palette 内改名生效
      （含成员别名对同路径 FolderPin 图标的联动，已知行为）、group 改名空
      白确认不生效、重复添加被忽略、Remove from Group 生效、目录移动后行
      照常可用、删除目录后显示 (missing) 且悬停可移除、重启后完整恢复、
      Close This Menu Instance 后重启不再出现。验证：上述各项逐一通过，
      iTerm 相关验证注意 by-id 定位（项目 memory）

## 6. 收尾

- [x] 6.1 Conventional Commits 分逻辑提交（store / window 参数化 / GroupPin
      / 接线分开），尾部 Co-Authored-By: Claude Code <noreply@anthropic.com>。
      验证：`git log --oneline` 各提交边界干净

## 7. 首轮实机验证反馈修复

- [x] 7.1 ActionRowView 边距对齐标准菜单项：leading 5→8pt、trailing 4→8pt
      （按钮锚点 +4pt），宽度公式同步（design 决策 9）。验证：`swift build`
      通过；group 下拉成员行与上方标准项左右内缩观感一致
- [x] 7.2 GroupStore 加 `moveMember(at:in:by:)`（swapAt + 越界忽略）。
      验证：driver 测试上移/下移/越界三种 case
- [x] 7.3 GroupPin palette 加 Move Up / Move Down（按位置裁剪越界项）与
      Restore Original Name（仅有别名时显示，点击清别名回落原名）。
      验证：`swift build` 通过
- [x] 7.4 group 下拉顶部加禁用组名 header 行（`ellipsizedMenuTitle()` 截
      断，tooltip 全名）。验证：`swift build` 通过；长组名下拉顶部可见
- [x] 7.5 用户复验：边距观感、Move Up/Down 顺序调整、Restore 恢复原名、
      长组名 header 可见、既有 FolderPin 行无回归。验证：逐项通过

## 8. 设置窗口拖拽管理（二轮反馈纳入）

- [x] 8.1 `GroupStore.moveMember` 泛化为 `moveMember(from:to:of:)`
      （remove+insert），palette 的 ±1 调用改为相邻下标。验证：driver 重跑
      上移/下移/越界 + 任意位置移动 case
- [x] 8.2 `AppDelegate` 暴露 `folderGroups` / `moveGroupMember` /
      `removeGroupMember` 转发方法（同 removeFolderURL pattern）；
      `notifyPinsChanged` 改 internal，GroupPin 在成员增删/移动后广播。
      验证：`swift build` 通过
- [x] 8.3 `Settings.swift` 加「Folder groups」小节：逐 group 成员 List
      （名称+路径，缺失标记），`.onMove` 拖拽重排 + 行移除按钮，live 刷新。
      验证：`swift build` 通过
- [x] 8.4 用户复验：设置窗口拖拽重排后重开菜单顺序一致、窗口移除成员同
      步、菜单内移动后设置窗口刷新、缺失成员可辨认可操作。验证：逐项通过

## 9. 二轮验证反馈修复

- [x] 9.1 修复「Start at Login 触发图标重复」：`LoginItem.install()` 不再
      `launchctl load`（RunAtLoad 会在 load 瞬间拉起第二个实例；plist 留给
      下次登录的 launchd 自行加载），并在 main 入口加 flock 单例锁兜底一切
      双启动路径。验证：`swift build` 通过；切换 Start at Login 菜单栏图标
      不翻倍
- [x] 9.2 Settings 成员行显示别名优先的显示名（路径次要文字保留真实路
      径），GroupPin 的成员改名/恢复原名/group 改名后广播既有变更通知使打
      开中的窗口刷新。验证：`swift build` 通过
- [x] 9.3 Settings「Folder groups」小节加组名块的上边距（截图反馈组名贴
      小节顶边）。验证：`swift build` 通过
- [x] 9.5 二轮截图像素测量后精调文字列：ActionRowView 标题列 29→32pt
      （图标→文字间距 5→8pt，对齐标准项文字列比例；图标列经一轮修正已对
      齐不再动）。验证：`swift build` 通过
- [x] 9.6 左边距改由用户实测口径决定并经一轮目测微调：ActionRowView 图标
      x=16pt、标题 x=40pt（trailing 8pt 不变），不再猜测标准项内缩常量；
      同轮反馈上下边距偏小，行高 24→28pt（内容居中，上下各 6pt）。
      验证：`swift build` 通过
- [x] 9.7 修复 Settings 成员列表布局：List 高度公式按真实行高（两行行
      ≈44pt/行，5 行封顶内部滚动，之前 ×30+14 导致末行路径被下一 group 块裁
      切）；组名块上边距 8pt、下边距 4pt。随后发现并修正自身引入的回归：
      显式 maxHeight:300 使 List 转为贪婪布局、把组名 Text 挤成零高（组名消
      失），已移除 maxHeight、保留 minHeight-only 模式（与组名可见时的结构
      一致）。验证：`swift build` 通过
- [x] 9.8 组名显示经几何测量定案：9.7 的 Section-header 方案被用户实测否
      决（header 行高按默认小号样式分配，.headline 字体渲染被裁半）；最终
      结构 = 组名为 List 兄弟节点 + `.fixedSize()` 不可压缩 + 收紧行布局
      （caption2、行距 38pt、3 行封顶内部滚动）使整块低于 section 隐式高度
      上限。离屏窗口 GeometryReader 测量验证：组名高 16pt 完整、位于列表上
      方。验证：`swift build` 通过
- [x] 9.9 三轮反馈落地：组名上间距 6→12pt；成员/pinned folders/书签列表全
      量展示（按数量计高，取消组内嵌套滚动）；Folder groups 每个 group 增加
      设置窗口内「Add Folder…」直添入口（复用 chooseGroupMemberFolder，同
      源去重）。验证：`swift build` 通过
- [x] 9.10 根治 Settings 组块裁剪（统一机制定案）：formStyle(.grouped)
      section 高度受限，超限时内容被垂直居中、上下两端同时裁掉——组名半截/
      消失/Add 按钮消失均为同一机制不同超限量。成员列表弃用 List（滚动容器在
      Form section 内才有此行为），改为普通 VStack 行 + 系统拖拽
      （.draggable/.dropDestination，String 载荷），整块自然生长、窗口整体滚
      动。验证：`swift build` 通过
- [x] 9.11 组块彻底摊平为 Form 直接子行（组名/每个成员/Add 按钮各为一
      行）——六轮截图证明 section 内任何「高个子单一子节点」（List 或打包
      VStack）都会在超出 section 分配高度时被居中裁剪；独立行是 Form 唯一
      保证原生处理的结构（自然生长、原生滚动），失败类被构造性消灭。
      验证：`swift build` 通过
- [x] 9.4 用户复验：Start at Login 不再叠图标、改名后 Settings 即时显示别
      名、边距观感正常。验证：逐项通过
