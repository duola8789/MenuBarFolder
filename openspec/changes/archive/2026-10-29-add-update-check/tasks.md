## 1. 版本比较与检查器

- [x] 1.1 新增 `Version.isNewer(_:than:)`（去掉可选 `v` 前缀、按 `.` 分段转整数、缺位补 0、逐段数值比较），用临时 `swift` 脚本跑用例表验证：`v1.5.2` > `1.5.1`、`v1.5.10` > `1.5.9`、`1.5.1` vs `1.5.1` 为 false、`1.5` vs `1.5.0` 为 false、非数字标签（如 `latest`）判为不可解析
- [x] 1.2 新增 `UpdateChecker`：请求 `AppInfo.updateLatestPageURL`，带 `User-Agent`，10 秒超时、忽略本地缓存；跟随重定向到 `/releases/tag/<tag>`，从最终 URL 取标签与发布页地址；按三态 `.upToDate` / `.updateAvailable` / `.failed` 在主线程回调；HTTP 非 200、网络错误、无发布页、版本无法解析都归入 `.failed` 并带原因。验证：`swift build` 通过，且代码中无其他网络调用入口

## 2. About 页接入

- [x] 2.1 在 `AppInfo` 增加最新发布页面常量（`https://github.com/duola8789/MenuBarFolder/releases/latest`），验证：全仓库只有这一处出现端点字面量
- [x] 2.2 在 `AboutView` 版本号下方增加「Check for Updates」按钮：点击发起检查，请求期间按钮 disabled 且显示进行中，结果用 `.alert` 呈现；有更新时提供「Download」打开重定向后的发布页 URL，已最新/失败只提供「OK」。验证：`swift build` 通过，About 页布局在 460×520 窗口内不溢出

## 3. 端到端验证

- [x] 3.1 运行 debug 产物打开设置 → About，点击按钮，确认当前 `1.5.1` 对线上最新 release 返回「已是最新」
- [x] 3.2 临时把 `AppInfo.version` 改为 `1.0.0` 重新构建，点击按钮确认返回「有更新 1.5.1」且「Download」能打开 release 页；完成后改回
- [x] 3.3 临时把 `updateLatestPageURL` 指向不存在的仓库重新构建，确认提示「检查失败」且应用不崩溃；完成后改回
- [x] 3.4 `openspec validate add-update-check --strict` 通过；确认无后台/启动时网络请求（只有点击路径调用 `UpdateChecker`）
