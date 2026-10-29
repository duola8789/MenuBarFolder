## Why

PinFold 目前没有任何版本发现渠道：用户只能自己去 GitHub 仓库翻 release 才知道有没有新版本。设置窗口的 About 页已经展示了版本号，是放置「Check for Updates」的自然位置。发布已经由 tag 驱动、产物挂在 GitHub Release 上，所以最新版本信息无需另建服务。

## What Changes

- 在设置窗口的 About tab 增加「Check for Updates」按钮与就地状态提示。
- 点击后向本仓库的 GitHub 最新发布页面发起一次请求，跟随其重定向到具体发布标签页，取得最新版本标签与发布页面地址。
- 用纯数字版本比较（`1.5.10` > `1.5.9`，缺位补 0）判断是否有新版本。
- 有新版本时提供「Download」动作，打开 release 页面；已是最新时提示 up to date；请求或解析失败时提示错误原因。
- 请求仅在用户点击时发起一次，10 秒超时，不缓存；不后台轮询，不自动下载或替换应用。
- 不引入 Sparkle 等第三方更新框架，保持单 target、无外部依赖。
- **BREAKING**：无。

## Capabilities

### New Capabilities

- `update-check`: 用户主动触发的版本检查——数据来源、版本比较规则、三种结果（有更新 / 已最新 / 失败）的呈现，以及「只在点击时请求、不自动下载」的边界。

### Modified Capabilities

无。

## Impact

- `Sources/MenuBarFolder/Settings.swift`：`AboutView` 增加按钮与状态展示。
- 新增 `Sources/MenuBarFolder/UpdateChecker.swift`：请求、解码、版本比较与结果回调。
- `Sources/MenuBarFolder/AppInfo.swift`：增加最新发布页面常量。
- `openspec/specs/update-check/spec.md`：新增能力规格（归档时合入）。
- 安全基线变化：应用首次具备出站 HTTPS 网络能力。请求目标固定为本仓库的 GitHub Releases 页面、仅在用户点击时发生、无后台上报，需要在设计与实现中保持这一约束。
- 不涉及发布流程与签名机制。
