## Context

About 页目前是纯展示的 SwiftUI 视图（`Settings.swift` 中的 `AboutView`），设置窗口由 `SettingsWindowController` 持有并复用。应用没有网络代码、没有第三方依赖、单 target、无单元测试 target。发布由 annotated tag 驱动，CI 产出 DMG 并挂到 GitHub Release，因此 GitHub 的「latest release」页面就是权威的版本来源。参考实现来自 breather 仓库的 `UpdateChecker.swift`、`Version.isNewer` 与 About 窗口按钮。

## Goals / Non-Goals

**Goals:**

- 在 About 页用一个按钮完成「检查 → 比较 → 呈现」的闭环。
- 让网络代码可独立推理：一个入口、固定端点、明确超时。
- 与现有 SwiftUI/AppKit 混编结构保持一致，不引入新 target 或依赖。

**Non-Goals:**

- 不做自动下载、自动安装、增量更新或 Sparkle 集成。
- 不做启动时检查、定时检查、更新提示气泡或后台任务。
- 不处理预发布版本（prerelease）语义；只读 latest release 端点返回的版本。

## Decisions

**1. 新增 `UpdateChecker` 枚举，沿用 breather 的三态 Outcome。**
`check(completion:)` 在主线程回调 `.upToDate(current:)` / `.updateAvailable(version:url:)` / `.failed(reason:)`。与 breather 同构，阅读和迁移成本最低。

**2. 用 `releases/latest` 的公开重定向，而不是 REST API 或静态 feed。**
请求 `https://github.com/duola8789/MenuBarFolder/releases/latest`，URLSession 默认跟随 302 到 `/releases/tag/<tag>`，从最终 URL 取标签与发布页地址，无需解析正文。备选有两个：REST API（`/repos/.../releases/latest`）与本机实测中未认证额度已打满（共享出口 IP `60/60 used`，会直接 403）；breather 的 gist JSON feed 无限制，但每次发版要手动改 gist，与 tag 驱动发布双写。公开页面重定向既无限流，又跟随发布自动生效。代价是依赖 GitHub 的 URL 路由结构——若不再重定向到 `/releases/tag/<tag>`，表现为「检查失败」而非误判。

**3. 版本比较用纯数字分段，独立成 `Version.isNewer(_:than:)`。**
去掉可选 `v` 前缀，按 `.` 分段转 `Int`（非数字按 0），缺位补 0，逐段数值比较。避免字典序把 `1.5.10` 判成低于 `1.5.9`。不做语义化版本预发布/构建号解析，因为本项目只用 `MAJOR.MINOR.PATCH`。

**4. 结果用 SwiftUI `.alert` 呈现，有更新时给「Download」与「OK」两个按钮。**
与 breather 的 NSAlert 行为对齐；`Download` 走 `NSWorkspace.shared.open(release page)`，只打开浏览器。备选是页内状态文本，但 alert 在失败时能完整显示原因，且不改变 About 页布局。

**5. 状态留在 `AboutView` 的 `@State`。**
设置窗口会复用视图实例，检查状态随视图存活；不需要进 `SettingsModel`，也不持久化。按钮在请求期间 disabled，杜绝重复请求。

**6. 常量集中在 `AppInfo`。**
新增 `updateLatestPageURL`，与版本号同处一处，避免散落字面量。

## Risks / Trade-offs

- [未认证 REST API 限流（实测共享出口 IP 已 60/60 打满）] → 改走公开页面重定向，绕开 REST 限流；仍失败时提示原因，不影响应用其他功能。
- [GitHub 调整 `/releases/latest` 的重定向路由] → 失效表现为「检查失败」而非误判为最新；端点集中在 `AppInfo`，改一处即可。
- [仓库迁移或改私有后端点失效] → 同上，集中一处可改；失败态不会崩溃。
- [没有任何已发布 release] → 重定向落到 `/releases` 而非 `/releases/tag/<tag>`，判为「检查失败」并提示，不误报为最新。
- [新增出站网络能力改变安全基线] → 仅点击时请求、固定端点、不携带用户数据；在归档的安全基线说明中记录这一处有意的能力变更。
- [无自动化测试覆盖] → 版本比较是纯函数，实现时用手动用例表覆盖（见 tasks），并在真实应用里点一次按钮验证三种结果。

## Migration Plan

无数据迁移。新增文件与 About 页改动可独立回滚；回滚即删除 `UpdateChecker.swift`、移除按钮与常量。
