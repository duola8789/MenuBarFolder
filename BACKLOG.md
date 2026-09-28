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
- [ ] Per-pin "show folder contents" toggle in `DisplayOptions` — with it
      off, a row's hover submenu becomes a pure action palette (Rename… +
      text versions of every action, no file listing). This realizes the
      "actions vs contents" split above and turns the app into a launcher.
- [ ] Group pin — one menu-bar icon holding a hand-picked list of arbitrary
      folders (not one parent's children). Rows reuse `ActionRowView`
      (inline actions + per-path alias + Rename…). Storage pattern: copy
      `FolderStore`. Needs add/remove-folder UI.
- [ ] Carry-over verifications from `add-folder-quick-actions`: iTerm2
      cold-start path (quit iTerm, click the terminal button once) and the
      macOS Automation permission prompt on first real use.
