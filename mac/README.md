# Claude Whiteboard · macOS 版（Terminal.app）

> **状态：未在真实 Mac 上验证过。** 这套脚本是在 Windows 上写的，只做了语法检查。第一次在 Mac 上跑请当作测试，出问题把现象（或终端里的报错）贴出来。

效果和 Windows 版一致：平时的终端不变；在 **Terminal.app** 里输入 `claude`，先播马克笔动画把终端涂成白板，再在原窗口的位置新开一个白板配色的 **Claude Code** 窗口，工作目录就是你当前所在的文件夹；退出 Claude Code 后这个窗口自动关闭，原来的窗口还在。动画里画的欢迎框、输入框和文字大小，会按你这台 Mac 上终端的实际字体、字号和行列数来摆（运行时实时测量，不同 Mac 设置不同也能对上）。

## 和 Windows 版的区别

| | Windows | macOS（Terminal.app） |
|---|---|---|
| 白板背景纸纹、手抖 / 颗粒滤镜 | 有 | **没有**（Terminal.app 不支持背景图和着色器），只有白板底色 + 配色 + 手绘字体 |
| 橙色标签页颜色 | 有 | 没有（Terminal.app 不能给单个窗口上色）；Mac 版是新开一个窗口，不是标签页 |
| 方块 / 框线 | 终端自带 | 字体里没有方块字符，会回退到系统字体；Claude 吉祥物是否清晰要看实际效果 |
| 动画里画的橙色标签页 | 对齐 | Terminal.app 的标签栏位置不同，会有一点偏差 |

## 前提

- macOS + 自带的 **Terminal.app**，默认 shell 是 zsh；已安装 Claude Code。
- 不需要 Node.js / git / Homebrew / sudo。动画运行环境会自动下载并校验。

## 安装（一行）

```bash
curl -fsSL https://raw.githubusercontent.com/wjunlin293-tech/claudecode-startup-animation/main/install.sh | bash && exec zsh
```

命令末尾的 `exec zsh` 会让当前窗口立刻加载新命令。`cd` 到项目，输入 `claude`。如果没带 `&& exec zsh`，装完请输入 `exec zsh` 或新开一个标签页，否则会提示 `command not found: claude-wb`。

- 安装过程中会弹出一个新的 Terminal 窗口，那是在导入 **Claude Whiteboard** 配置，关掉它就行。
- 第一次会弹出"想要控制 Terminal"的授权，点 **好**。如果之前点过"不允许"：系统设置 → 隐私与安全性 → 自动化，把 Terminal / Electron 对 Terminal 的开关打开。
- 只有白板窗口里启动的 Claude Code 会用 **Whiteboard Marker** 主题（启动时带 `--settings` 指定，不改你的全局设置）。状态栏脚本是 Windows 专用的，Mac 版没装。
- 不想联网跑脚本：下载**整个仓库**（不能只下 `mac/`，字体在上一级）后运行 `bash mac/setup.sh`；不要动画加 `--no-intro`。

## 日常管理

输入 `claude-wb`：`update`（更新）、`version`、`doctor`（自检）、`intro on|off`、`uninstall`（卸载）。

## 常用命令

| 命令 | 效果 |
|---|---|
| `claude` | 播放动画，然后打开白板标签页 |
| `claude-quick` | 不播动画，直接开白板标签页 |
| `claude-wb` | 管理：更新 / 版本 / 自检 / 开关动画 / 卸载 |
| `claude-plain` | 在当前标签页运行，不换外观 |
| `CLAUDE_NO_INTRO=1 claude` | 这一次不播动画 |
| `CLAUDE_INTRO_FREEZE=10.4 claude` | 调试：动画停在第 10.4 秒，盖在真实窗口上方便对比尺寸，按 Esc 退出 |
| 动画播放时按 Esc，或点右上角的“跳过 Skip” | 立刻跳过，白板标签页照样会打开（Mac 版仍是动画退出后才开窗口，所以跳过后还要等窗口和 Claude 启动） |

只有在 **Terminal.app** 里这些命令才会开白板标签页；在 iTerm2、VS Code 等其他终端里，`claude` 会原地运行。

## 动画跟着窗口走

动画播放期间拖动 Terminal 窗口，动画会一起移动；改变窗口大小，动画会按新的行列数重新排版，并从当前这一刻接着播。升级后输入 `claude-wb update` 即可。

## 检查

```
claude-wb doctor
```
只读，不改任何东西，逐项显示是否装好（也可以直接运行 `bash mac/check.sh`）。

## 换成你自己的角色图

放到 `~/.whiteboard/characters/`，一张就够（透明背景 PNG，512×512 左右）。不放的话用仓库里自带的那只橙色小怪物。

## 排错

| 现象 | 处理 |
|---|---|
| 输入 `claude` 没反应 | 新开一个标签页（旧标签页还是旧的命令）；运行 `bash mac/check.sh` |
| 动画播了，但没有开白板标签页 | 多半是"自动化"授权被拒，见上面的授权说明 |
| 没有动画，直接开了标签页 | 动画运行环境没下载成功（多半是网络）：联网后重新运行一键安装命令 |
| 白板窗口不是白底（还是系统的颜色） | 重新运行一键安装命令（它会用 Terminal 自己的接口把背景色、文字色、字体设上）；再用 `claude-wb doctor` 看 3b 项 |
| 标签页不是白底 | `check.sh` 的第 3 项；在 Terminal → 设置 → 描述文件里看有没有 Claude Whiteboard，没有就双击 `mac/terminal/Claude-Whiteboard.terminal` |
| 吉祥物显示得很怪 | Terminal → 设置 → 描述文件 → Claude Whiteboard → 文本，把字体换成 Menlo 或 SF Mono，框线会变成系统的 |
| 动画画的框和真实窗口差一点 | 改 `~/.whiteboard/intro-config.json` 里的 `"gridDy"`（单位是行，默认 0；负数上移、正数下移，如 `-0.5`、`1`），再用 `CLAUDE_INTRO_FREEZE=10.4 claude` 对照红色网格 |
| 动画和窗口还是没对齐 | `CLAUDE_NO_INTRO=1 claude` 先跳过动画，并把现象告诉我 |

## 卸载

```
claude-wb uninstall
```
会清掉 `~/.zshrc` 里的钩子并删除动画程序（如果早先的版本改过全局主题，也一并还原）。字体和 Terminal 配置会留下，不影响别的东西。想删配置：Terminal → 设置 → 描述文件 → Claude Whiteboard → 点 `-`。
