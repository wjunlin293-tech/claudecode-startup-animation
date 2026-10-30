# 交接说明：给 Jeff 电脑上的 Claude Code

## Jeff 想要什么

环境是 Windows Terminal + Windows PowerShell 5.1。具体要求：

- 普通标签页保持黑色默认外观。
- 输入 `claude` 时：
  - 先播放透明覆盖层动画（Electron）：小角色拿马克笔把当前终端窗口涂成白板。
  - 然后在当前窗口新开一个 "Claude Whiteboard" 标签页（橙色），在当前目录启动 Claude Code。
  - 这个标签页的外观：白板背景、Whiteboard Mono 字体（框线是手绘的）、配色 Whiteboard Marker，可选像素着色器。
  - 退出 Claude Code 后，这个标签页自动关闭。

## 这个包

`setup.ps1` 合并并取代了旧的 `claude-only.ps1`、`install-intro.ps1`，重复运行是安全的。用户一般不直接运行它：一键安装入口是仓库根目录的 `install.ps1`（`irm ... | iex`，下载仓库 zip 后调用 `setup.ps1`）和 Mac 的 `install.sh`；装好后用 `claude-wb update | version | doctor | intro on/off | uninstall` 管理。

它依次做 7 步：

1. 为当前用户安装字体。
2. 把 `~/.whiteboard` 下的素材复制好，并生成 `claude-wb.ps1`。
3. 安装 Claude Code 主题和 statusLine。
4. 修改 Windows Terminal：
   - 清理 `profiles.defaults` 里旧版写进去的白板键。
   - 加入配色方案。
   - 重写 Claude Whiteboard 配置，GUID 为 `{7b1e5c2a-4d3f-4c8e-9a1b-3c5d7e9f0a12}`。`builtinGlyphs:false` **只**写在 `font` 对象里。
5. 安装动画到 `~/.whiteboard/intro/app`：
   - 动画运行环境（Electron）直接从官方 release 下载并校验 SHA-256，解压到 `~/.whiteboard/intro/electron`，**不需要 Node.js**；之前用 npm 装的 `node_modules` 版本仍然兼容。
   - 下载失败就跳过，`claude` 会直接开标签页。
6. 改写 `$PROFILE` 里 `# >>> whiteboard-claude >>>` 标记之间的内容：只有一行，加载 `~/.whiteboard/shell.ps1`（源文件是仓库的 `shell/whiteboard-claude.ps1`，里面是 `claude`、`claude-quick`、`claude-plain`、`claude-wb`）。同时把 `setup.ps1`、`check.ps1` 复制到 `~/.whiteboard/tools`，把来源和版本写进 `~/.whiteboard/install.json`。
7. 如果执行策略是 Restricted，把 CurrentUser 的策略设为 RemoteSigned。

`check.ps1` 是只读检查（`claude-wb doctor`）。`-Undo` 用来撤销（`claude-wb uninstall`）。装完 `setup.ps1` 会自动自检一次，只显示有问题的项。

注意：带中文输出的 `.ps1` 文件（`setup.ps1`、`check.ps1`、`shell/whiteboard-claude.ps1`）必须保存为 **UTF-8 带 BOM**，否则 Windows PowerShell 5.1 会按 ANSI 读成乱码；`install.ps1` 是直接 `irm | iex` 运行的，保持纯 ASCII。

## 已知风险

- 旧的 `claude-only.ps1` 会覆盖 `$PROFILE` 标记段，把动画去掉。所以不要再运行它，用 `setup.ps1`。
- 以下三项都只在 Linux 的 PowerShell 7 上用模拟路径测过，没在真实 Windows 上测过：
  - Windows PowerShell 5.1 下的运行情况
  - 动画覆盖层在不同 DPI 下能不能对齐
  - HLSL 着色器能不能编译
- 不要擅自添加或下载 Claude 官方吉祥物的图片。角色图由 Jeff 自己放进 `~/.whiteboard/characters`。

## 排错

| 现象 | 处理 |
|---|---|
| 输入 `claude` 后没开新标签页 | 运行 `claude-wb doctor`，看第 6 项和第 7 项 |
| 新标签页一闪就关 | 运行 `powershell -NoProfile -File "$HOME\.whiteboard\claude-wb.ps1"` 看报错，多半是 PATH 里找不到 claude |
| 框线还是直的 | 看 `check.ps1` 的 4e 项；Windows Terminal 需要 1.21 以上版本 |
| 着色器报错或文字发虚 | 运行 `setup.ps1 -NoShader` |
| 动画和窗口没对齐 | 设置环境变量 `CLAUDE_NO_INTRO=1` 临时关掉动画，或用 `claude-quick`，然后把现象告诉 Jeff |

遇到报错时请贴出原文，先排查，不要手改大段 JSON。
