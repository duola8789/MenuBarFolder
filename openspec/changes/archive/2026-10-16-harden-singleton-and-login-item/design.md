## Context

动机见 `proposal.md`。需要说明的当前状态与约束：

- **锁**：`main.swift` 的 `MainActor.assumeIsolated` 块里，`open("/tmp/pinfold.duola8789.singleton.lock", O_CREAT | O_RDWR, 0o644)` + `flock(LOCK_EX | LOCK_NB)`；失败即 `exit(0)`。注释说明「有意不关闭、不解锁——锁随进程消亡」。这是**唯一的**一处锁。
- **登录项**：`LoginItem` 用固定 label `com.duola8789.pinfold`，plist 落在 `~/Library/LaunchAgents/`，`ProgramArguments` 取 `Bundle.main.executablePath`，`RunAtLoad: true`。`isEnabled` 的实现是**「plist 文件是否存在」**，Settings 的开关初值与回落都基于它。`install()` 有意不调 `launchctl load`（否则 `RunAtLoad` 会当场叠出第二个实例）。
- **两处共用同一 label 与同一把锁**，这正是 AGENTS.md 里「debug 产物与安装版不能共存」的成因；本次设计**保留**该约束（老板已确认）。
- 应用未沙箱化（ad-hoc 签名、无 entitlements），因此没有 sandbox container 路径可用；`~/Library/Application Support/` 是可用的用户私有位置。
- 当前没有任何代码写入 `Application Support`（该目录只被**读**用于浏览器书签功能），因此新建一个应用自有子目录不会与既有数据冲突。

## Goals / Non-Goals

**Goals:**

- 消除锁文件位于全局可写目录这一本地 DoS 面，且不引入新的静默失效。
- 让登录项在 app 被移动后继续有效，并消除指向旧路径的残留。
- 保证「自愈」不会把安装版的登录项劫持到构建产物路径。

**Non-Goals:**

- 不改 LoginAgent label、不改 bundle id、不引入沙箱或 Developer ID 签名（属发布链路话题）。
- **不**解除 debug 产物与安装版互斥的现有约束（保持全局单实例）。
- 不主动清理 `/tmp` 下的旧锁文件。
- 不做登录项以外的卸载残留清理（如 UserDefaults 等）。

## Decisions

### 1. 锁文件位置：`~/Library/Application Support/PinFold/singleton.lock`，固定名

路径通过 `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)` 解析后追加 `PinFold/singleton.lock`，**不硬编码** `~/Library/...` 字面量。目录按需 `createDirectory(withIntermediateDirectories: true)` 创建。

固定名（不按 bundle id 分目录）是有意为之：单实例语义是**跨发行形态的全局互斥**，按 bundle id 分会顺带解除 debug 与安装版共存限制，改变 AGENTS.md 记录的既有约定。

备选与排除理由：

- `~/Library/Caches/...`：锁属可再生产物，放 Caches 语义上也说得通，但 Caches 会被清理工具整目录删除，且该目录下并发写者更多；`Application Support` 更稳定，且本应用尚无自有子目录，正好一并占用。
- 按 bundle id 分目录：见上，会改变既有语义，已被老板否决。
- 保留 `/tmp` 但改权限/加随机名：仍需 `createDirectory` 之外的目录归属，且随机名与「固定路径可诊断」冲突；不如直接换到私有目录。

锁文件权限从 `0o644` 收紧为 `0o600`。目录本身由系统建为 `0o700`，外部用户不可达。

### 2. 锁失败的两种情形必须分开处理

这是本次改动**唯一一处行为语义新增**。当前代码把 `open` 失败与 `flock` 失败合并成同一个 `exit(0)`，在 `/tmp` 下这没什么问题；迁到需要创建目录的私有路径后，`open` 失败意味着「锁基础设施不可用」（磁盘满、目录权限被改坏），与「已有实例在跑」是完全不同的状况，而合并处理会让应用**完全无法启动且毫无提示**——这正是本变更要消灭的那类静默失效，不能从「别人能触发」变成「自己会踩」。

处理：

- `flock` 失败（锁被他人持有）→ **静默 `exit(0)`**。这是唯一合法的静默退出路径，语义不变。
- 目录创建失败 / `open` 失败 → `NSLog` 记录原因并**继续启动**（降级为无锁运行）。

