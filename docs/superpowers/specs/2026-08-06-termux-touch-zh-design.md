# Termux 触摸/输入法与中文插件默认启用

日期：2026-08-06  
状态：已确认设计，待评审

## 背景

在 Termux 中使用 opencode 时，点击输入框无法唤起软键盘。

根因：

- opencode 默认启用鼠标捕获（发送 `\x1b[?1000h`、`\x1b[?1002h`、`\x1b[?1003h`、`\x1b[?1006h`）。
- Termux 的 `TermuxTerminalViewClient.onSingleTapUp()` 只在鼠标捕获未激活时才会弹出软键盘。

因此需要让 opencode-termux 默认关闭 opencode 的鼠标捕获，恢复 Termux 点击唤起输入法的行为，同时保留用户重新开启鼠标的入口。

另外，用户希望 opencode 在 Termux 下默认启用中文界面。官方 OpenCode 1.18.13 的 TUI 没有内置 i18n，完整汉化需要 fork 源码重新编译，维护成本高；社区插件 `opencode-zh-plugin`（要求 OpenCode >= 1.18.0）可通过官方插件 API 实现常见界面的中文展示，适合随 opencode-termux 默认安装。

## 目标

- opencode-termux 安装后，Termux 点击输入框可以正常唤起软键盘。
- opencode-termux 安装后默认启用 `opencode-zh-plugin` 中文插件。
- 用户仍可通过配置重新开启鼠标，或移除中文插件。
- 不修改官方 opencode 二进制，不破坏用户已有配置。

## 非目标

- 不做 TUI 硬编码字符串的完整汉化（官方暂不支持，需 fork 源码，后续单独立项）。
- 不修改 Termux 应用本身。
- 不覆盖用户已有的 `opencode.json` / `opencode.jsonc` / `tui.json` 内容。

## 方案

### 1. 触摸/输入法：默认关闭鼠标捕获

新增 `scripts/termux-mouse-default.sh`，由 `bin/opencode` 在启动时 source。

逻辑：

1. 如果用户已经显式设置了 `OPENCODE_DISABLE_MOUSE` 环境变量，则尊重用户设置。
2. 否则检查全局 `tui.json`（`${XDG_CONFIG_HOME:-$HOME/.config}/opencode/tui.json`）：
   - 若存在且显式包含 `"mouse": true`，则不导出变量，保持鼠标捕获开启。
   - 其余情况（无配置、`"mouse": false`、解析失败等）默认导出 `OPENCODE_DISABLE_MOUSE=1`。

### 2. 中文插件：安装时自动注册

在 `install.js` 完成运行时安装后，执行：

```bash
"$OPENCODE_DIR/opencode" plugin opencode-zh-plugin --global
```

说明：

- 该命令是幂等的，重复执行只会提示已配置，不会覆盖已有配置。
- 会同时更新全局 `opencode.json` 和 `tui.json`，加入 `opencode-zh-plugin`。
- 若插件安装失败（例如无网络），只输出警告，不阻塞 opencode 启动。

### 3. 文档

README 新增章节：

- Termux 触摸/输入法：说明默认关闭鼠标捕获的原因、如何重新开启（`tui.json` 中 `"mouse": true` 或设置 `OPENCODE_DISABLE_MOUSE=0`）。
- 中文模式：说明默认启用 `opencode-zh-plugin`、支持的范围、如何移除插件恢复英文。

## 测试

- 新增 `scripts/test-termux-mouse-default.sh`，覆盖：
  1. 无 `tui.json` → 导出 `OPENCODE_DISABLE_MOUSE=1`
  2. `tui.json` 为 `"mouse": true` → 不导出
  3. `tui.json` 为 `"mouse": false` → 导出 `OPENCODE_DISABLE_MOUSE=1`
  4. 用户已设置 `OPENCODE_DISABLE_MOUSE=0` → 保持不变
- 本地集成验证：
  1. 在临时 `XDG_CONFIG_HOME` 中执行 `opencode plugin opencode-zh-plugin --global`，确认配置被写入、TUI 出现中文。
  2. 用 `script` 捕获启动输出，确认默认不再发送 `?1000h` / `?1002h` / `?1003h` / `?1006h` 鼠标追踪序列。

## 风险与取舍

- 默认关闭鼠标捕获后，TUI 内需要鼠标/触摸点击的交互（按钮、链接等）在 Termux 下不可用；这是 Termux 唤起软键盘的已知取舍，用户可通过配置重新开启。
- 中文插件是部分汉化：首页、侧边栏标题、斜杠命令、AI 回复等可汉化；TUI 硬编码提示仍为英文。
- 自动注册插件会修改用户全局配置（仅追加插件条目），已通过幂等命令控制；README 会说明如何移除。

## 提交与推送

- 两个功能作为一次提交推送到 `origin/main`，提交信息示例：`feat: enable Termux touch/IME and zh-CN plugin by default`。
