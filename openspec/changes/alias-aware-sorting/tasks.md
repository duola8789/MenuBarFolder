## 1. 排序别名化实现

- [x] 1.1 `FolderMenu.swift` `readListing` 内取 `InstancePrefs.aliasSnapshot()`
      一次，构建 `Meta` 时**仅对目录条目**（`isDir` 为真）将排序名改为
      `aliases[entry.standardizedFileURL.path] ?? (v?.localizedName ?? entry.lastPathComponent)`
      （key 与渲染层 buildItems 一致，文件条目不查别名与其对齐）；确认
      `nameAsc`/`dateDesc`/`size` 分发与 foldersOnTop/separator/maxItems 逻辑无
      其他改动
- [x] 1.2 `aliasSnapshot()` 处对空串别名的防御过滤（`compactMapValues` 改为
      剔除空串，见 design.md Risks），确认渲染层行为不受影响（历史手工空串别
      名随之回落原名，视为修复）
- [x] 1.3 `swift build -c release` 通过（失败先查 `xcode-select -p` 是否指向
      /Applications/Xcode-27.0.0.app）
- [x] 1.4 `openspec validate alias-aware-sorting --strict` 通过
- [x] 1.5 顺手修复 2.5 验证发现的真实 bug（三轮）：iTerm2 未运行时 AppleScript
      冷启动失败。根因（实测定案）：iTerm2 的 LS 注册名是「iTerm」（bundle 名），
      可执行/进程名才是「iTerm2」，按名字 `tell application "iTerm2"` 只在 app
      运行时经进程表命中，app 退出则编译期 -2741 / 运行期 -1728（报错被 `try?`
      吞掉，表现为「点了没反应」）。另修两处竞态：`create window` 后经动态解
      析的 `current window` 找会话不可靠；冷启动后 phase 2 探针只等「启动窗口
      出现」而非「会话空闲」，登录 shell 启动期 `is processing` 为真会让复用检
      查误判而多开一个空壳窗口。最终实现：所有脚本与探针改 `tell application id
      "com.googlecode.iterm2"`（by-id 冷热通吃，activate 可隐式拉起）；未运行时
      NSWorkspace.openApplication 预启动 + 两阶段探针（应答 + 启动窗口空闲）；
      冷启动单空闲窗口复用、否则新建；窗口定向一律持引用不问「当前窗口」。
      冷热路径均经独立复刻进程端到端验证（冷：终态恰 1 窗口；热：恰增 1 窗口）。
      行为契约不变（inline-row-actions 无需 delta），`swift build -c release`
      通过

## 2. 实机验证（先 Quit 正在跑的 MenuBarFolder 实例，避免图标叠加）

- [x] 2.1 运行 `.build/release/MenuBarFolder ~/projects`，为字母序靠前的子目录
      `api-server` 设别名 `gateway`，Sort by name 下确认该行按别名排到
      `blog` 与 `chinasource-server` 之间（spec scenario「Sort by name 按别
      名排序」；勿用中文别名验证排序位置——汉字在 zh_CN locale 下排在拉丁字
      母之前，位置断言不稳健）——实测通过
- [x] 2.2 修改该别名后关闭并重开菜单，确认目录刷新完成后顺序按新别名更新（验
      证无缓存陈旧问题，spec scenario「别名变更后重开菜单顺序更新」；打开首
      帧沿用上次快照属正常）；清除别名确认回落原位——实测通过
- [x] 2.3 Sort 切到 Date modified，用 `touch -t YYYYMMDDhhmm` 给两个目录设相
      同 mtime 制造平局，确认平局回退按显示名（spec scenario「平局回退按显示
      名」；date added 取 addedToDirectoryDate/creationDate，touch 改不了，不
      作验证项）——实测通过（zz-test-a/b 同 mtime，改 zzz 后按显示名排到
      zz-test-b 之后；测试目录已删）
- [x] 2.4 Folders on top 开启下确认组内顺序与「+N more」按显示名序生效——实
      测通过。附带：冷启动后进 claude 的「几秒延迟」已量化（3.6s 总延迟中
      2.97s 为登录 zsh 初始化，机制开销仅 ~0.6s），探针轮询 0.2s 收紧至
      0.05s 再省检测滞后；剩余为 shell 环境启动成本，不在本项目范围
- [x] 2.5 Carry-over 验证一：quit iTerm2 后点终端按钮，确认冷启动路径正常
      （新窗口 cd + claude 启动）——实测发现并修复了真实 bug（见 1.5），修复后
      冷启动通过；附带两个非 bug 观察：iTerm 冷启动的会话恢复窗口属其默认行为，
      `!` shell 的 CLAUDE_CODE_CHILD_SESSION 标记沿启动链继承属测试方法伪影
      （真实使用不受影响）
- [x] 2.6 Carry-over 验证二：如触发首次 macOS Automation 授权弹窗（iTerm2
      AppleScript），确认允许后流程正常——实测弹窗出现、允许后即成功

## 3. 提交与收尾

- [ ] 3.1 Conventional Commits 提交（如 `fix(sort): sort by alias-aware
      display name in folder listings`），尾部
      `Co-Authored-By: Claude Code <noreply@anthropic.com>`
- [ ] 3.2 BACKLOG「Carry-over verifications」两项按实测结果标记完成
