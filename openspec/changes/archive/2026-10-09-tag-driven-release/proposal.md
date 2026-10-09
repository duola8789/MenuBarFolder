# Proposal: tag-driven-release

## Why

Release 目前是纯手动：本地跑 `scripts/build_app.sh`、手动 `gh release create`
传 DMG 写 notes。手动流程依赖本机环境（ad-hoc 签名、产物在 dist/），且
「发版」这个动作没有留任何流程痕迹（tag 只是 gh 顺手打的、本地都没有）。
用 tag 驱动 GitHub Actions 出 release，把「发版」收敛成一个可审计的原子动
作：推一个 tag。

## What Changes

- 新增 `.github/workflows/release.yml`：`on: push: tags: ["v*"]` 触发，在
  macOS runner 上执行 `scripts/build_app.sh`（runner 无证书，脚本自动走
  ad-hoc 分支），产物 DMG 用 `gh release create` 挂到该 tag 上。
- **版本号与 tag 一致性校验**：workflow 第一步从 `AppInfo.swift` 提取版本
  号，与 tag 名（去掉 `v` 前缀）比对，不一致直接 fail——`AppInfo.swift` 保
  持唯一版本来源（`build_app.sh` 与 Info.plist/DMG 命名已依赖它），tag 只是
  发布信号，两者错位视为操作错误。
- Release notes 取 annotated tag 的 message（发布时打 annotated tag、正文
  写 notes，CI 原样搬运）；lightweight tag 兜底为空 notes。
- 本地补齐 `git fetch --tags`（v1.2.0 目前只在远端）。
- **AGENTS.md 更新**：核心原则第 3 条升级为「升版本号 = 打同名 tag」——
  push 到 main 后询问老板是否升版本，确认后：改 `AppInfo.swift` → commit →
  push → 打 annotated tag `v<version>`（message 即 release notes）→ push
  tag，release 由 CI 出。

## Capabilities

### New Capabilities

（无——纯工具链变更，无 spec 级行为变化，`.openspec.yaml` 已设
`skip_specs: true`）

### Modified Capabilities

（无）

## Impact

- 新增 `.github/workflows/release.yml`（GITHUB_TOKEN 需 `contents: write`
  权限）。
- `scripts/build_app.sh` 不动（现有 ad-hoc 分支在无证书 runner 上自然生
  效；notary 分支因 profile 缺失自动跳过）。
- `AGENTS.md` 核心原则/约定两处措辞更新。
- 发布流程变更：从「本地构建 + gh 手动发布」改为「本地只管 bump + tag，
  构建发布进 CI」。CI 产物仍为 ad-hoc 签名（收方清 quarantine，现状不
  变）。
