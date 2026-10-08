# MenuBarFolder — Backlog

## Heritage / history — DONE (Ilya loves the lineage)
- [x] Mentioned in **About** and **README**: MenuBarFolder is the spiritual
  successor to **TrayMenu (1998)** — Ilya's Win95/Win NT pop-up-menu utility:
  a Start-button-like menu that could sit anywhere on screen (including the
  tray, next to the clock / keyboard switcher), fully customizable, with
  directory submenus. The surviving archive holds only `TRAYMENU.EXE`
  (463 KB, dated 1998) — no source, just the binary.
- [x] Link to the old-site publication: https://old.osipov.ru/proge.htm

## Ideas / later
- Right-click context menu on individual items (requires custom NSView-backed
  menu items + `NSMenu.popUp`; loses default item styling — weigh cost).
- Option-alternate secondary actions for bookmark items (e.g. Copy URL).
- Opera / Arc bookmark support (different profile layout: Opera stores its
  profile at the support-dir root; Arc uses `StorableSidebar.json`).
- Safari bookmarks (would need Full Disk Access — decided against for now).

## Launcher roadmap (fork, decided 2026-09-28)

Row-action architecture rule: inline buttons are frequent *instant* actions
(keep to ~5 max); the hover submenu is the full action palette (text labels +
Rename… + optional contents). Implemented so far: Finder / Copy Path / Claude
inline, Rename… in the submenu header.

- [x] Open in IDEA button — 4th inline action. Add `QuickActions.openInIDEA`
      (NSWorkspace open-with-app, pattern from `BookmarksPin.openBookmark`);
      detect the installed flavor (`com.jetbrains.intellij` or CE
      `com.jetbrains.intellij.ce`), beep when absent (pattern from
      `openClaude`). Pick an SF Symbol for the button. — done 2026-09-28
      (`add-idea-action`, commit 9bb4131; symbol: `curlybraces`; note:
      modern IDEA builds incl. CE report bundle id `com.jetbrains.intellij`)
- [x] Per-pin "show folder contents" toggle in `DisplayOptions` —
      **superseded** (2026-10-08, `group-pin`): 不单独实现。explore 阶段定
      论：其动机（手挑目录作为启动目标、不展示内容）由 group pin 的行设计
      天然满足——group 成员行即纯 launcher 行，悬停面板即纯动作面板。
- [x] Group pin — one menu-bar icon holding a hand-picked list of arbitrary
      folders (not one parent's children). Rows reuse `ActionRowView`
      (inline actions + per-path alias + Rename…). Storage pattern: copy
      `FolderStore`. Needs add/remove-folder UI. — done 2026-10-08
      (`group-pin`): `GroupStore`（聚合 JSON + plain bookmark，resolve 失败
      成员保留显示 missing）、`GroupPin`（下拉 = 组名 header + 成员行，无
      listing；行悬停 = Rename…/Restore Original Name/四文字动作/Move Up/
      Move Down/Remove from Group）、创建命名复用 FolderAliasWindow、
      Settings「Folder groups」小节（摊平为 Form 直接子行 + 系统拖拽
      .draggable/.dropDestination 重排 + 行移除 + 直添入口）。附带修复既有
      bug：Start at Login 的 RunAtLoad 双实例（去 launchctl load + flock
      单例锁）。macOS 26 教训：formStyle(.grouped) section 会把高个子单一
      子节点垂直居中裁剪，组块必须摊平成 Form 直接子行。
- [x] Carry-over verifications from `add-folder-quick-actions`: iTerm2
      cold-start path (quit iTerm, click the terminal button once) and the
      macOS Automation permission prompt on first real use. Done in
      `alias-aware-sorting` (2026-09-28): the cold-start test surfaced a real
      bug — by-name `tell application "iTerm2"` only resolves while the app
      runs (LS registers the bundle as "iTerm"); fixed by by-bundle-ID
      targeting plus launch-window idle detection (avoids a second empty
      window). Prompt verified: appears once, allow, flow proceeds. Residual
      ~3 s cold delay is login-shell init, not app overhead.
