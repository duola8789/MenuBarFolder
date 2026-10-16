## Why

一次针对本项目的安全审计发现两处低危但真实的加固点。它们都不构成后门或提权，但都属于本可以用很小改动消除的粗糙面：

1. **单实例锁放在世界可写的 `/tmp`。** 锁文件 `/tmp/pinfold.duola8789.singleton.lock` 位于全局共享、权限 1777 的 `/tmp`，路径固定且可预测。同机其他用户可预先创建并 `flock` 占用该文件，使 PinFold 每次启动都在拿到锁之前 `exit(0)`——对外表现为「点了图标什么都没发生」的静默失效。个人机器上危害有限，但这个本地拒绝服务面完全可以靠换个存放目录消掉。
2. **登录项会残留。** `~/Library/LaunchAgents/com.duola8789.pinfold.plist` 的 `ProgramArguments` 记录的是**写入当时**的可执行文件绝对路径。而 DMG 的标准安装方式正是「从挂载卷把 app 拖进 /Applications」——app 一旦被移动、改名或删除，plist 就指向一个不存在的路径。用户若直接拖废纸篓而没先关掉开关，就会留下一个 `RunAtLoad` 的失效 LaunchAgent，且此时登录项已静默失效、用户毫不知情。

两处行为都在 `AGENTS.md` 里被当作已知约束记着（锁路径；debug 产物与安装版不能共存），所以修复要连带把文档同步。

## What Changes

- 单实例锁从 `/tmp/pinfold.duola8789.singleton.lock` 迁到 `~/Library/Application Support/PinFold/singleton.lock`，**保持现有「全局单实例」语义不变**：debug 产物与安装版依然互斥，退出即释放锁的语义也不变。
- 区分两类锁失败：锁**被占用**仍是静默退出；锁**无法建立**（目录不可用等）改为记录日志并降级启动。现状把两者合并成同一个 `exit(0)`，迁到需要创建目录的私有路径后，这会让应用在锁基础设施出问题时完全无法启动且毫无提示——那正是本变更要消灭的那类静默失效。
- 新增登录项启动自检与**自愈**：登录项 plist 已存在时，把 `ProgramArguments` 修正为当前可执行文件的真实路径。app 被移动后登录项继续有效，同时消除指向旧路径的残留。
- 自愈带**安装版守卫**：只有从 `.app` bundle 内运行的进程才改写 plist；裸二进制（`.build/debug` 产物）启动时不自愈——否则每次调试都会把安装版的登录项劫持到 `.build/debug/`，而该路径会被后续构建重建或删除。
- 同步更新 `AGENTS.md` 的锁路径记录与相关表述。

## Capabilities

### New Capabilities

- `app-lifecycle`: 应用的进程生命周期行为——单实例互斥锁的存放位置与作用域，以及登录项的注册、自检与自愈。

### Modified Capabilities

无。现有 4 个 capability（`folder-alias`、`folder-quick-actions`、`group-pin`、`inline-row-actions`，共 20 条 requirement）均不涉及这两块行为——单实例锁与登录项是 `group-pin` 变更实现时顺带加的，从未立过 spec。

## Impact

- **代码**：`Sources/MenuBarFolder/main.swift`（锁路径）、`Sources/MenuBarFolder/LoginItem.swift`（自检与自愈），可能涉及 `Settings.swift`（开关状态的反映）。
- **文档**：`AGENTS.md`（锁路径、debug/安装版共存表述）、`README.md`（提及单例锁的那句）。
- **兼容性**：无持久化格式变更、无需迁移。旧锁文件自然废弃；已有安装的登录项 plist 由自愈按需修正，用户无感。
- **依赖与权限**：不新增任何依赖，不新增任何权限。