降级运行的代价是可能出现双实例（叠图标），但其触发条件（用户私有目录不可写）概率极低，且叠图标比「点了没反应」更容易被察觉和诊断。

### 3. 自愈的安装版守卫：仅 `.app` bundle 内运行才改写

守卫条件为当前进程的可执行文件位于 `.app` bundle 内（`Bundle.main.bundleURL.pathExtension == "app"`）。

没有守卫会怎样：老板调试时跑 `.build/debug/MenuBarFolder`，自愈会把安装版的 plist 改指向 `.build/debug/MenuBarFolder`；此后重启电脑，launchd 启动的是构建产物，而该路径会被下一次 `swift build` 重建、`rm -rf .build` 删除——登录项坏掉，且指向一个每次构建都在变的路径。

备选：用 `Bundle.main.bundleIdentifier != nil` 判断。裸二进制的 `bundleIdentifier` 通常为 nil，效果接近，但 `.app` 路径后缀更直接地表达「这是一个安装版」。

### 4. 自愈只改 `ProgramArguments`，不重建整个 plist

读出既有 plist → 仅替换 `ProgramArguments` → 写回。读失败或结构不可用时，回落到按标准结构重建（与 `install()` 一致）。

理由：自愈的职责边界只有「启动目标路径」这一个字段，不该越权重写用户文件里的其它键。若直接复用 `install()` 的整份 dict 重建，会静默丢弃 plist 里我们没写的键。

写入逻辑（构造 dict + 序列化 + 落盘）与 `install()` **共用同一段实现**，避免两处 plist 结构各自漂移——这是本次唯一需要的小幅重构。

### 5. 自愈时机：启动时执行一次，幂等

在启动流程早期（`applicationDidFinishLaunching` 内、UI 建立之前）同步执行一次。

与 Settings 的交互无需特殊处理：Settings 开关初值来自 `LoginItem.isEnabled`，而自愈**不改变 plist 的存在性**（只改内容），所以开关状态不受影响。

幂等通过「路径一致则直接返回、不落盘」保证，避免每次启动都无谓写盘。

### 6. 不清理 `/tmp` 下的旧锁文件

旧文件是 0 字节、不再被任何代码使用，由系统周期性清理 `/tmp` 时自然消失。主动 `unlink` 需要在全局可写目录里做文件操作（引入 TOCTOU 与符号链接面），收益为零——不划算。仅需在 AGENTS.md 里说明旧路径已废弃。

## Risks / Trade-offs

- **[降级启动可能造成双实例、菜单栏叠图标]** → 仅在用户私有目录不可写时发生，概率极低；且叠图标易于察觉，优于静默不启动。日志中有明确记录可定位。
- **[自愈改写 plist 若被第三方工具同时写入]** → LaunchAgents 目录由 launchd 与本应用独占使用，并发写场景实际不存在；写入采用「读—改—写」短窗口，风险可忽略。
- **[自愈按「plist 存在」推断用户意图]** → 该推断与 `isEnabled` 的既有实现一致（同样以文件存在性为准），不新增语义分歧。用户删除 plist 即视为关闭，自愈不会重建。
- **[锁目录与未来应用数据目录混用]** → `PinFold/` 目录归本应用所有，本次只放 `singleton.lock`；后续若放数据，需在 AGENTS.md 的目录速览中一并登记。
- **[guard 判断依赖 bundle 结构]** → 若将来改为 `launchctl` 之外的方式（如 `SMAppService`）承载登录项，守卫条件需重新审视；当前无此计划。

## Migration Plan

无需数据迁移，步骤为纯部署：

1. 新代码启动即在私有目录建锁；`/tmp` 旧锁文件自然废弃，无需处理。
2. 已有安装的登录项 plist：启动时若其路径与当前可执行文件不一致则被自愈；一致则不动。用户无感。
3. 从 DMG 升级安装（拖入 `/Applications` 覆盖旧副本）后，路径不变，登录项保持有效；若用户此前把 app 放在别处，则首次从新路径启动时被自愈。

回滚：把锁路径改回 `/tmp` 即可，无持久化状态残留。自愈已修正的 plist 路径在回滚后依然正确（指向实际可执行文件），无需反向处理。

## Open Questions

无。所有会改变 spec、方案或任务拆分的决策均已定案。
