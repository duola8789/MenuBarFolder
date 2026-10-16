## 1. 单实例锁迁移到用户私有目录

- [x] 1.1 在 `main.swift` 中把锁路径从 `/tmp/pinfold.duola8789.singleton.lock` 改为经 `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)` 解析后追加 `PinFold/singleton.lock`（不硬编码 `~/Library/...` 字面量），并在 open 前按需 `createDirectory(withIntermediateDirectories: true)`。验证：删除 `/tmp` 下旧锁后启动应用，`ls -l ~/Library/Application\ Support/PinFold/singleton.lock` 显示锁已在新位置创建，且 `/tmp/pinfold.duola8789.singleton.lock` 不再被重建。
- [x] 1.2 拆分锁失败的两种情形：`flock` 失败（锁被占用）保持静默 `exit(0)`；目录创建失败或 `open` 失败改为 `NSLog` 记录原因后继续启动。验证：让锁**无法建立**后启动应用——`chmod 0500` 该目录**并确保其中的锁文件不存在**（锁文件已存在时 `open` 仍会成功，测不到降级分支），菜单栏图标仍正常出现，`log show --last 1m --predicate 'process == "PinFold"'`（debug 产物则用 `MenuBarFolder`）能看到失败记录；随后 `chmod 0700` 恢复。
- [x] 1.3 锁文件创建权限由 `0o644` 收紧为 `0o600`。验证：`ls -l` 输出的权限位为 `-rw-------`。

## 2. 登录项自检与自愈

- [x] 2.1 在 `LoginItem.swift` 中抽出「构造 plist 字典 → 序列化 → 落盘」这一段供 `install()` 与新自愈逻辑共用，避免两处结构漂移。验证：`swift build` 通过，且生成的 plist 内容与改动前一致——用一个不可读的 plist 触发重建分支，`plutil -p` 显示的键恰为 Label / ProgramArguments / RunAtLoad / ProcessType 四项。
- [x] 2.2 实现自愈：启动时若 plist 存在，读出后**仅**替换 `ProgramArguments` 为新路径再写回；读失败或结构不可用时回落到按标准结构重建。验证：组装一个最小 `.app`（可执行文件置于 `Contents/MacOS/` 且 `CFBundleExecutable` 匹配，以通过 2.3 的守卫），手工把 plist 里的路径改成 `/nonexistent/PinFold`，从该 `.app` 启动后 `plutil -p ~/Library/LaunchAgents/com.duola8789.pinfold.plist` 显示路径已被修正为当前可执行文件。
- [x] 2.3 为自愈加安装版守卫：仅当 `Bundle.main.bundleURL.pathExtension == "app"` 时改写 plist。验证：先把 plist 里的路径改成 `/nonexistent/PinFold`，再运行 `.build/debug/MenuBarFolder`，`plutil -p` 显示该路径**未**被改写。
- [x] 2.4 保证自愈幂等且不创建：路径与当前可执行文件一致时 MUST NOT 重写文件，plist 不存在时 MUST NOT 创建。验证：路径一致时启动应用，plist 的 mtime 保持不变；删除 plist 后启动应用，`ls` 确认其未被重新创建、Settings 开关显示为关闭。

## 3. 文档同步

- [x] 3.1 更新 `AGENTS.md`：把「必须知道的坑」里的锁路径改为新位置，并保持「debug 产物与安装版不能共存」的表述（该约束本次不变）；在目录速览附近登记 `~/Library/Application Support/PinFold/` 归本应用所有。验证：`grep -rn '/tmp/pinfold' AGENTS.md` 无命中，且文中路径与代码实际解析结果一致。
- [x] 3.2 更新 `README.md` 中提及单例锁的描述。验证：`grep -rn 'tmp' README.md` 无遗留旧路径。

## 4. 回归与端到端验证

- [x] 4.1 双实例互斥回归：先启动安装版，再启动 `.build/debug/MenuBarFolder`（按 AGENTS.md 约定，测前先退出安装版、测后恢复）。验证：第二个进程静默退出，菜单栏不出现第二套图标。*（已用 `.app` 与裸二进制两个新代码实例验证：后者 `exit=0` 静默退出，全局仅剩 1 个实例。注意 `/Applications` 里的安装版仍是 1.4.0 旧代码、锁在 `/tmp`，需升级到本版本后才与 debug 产物互斥。）*
- [ ] 4.2 登录项端到端：在 Settings 中开启「Start at Login」，确认 plist 指向当前可执行文件且本会话未额外启动实例；关闭后确认 plist 被移除且开关显示为关。验证：`plutil -p` 与 `ls` 交叉确认，注销重登后应用自动启动。*（plist 层面的写入结构、自愈、幂等、不创建已由 2.1–2.4 与 4.3 覆盖；Settings 开关的实际点击与注销重登需人工确认。）*
- [x] 4.3 app 移动场景：把 `.app` 复制到另一路径并从该副本启动。验证：plist 中的路径被自愈为新副本路径，此后从该副本的登录项启动有效。*（已验证自愈到新副本路径，且 Label / RunAtLoad / ProcessType 三个键完整保留。）*
- [ ] 4.4 全量回归：`swift build` 通过；既有功能（pin 文件夹、书签 pin、folder group、行内快捷操作 Finder/复制路径/claude/IDEA）无回归。验证：按 README 手测一轮核心路径。*（自动部分已完成：`swift build` 通过、启动冒烟 4 秒稳定无异常日志、改动仅落在 `main.swift` 与 `LoginItem.swift`，菜单构建/书签/group/行内动作/持久化相关文件均未触碰；按 README 的核心路径手测需人工确认。）*
