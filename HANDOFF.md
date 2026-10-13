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

`setup.ps1` 合并并取代了旧的 `install.ps1`、`claude-only.ps1`、`install-intro.ps1`，重复运行是安全的。

它依次做 7 步：

1. 为当前用户安装字体。
2. 把 `~/.whiteboard` 下的素材复制好，并生成 `claude-wb.ps1`。
3. 安装 Claude Code 主题和 statusLine。
4. 修改 Windows Terminal：
   - 清理 `profiles.defaults` 里旧版写进去的白板键。
   - 加入配色方案。
   - 重写 Claude Whiteboard 配置，GUID 为 `{7b1e5c2a-4d3f-4c8e-9a1b-3c5d7e9f0a12}`。`builtinGlyphs:false` **只**写在 `font` 对象里。
5. 安装动画到 `~/.whiteboard/intro/app`：
   - 已有 `node_modules` 的就保留，不重新下载。
   - 没有 Node 就跳过，`claude` 会直接开标签页。
6. 改写 `$PROFILE` 里 `# >>> whiteboard-claude >>>` 标记之间的内容，包含 `claude`（带动画）、`claude-quick`、`claude-plain` 三个函数。
7. 如果执行策略是 Restricted，把 CurrentUser 的策略设为 RemoteSigned。

`check.ps1` 是只读检查。`-Undo` 用来撤销。

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
| 输入 `claude` 后没开新标签页 | 运行 `check.ps1`，看第 6 项和第 7 项 |
| 新标签页一闪就关 | 运行 `powershell -NoProfile -File "$HOME\.whiteboard\claude-wb.ps1"` 看报错，多半是 PATH 里找不到 claude |
| 框线还是直的 | 看 `check.ps1` 的 4e 项；Windows Terminal 需要 1.21 以上版本 |
| 着色器报错或文字发虚 | 运行 `setup.ps1 -NoShader` |
| 动画和窗口没对齐 | 设置环境变量 `CLAUDE_NO_INTRO=1` 临时关掉动画，或用 `claude-quick`，然后把现象告诉 Jeff |

遇到报错时请贴出原文，先排查，不要手改大段 JSON。
