## Why

当前一个 pin 只能装一个目录：用户想「一个图标 + 手挑的若干目录作为启动目标」
（如 p1/p2 各是一个项目根目录，点行内按钮直达 claude/IDEA），只能为每个目录
单独建 pin，菜单栏图标泛滥，且每个 pin 下拉还拖着不想看的子目录 listing。
BACKLOG「Launcher roadmap」第三条（group pin）即为这一步；原第二条（per-pin
contents toggle）的动机——手挑目录不需要展示内容——由本 change 的行设计天然
满足，标注 superseded 不再单独实现。

## What Changes

- 新 pin 类型 GroupPin：一个状态栏图标，下拉内每行是一个**手挑的目录**（复用
  ActionRowView：图标 + 标题 + 四个行内按钮，标题点击开 Finder），**不列任何
  目录内容**——下拉即启动目标清单
- 行悬停子菜单 = 纯 action palette（无文件 listing）：Rename…（per-path 别
  名，复用 InstancePrefs）、文字版 Open in Finder / Copy Path / Open with
  Claude Code (iTerm2) / Open in IDEA、Remove from Group
- 新 GroupStore（抄 FolderStore 模式）：UserDefaults 持久化
  `[UUID, name, 成员 bookmark 数组]`；成员顺序 = 添加顺序，无排序设置
- 创建入口：各 pin 的 MenuBarFolder ▸ 子菜单与空态 setup 菜单加「New Folder
  Group…」；名字必填（复用 FolderAliasWindow 作输入窗），状态栏字母取字复用
  `StatusIcon.iconLetters` 规则；改名走 group 显示小节的 Rename…，按 UUID 持久化
- 成员增：group 自己的 MenuBarFolder ▸ 子菜单「Add Folder to Group…」
  （复用 NSOpenPanel picker pattern）
- 缺失目录（被删除或 bookmark 彻底失效）显示禁用缺失行（保留最后可知的名
  称/路径），悬停可经「Remove from Group」移除；被移动/重命名的目录经
  bookmark 解析到新路径，行照常可用不视为缺失
- group 的显示小节只含 Rename… 与 Add Folder to Group…（无 sort /
  foldersOnTop——无 listing 即无排序语义）；group 名空白确认不生效（保持
  原名，区别于成员别名的空白清除语义）
- 成员顺序为手动（菜单内 palette 的 Move Up / Move Down + 设置窗口拖拽重
  排，同一持久化）；设置窗口新增「Folder groups」管理小节（成员重排/移除/
  缺失标记；菜单内拖拽不可行——NSMenu tracking loop 接管鼠标，无公开重排
  API）

## Capabilities

### New Capabilities

- `group-pin`: group pin 的完整行为——创建与命名（状态栏图标字母）、成员
  行渲染（无 listing 的 launcher 行）、悬停 action palette、成员增删、
  持久化与重启恢复、缺失目录处理

### Modified Capabilities

（无——inline-row-actions 的条款均针对 FolderPin 的标题行与子目录行，group
pin 是新增 pin 类型，不使任何既有 requirement 失真；普通 FolderPin 行为不
变，原 per-pin contents toggle 不实现。）

## Impact

- 新文件：`GroupPin.swift`（抄 FolderPin 骨架）、`GroupStore.swift`（抄
  FolderStore）
- `Sources/MenuBarFolder/BasePin.swift`：app 子菜单加「New Folder Group…」
  入口（与 Open Another Folder… 并排）
- `Sources/MenuBarFolder/main.swift`：AppDelegate 启动时从 GroupStore 建
  GroupPin；closePin / remove 类分派加 group 分支；空态 setup 菜单加同款
  创建入口
- `Sources/MenuBarFolder/Settings.swift`：新增「Folder groups」小节（成员
  拖拽重排/移除/缺失标记，`.onMove` 标准拖拽）
- 复用不改：ActionRowView、QuickActions、StatusIcon.iconLetters、
  InstancePrefs per-path 别名；FolderAliasWindow 参数化 window/confirm 文案
  （默认参数保持两个既有调用点行为不变）
- 兼容性：无既有持久化格式变化，无 BREAKING；书签 pin 与普通文件夹 pin 不
  受影响
