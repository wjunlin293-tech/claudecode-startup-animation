# Jeff 定稿版改动（相对原 claude-whiteboard.zip）

这个包 = 原包 + 下面几处改动，其余文件完全一致。

1. 小人：intro\app\characters 里的 4 张图全部换成橙色小怪物（透明背景、眼睛实心黑）。
2. setup.ps1：Windows Terminal 配置的字体改成 "Whiteboard Mono, Cascadia Mono"，font.builtinGlyphs 改成 true。
   原因：Whiteboard Mono 没有方块字符，Claude Code 的吉祥物是方块拼的，用字体画会变形、露缝；用终端自带方块才干净。
   代价：输入框的横线是直线，不是手绘的。
3. check.ps1：4d / 4e 的判断跟着改（4e 现在要求 builtinGlyphs=true）。
4. assets\whiteboard.hlsl：晕染 BLEED=0、手抖 WOBBLE_PX=0，只保留纸张颗粒。

注意：这些调整在 Jeff 的电脑上看过效果；原包 HANDOFF.md 里"未在真实 Windows 上测过"的几项（不同缩放比例、着色器编译）这个包同样没有额外验证。
