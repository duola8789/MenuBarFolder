# Design: tag-driven-release

## Context

见 `proposal.md` 的 Why。现状：`scripts/build_app.sh` 从
`AppInfo.swift` 读版本号（唯一来源），产出
`dist/PinFold-<version>.dmg`；无证书时自动 ad-hoc 签名、notary profile 缺
失时跳过公证；仓库无 `.github/workflows/`；远端有 `gh release create` 顺手
打的 `v1.2.0` tag，本地未 fetch。

## Goals / Non-Goals

**Goals:**

- 「发布」= 推一个 annotated tag，其余全自动（构建、DMG、GitHub
  Release、notes）。
- 版本号与 tag 错位在 CI 侧被显式拒绝，而不是产出错误命名的产物。
- 发布流程在 AGENTS.md 中一句话可描述，AI agent 与人工都照做。

**Non-Goals:**

- 不做 main push 的构建校验 CI（可后续加，与本变更无关）。
- 不引入 Developer ID 签名/公证（需要老板的 Apple 开发者证书与
  secrets，另行立项）。
- 不改 `build_app.sh` 本体。

## Decisions

### D1：AppInfo.swift 是唯一版本来源，tag 必须与之一致

workflow 第一步比对 `tag 名去 v 前缀` vs `AppInfo.swift 的
static let version`，不一致 `exit 1`。

- 备选（否决）：tag 为来源、CI 回写 AppInfo.swift。回写产生额外交易
  （tag 指向的 commit 与版本写入的 commit 分裂），且
  `build_app.sh`/Info.plist/DMG 命名已锚定 AppInfo.swift，改动面大。

### D2：notes 取 annotated tag 的 message

发布动作是 `git tag -a v<version> -m "<release notes>"`；workflow 用
`git tag -l --format='%(contents)' <tag>` 取出后作为 `gh release create
--notes-file`。v1.2.0 的长中文 notes 证明这个载体够用。

- 备选（否决）：仓库维护 RELEASE_NOTES.md 模板或 workflow 里硬编码。多
  一个要同步的文件；tag message 就地可见（`git show v1.3.1`），少一处真
  相。

### D3：单 workflow、tag 触发、macOS runner

`.github/workflows/release.yml`，`on: push: tags: ["v*"]`；
`runs-on: macos-14`（SwiftPM 原生支持）；permissions:
`contents: write`；步骤：checkout → 版本一致性校验 →
`scripts/build_app.sh`（`SKIP_NOTARIZE=1` 显式跳过公证探测，runner 上必然
无 profile，跳过探测省时间）→ `gh release create` 传
`dist/PinFold-<version>.dmg`。

- runner 无签名身份 → 脚本自动 ad-hoc，与本地现状一致，无需注入任何
  secrets。

## Risks / Trade-offs

- [CI 构建时间] macOS runner 冷启 + universal 双架构构建，单次约 5–10 分
  钟（本地 7 秒） → 只在 tag 时触发，频率低，可接受；失败时 tag 需删掉重
  打。
- [tag 打错（版本不一致）] → D1 的校验使其快速失败；恢复动作是删远端
  tag 重推。
- [ad-hoc 签名的收方体验不变（清 quarantine）] → 与现状一致，AGENTS.md
  已有说明；升级为正式签名另行立项。

## Migration Plan

- 合入本变更后，下一次发布即用新流程验证端到端（打 v1.3.2 tag 试跑，
  DMG 与 release 产出后人工核对）。
- 回滚：删除 workflow 文件即可回到纯手动发布，tag 与 AppInfo.swift 的
  一致性约定保留无害。
