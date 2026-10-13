# Claude Whiteboard 最终版（一个包装全部）

这个包代替之前的三个安装脚本：`install.ps1`、`claude-only.ps1`、`install-intro.ps1`。

装好后的效果：
- 平时的终端标签页保持黑色。
- 输入 `claude`：先播放马克笔动画，把终端涂成白板，再打开一个橙色的 **Claude Code** 白板标签页，工作目录就是你当前所在的文件夹。
- Claude Code 退出后，这个标签页会自动关闭。

## 包里有什么

| 文件 | 作用 |
|---|---|
| `setup.ps1` | 一键安装，重复运行也安全；改动前会先把原设置备份成 `.bak-时间` |
| `check.ps1` | 只做检查、不改任何东西，逐项显示是否已经装好 |
| `fonts/` | 手写风字体 Whiteboard Mono，框线是马克笔画的（OFL 授权） |
| `assets/` | 白板背景图、手抖滤镜 |
| `claude/` | Claude Code 主题、状态栏 |
| `intro/app/` | 启动动画程序（Electron） |
| `intro/intro-preview.mp4` | 动画演示 |
| `HANDOFF.md` | 交接说明，给你电脑上的 Claude Code 看 |

## 先检查已经装上了没有

1. 把 `claude-whiteboard.zip` 解压到桌面。
2. 打开 `claude-whiteboard` 文件夹，在空白处右键，选"在终端中打开"。
3. 运行：
   ```
   powershell -ExecutionPolicy Bypass -File .\check.ps1
   ```
4. 看结果：
   - 最后一行是 `All written in.`：全部装好了，什么都不用做。
   - 有红色的 `[FAIL]` 行：继续往下装。

## 安装（逐字照做）

1. 在同一个窗口运行：
   ```
   powershell -ExecutionPolicy Bypass -File .\setup.ps1
   ```
   - 不想要动画：在末尾加 `-NoIntro`
   - 觉得文字发虚：在末尾加 `-NoShader`
2. 等它显示 `7/7` 和 `Done.`。
   - 第一次装动画要下载大约 100MB，需要等一会儿。
   - 如果提示 `Node.js not found`，先运行 `winget install OpenJS.NodeJS.LTS`，新开一个终端，再重复第 1 步。
3. **关掉所有 Windows Terminal 窗口**，然后重新打开。
4. 回到这个文件夹，运行 `check.ps1` 检查，应该看到 `All written in.`。
5. `cd` 到任意项目文件夹，输入 `claude`。
6. 第一次进入 Claude Code 时，输入 `/theme`，选 **Whiteboard Marker**。

## 常用命令

| 命令 | 效果 |
|---|---|
| `claude` | 播放动画，然后打开白板标签页 |
| `claude-quick` | 不播动画，直接打开白板标签页 |
| `claude-plain` | 在当前标签页运行，不换外观 |
| 动画播放时按 Esc | 跳过动画 |

## 换成你自己的角色图

- 把图片放进 `%USERPROFILE%\.whiteboard\characters\`，放一张就够了。
- 建议用透明背景的 PNG，512×512 左右。
- 不需要重新安装，下次运行 `claude` 就会用上。

动画的参数（流动代码的透明度、速度、要不要画爱心）在 `%USERPROFILE%\.whiteboard\intro-config.json` 里改。

## 撤销

```
powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Undo
```

这会删掉白板配置、配色、动画和 `claude` 函数。字体和主题文件会留下，它们不影响其他东西。

## 注意

**不要再运行旧包里的 `claude-only.ps1`**。它会把 `claude` 命令改回没有动画的旧版本。
