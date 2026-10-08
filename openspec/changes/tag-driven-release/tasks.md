## 1. 本地准备

- [x] 1.1 `git fetch --tags` 把远端 `v1.2.0` 补到本地，确认
  `git tag -l` 可见、指向 `0bdf709`

## 2. CI workflow

- [x] 2.1 新增 `.github/workflows/release.yml`：`on: push: tags:
  ["v*"]`、`macos-14`、`permissions: contents: write`；步骤为 checkout →
  版本一致性校验（tag 去 `v` 前缀 vs `AppInfo.swift` 版本，不一致
  exit 1）→ `SKIP_NOTARIZE=1 scripts/build_app.sh` → `gh release
  create` 挂 `dist/PinFold-<version>.dmg` 并以 annotated tag message 为
  notes：核对 YAML 语法（actionlint 或人工逐项检查 triggers/permissions/
  step 顺序）
- [x] 2.2 AGENTS.md 更新：核心原则第 3 条改为「升版本号 = 打同名
  annotated tag」的完整流程（改 AppInfo.swift → commit → push → `git
  tag -a v<version> -m "<notes>"` → push tag，release 由 CI 出），约定区
  同步「tag 必须与 AppInfo.swift 版本一致，错位会被 CI 拒绝」：核对两条
  更新落位且与现有内容不冲突

## 3. 端到端验证

- [x] 3.1 用一个真实版本走通全链路：bump 版本 → push → 打 annotated
  tag（notes 即 release 正文）→ push tag → 观察 Actions 成功、GitHub
  Release 创建、asset 为 `PinFold-<version>.dmg`、notes 为 tag message；
  顺带验证版本不一致路径（推一个错位 tag，确认 job fail 且不产生
  release，事后清理该 tag）
