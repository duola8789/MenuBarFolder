# PinFold

**把文件夹钉在 macOS 菜单栏上 —— 一键直达，即点即开。**

> **PinFold** 是 [MenuBarFolder](http://ctrl8.com/MenuBarFolder)
> （作者 iLya Os，MIT 协议）的 fork。上游负责把文件夹搬进菜单栏，
> 本 fork 把它升级成**手选项目的启动器**。

上游 MenuBarFolder 能做的：文件夹钉到菜单栏、点击打开、嵌套子菜单、
浏览器书签树、后台读大文件夹、四种排序、登录启动、无 Dock 图标。
这些 PinFold 全部继承。在此之上，fork 新增了下面这些。

---

## 本 fork 新增

### 文件夹分组（Group Pin）

一个菜单栏图标 = 一组**手选的任意文件夹**（不必同属一个父目录）。
点开就是纯启动器列表，一行一个成员，专为"常去的几个项目"设计：

- 每行悬停弹出操作面板：**重命名… / 还原原名 / 上移 / 下移 / 移出分组**
- 在**设置 → Folder groups** 里管理：新建、添加、系统原生拖拽重排、
  删除成员，所见即所得
- 成员以 bookmark 保存，文件夹移动/改名后依然有效；失效成员保留
  显示 missing 而不是悄悄消失

### 行内快捷按钮

每个文件夹行（普通 pin 的标题行和子文件夹行、分组 pin 的成员行）
都带四个行内小按钮：

| 按钮 | 动作 |
|------|------|
| Finder | 在 Finder 中打开 |
| 复制路径 | 复制 POSIX 路径到剪贴板 |
| Claude Code | 在该文件夹打开 iTerm2 会话并启动 Claude Code |
| IDEA | 用 IntelliJ IDEA 打开该文件夹 |

常用工具一键直达，不用先去 Finder 里找目录再拖进终端。未安装 IDEA
或 iTerm2 时会响铃提示，不会静默失败。

### 显示别名

给被钉的文件夹起显示别名（`Do` 图标下可以叫"下载"，也可以叫
"临时垃圾堆"），**排序按别名**进行，改个名就是重排。

### 独立应用身份

独立的 bundle 标识（`com.duola8789.pinfold`）与 LaunchAgent，与上游
共存互不干扰；打包脚本支持无证书机器 ad-hoc 出 DMG。

---

## 下载与安装

DMG 在仓库 `dist/` 目录
（[github.com/duola8789/MenuBarFolder/releases](https://github.com/duola8789/MenuBarFolder/releases)）。
macOS 13+。打开 DMG，把 **PinFold** 拖进"应用程序"，启动后挑一个
要钉的文件夹即可。

上游原版 [MenuBarFolder](https://github.com/ilya000/MenuBarFolder/releases/latest)
的 DMG 有签名并公证，不会被 Gatekeeper 拦。

### Gatekeeper 提示"无法验证"怎么办

本 fork 的 DMG 是 **ad-hoc 签名**（无 Developer ID、未公证），下载副本
会被 Gatekeeper 拦下（"Apple 无法验证 PinFold-x.x.x.dmg …"）。两种解法：

- **系统设置 → 隐私与安全性**，找到"Apple 无法验证…"提示，点
  **仍要打开**，再确认一次；
- 或终端去掉隔离属性：

  ```bash
  xattr -d com.apple.quarantine ~/Downloads/PinFold-1.2.0.dmg
  xattr -dr com.apple.quarantine /Applications/PinFold.app   # 若拖装后仍被拦
  ```

## 从源码构建

macOS 13+，推荐完整版 Xcode（CLT 若报
`plugin for module 'SwiftUIMacros' not found`，用
`sudo xcode-select -s /Applications/Xcode.app` 切换后重试）。
包/可执行名沿用上游的 `MenuBarFolder`，应用显示名才是 PinFold：

```bash
git clone https://github.com/duola8789/MenuBarFolder.git
cd MenuBarFolder
swift build -c release
.build/release/MenuBarFolder            # 首启出文件夹选择器
scripts/build_app.sh                    # 打包发布版 DMG
```

## 内部实现速览

- 文件夹/分组以 bookmark 保存，移动改名后依然有效。
- 登录启动写 `~/Library/LaunchAgents/com.duola8789.pinfold.plist`，
  无需 `.app` bundle；带单例锁，修掉了上游登录启动会叠出双图标的 bug。
- 目录读取在后台线程、带缓存、每层有上限，菜单秒开。
- Claude Code 按钮经 AppleScript 驱动 iTerm2，按 bundle id 寻址并做
  启动窗口空闲检测 —— 冷启动也稳定，不会多开空窗口。

## 沿革

上游 MenuBarFolder 是 iLya Os 1998 年 Win95/NT 小工具 **TrayMenu** 的
精神续作（老站存档：[old.osipov.ru/proge.htm](https://old.osipov.ru/proge.htm)）。
同一个点子，约 28 年后原生于 macOS 菜单栏重现。

## 许可证

MIT —— 见 [LICENSE](LICENSE)。
Copyright (c) 2026 Ilya Osipov (iLya Os) ·
Fork 维护：[duola8789](https://github.com/duola8789)
