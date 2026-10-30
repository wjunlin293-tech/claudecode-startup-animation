# Claude Whiteboard - all-in-one setup.  Easiest way to run it: the one-line installer, see README.md
#  - normal Windows Terminal tabs stay dark
#  - typing `claude` plays the marker intro, then opens an orange "Claude Whiteboard" tab in the current folder
#  - needs NO Node.js: the animation runtime (Electron) is downloaded and checksum-verified here
# Usage (from this folder, or just double-click install.cmd):
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1              full install / update (safe to run again)
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1 -NoIntro     no animation, just the whiteboard tab
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1 -NoShader    no wobble/grain filter
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Undo        remove profile, scheme, intro, claude function
param([switch]$NoIntro, [switch]$NoShader, [switch]$Undo)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # the progress bar makes Windows PowerShell 5.1 downloads many times slower
trap {
    Write-Host ""
    Write-Host "[whiteboard] 出错了: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[whiteboard] 改动过的文件都已备份成 .bak-时间。重新运行一次通常就好；还不行，把这段报错原文发给我。" -ForegroundColor Red
    exit 1
}
$here  = Split-Path -Parent $MyInvocation.MyCommand.Path
$version = "?"
try { $version = ([IO.File]::ReadAllText((Join-Path $here "VERSION"))).Trim() } catch {}
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$utf8  = New-Object System.Text.UTF8Encoding($false)
function Say($m) { Write-Host "[whiteboard] $m" }

$wbDir      = Join-Path $HOME ".whiteboard"
$bgPath     = Join-Path $wbDir "whiteboard-bg.png"
$shaderPath = Join-Path $wbDir "whiteboard.hlsl"
$launcher   = Join-Path $wbDir "claude-wb.ps1"
$introDest  = Join-Path $wbDir "intro"
$profGuid   = "{7b1e5c2a-4d3f-4c8e-9a1b-3c5d7e9f0a12}"
$profName   = "Claude Whiteboard"
$schemeName = "Whiteboard Marker"

# ======================= 1. fonts (per user, no admin) =======================
if (-not $Undo) {
    $fontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
    $reg = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
    if (-not (Test-Path $reg)) { New-Item -Path $reg -Force | Out-Null }
    foreach ($f in @(@{file="WhiteboardMono-Regular.ttf"; name="Whiteboard Mono Regular (TrueType)"},
                     @{file="WhiteboardMono-Bold.ttf";    name="Whiteboard Mono Bold (TrueType)"})) {
        $dst = Join-Path $fontDir $f.file
        try { Copy-Item (Join-Path $here "fonts\$($f.file)") $dst -Force }
        catch { Say "font $($f.file) is in use, keeping the installed copy" }
        New-ItemProperty -Path $reg -Name $f.name -Value $dst -PropertyType String -Force | Out-Null
    }
    Say "1/7 字体已安装"

# ======================= 2. assets + launcher =======================
    New-Item -ItemType Directory -Force -Path $wbDir | Out-Null
    Copy-Item (Join-Path $here "assets\whiteboard-bg.png") $wbDir -Force
    Copy-Item (Join-Path $here "assets\whiteboard.hlsl")   $wbDir -Force
    # the shell functions (claude, claude-wb ...) live in their own file, so an update never has to rewrite $PROFILE
    Copy-Item (Join-Path $here "shell\whiteboard-claude.ps1") (Join-Path $wbDir "shell.ps1") -Force
    # keep setup/check around, so `claude-wb doctor` and `claude-wb uninstall` work without the download folder
    $toolsDir = Join-Path $wbDir "tools"
    New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
    foreach ($t in @("setup.ps1", "check.ps1")) {
        $from = Join-Path $here $t; $to = Join-Path $toolsDir $t
        if ((Test-Path $from) -and ($from -ne $to)) { Copy-Item $from $to -Force }
    }
    $repoId = if ($env:CLAUDE_WB_REPO) { $env:CLAUDE_WB_REPO } else { "wjunlin293-tech/claudecode-startup-animation" }
    $refId  = if ($env:CLAUDE_WB_REF)  { $env:CLAUDE_WB_REF }  else { "main" }
    # channel "latest" = `claude-wb update` takes the newest GitHub Release; "pinned" = keeps following $refId (a branch / tag)
    $chanId = if ($env:CLAUDE_WB_CHANNEL) { $env:CLAUDE_WB_CHANNEL } else { "latest" }
    [IO.File]::WriteAllText((Join-Path $wbDir "install.json"), ([ordered]@{ repo = $repoId; ref = $refId; channel = $chanId; version = $version; installedAt = (Get-Date -Format "s") } | ConvertTo-Json), $utf8)
    $launcherText = "`$Host.UI.RawUI.WindowTitle = `"Claude Code`"`r`n& claude @args`r`n"
    [IO.File]::WriteAllText($launcher, $launcherText, $utf8)
    Say "2/7 背景图、滤镜、启动脚本已放到 $wbDir"

# ======================= 3. Claude Code theme + status line =======================
    $claudeDir = Join-Path $HOME ".claude"
    New-Item -ItemType Directory -Force -Path (Join-Path $claudeDir "themes") | Out-Null
    Copy-Item (Join-Path $here "claude\whiteboard.json") (Join-Path $claudeDir "themes\whiteboard.json") -Force
    Copy-Item (Join-Path $here "claude\statusline.ps1")  (Join-Path $claudeDir "statusline.ps1") -Force
    $settingsPath = Join-Path $claudeDir "settings.json"
    $settings = New-Object PSObject
    if (Test-Path $settingsPath) {
        Copy-Item $settingsPath "$settingsPath.bak-$stamp"
        $raw = [IO.File]::ReadAllText($settingsPath)
        if ($raw.Trim()) { $settings = $raw | ConvertFrom-Json }
    }
    $status = [PSCustomObject]@{ type = "command"; command = "powershell -NoProfile -ExecutionPolicy Bypass -File ~/.claude/statusline.ps1"; padding = 1 }
    $settings | Add-Member -NotePropertyName statusLine -NotePropertyValue $status -Force
    [IO.File]::WriteAllText($settingsPath, ($settings | ConvertTo-Json -Depth 32), $utf8)
    Say "3/7 Claude Code 主题和状态栏已安装"
}

# ======================= 4. Windows Terminal =======================
$wtCandidates = @(
    (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"),
    (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"),
    (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json")
)
$wt = $wtCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $wt) { throw "没找到 Windows Terminal 的设置文件。请先在微软商店安装 Windows Terminal（Windows 11 自带），打开它一次，然后重新运行这个安装命令。" }
$text  = [IO.File]::ReadAllText($wt)
$clean = ($text -split "`n" | Where-Object { $_.TrimStart() -notlike "//*" }) -join "`n"
$j = $clean | ConvertFrom-Json
Copy-Item $wt "$wt.bak-$stamp"

# 4a. scheme
$schemes = @($j.schemes | Where-Object { $_.name -ne $schemeName })
if (-not $Undo) {
    $schemes += [PSCustomObject][ordered]@{
        name = $schemeName; background = "#ECEEEB"; foreground = "#222222"
        cursorColor = "#E5653C"; selectionBackground = "#FFE873"
        black = "#222222"; red = "#E5484D"; green = "#30A46C"; yellow = "#C98A00"
        blue = "#2F6FED"; purple = "#8E4EC6"; cyan = "#0E8A8A"; white = "#8A8F88"
        brightBlack = "#6B6F69"; brightRed = "#F2555A"; brightGreen = "#3DB87A"; brightYellow = "#E5A50A"
        brightBlue = "#4C82F7"; brightPurple = "#A363D9"; brightCyan = "#12A5A5"; brightWhite = "#F7F8F6"
    }
}
$j | Add-Member -NotePropertyName schemes -NotePropertyValue $schemes -Force

# 4b. normal tabs back to dark: remove any whiteboard keys an older install put in profiles.defaults
$d = $j.profiles.defaults
if ($d) {
    foreach ($k in @($d.PSObject.Properties | ForEach-Object { $_.Name })) {
        $v = $d.$k; $ours = $false
        switch ($k) {
            "colorScheme"                  { $ours = ($v -eq $schemeName) }
            "font"                         { $ours = ("$($v.face)" -like "Whiteboard Mono*") }
            "builtinGlyphs"                { $ours = $true }
            "backgroundImage"              { $ours = ("$v" -like "*whiteboard*") }
            "backgroundImageStretchMode"   { $ours = ("$v" -eq "uniformToFill") }
            "backgroundImageOpacity"       { $ours = $true }
            "experimental.pixelShaderPath" { $ours = ("$v" -like "*whiteboard*") }
            "cursorShape"                  { $ours = ($v -eq "bar") }
            "padding"                      { $ours = ("$v" -eq "18") }
            "intenseTextStyle"             { $ours = ($v -eq "bold") }
            "useAcrylic"                   { $ours = ($v -eq $false) }
        }
        if ($ours) { $d.PSObject.Properties.Remove($k) }
    }
}

# 4c. the Claude Whiteboard profile (only this profile gets the look)
$list = @($j.profiles.list | Where-Object { $_.name -ne $profName -and $_.guid -ne $profGuid })
if (-not $Undo) {
    $p = [ordered]@{
        guid = $profGuid
        name = $profName
        commandline = "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$launcher`""
        startingDirectory = "%USERPROFILE%"
        hidden = $false
        tabTitle = "Claude Code"
        suppressApplicationTitle = $true
        tabColor = "#E5653C"
        closeOnExit = "graceful"
        colorScheme = $schemeName
        font = [ordered]@{ face = "Whiteboard Mono, Cascadia Mono"; size = 13; features = [ordered]@{ calt = 1 }; builtinGlyphs = $true }
        backgroundImage = $bgPath
        backgroundImageStretchMode = "uniformToFill"
        backgroundImageOpacity = 1.0
        cursorShape = "bar"
        padding = "18"
        useAcrylic = $false
        intenseTextStyle = "bold"
    }
    if (-not $NoShader) { $p["experimental.pixelShaderPath"] = $shaderPath }
    $list += [PSCustomObject]$p
}
$j.profiles | Add-Member -NotePropertyName list -NotePropertyValue $list -Force
[IO.File]::WriteAllText($wt, ($j | ConvertTo-Json -Depth 32), $utf8)
Say "4/7 Windows Terminal: 普通标签页保持原样，'$profName' 配置已$(if ($Undo) {'移除'} else {'写入'})（备份 .bak-$stamp）"

# ======================= 5. intro animation =======================
# The animation runtime (Electron) is downloaded straight from the official release and checked against its
# published SHA-256 - no Node.js / npm needed. Older npm-based installs keep working.
function Install-WbElectron([string]$dest) {
    $ver  = "33.2.1"
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64" -or $env:PROCESSOR_ARCHITEW6432 -eq "ARM64") { "arm64" } else { "x64" }
    $exeP = Join-Path $dest "electron.exe"
    $verF = Join-Path $dest "version"
    if ((Test-Path $exeP) -and (Test-Path $verF) -and (([IO.File]::ReadAllText($verF)).Trim() -eq $ver)) { return $true }
    $name = "electron-v$ver-win32-$arch.zip"
    $base = "https://github.com/electron/electron/releases/download/v$ver"
    $zip  = Join-Path ([IO.Path]::GetTempPath()) $name
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Say "5/7 正在下载动画运行环境（约 100 MB，只需要这一次）..."
        Invoke-WebRequest -UseBasicParsing "$base/$name" -OutFile $zip
        $sums = Invoke-WebRequest -UseBasicParsing "$base/SHASUMS256.txt"
        $text = if ($sums.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($sums.Content) } else { [string]$sums.Content }
        $line = $text -split "`n" | Where-Object { $_ -match ("(^|[ *])" + [regex]::Escape($name) + "\s*$") } | Select-Object -First 1
        if (-not $line) { throw "官方校验文件里没有 $name" }
        $want = ($line.Trim() -split "\s+")[0].ToLower()
        $got  = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
        if ($got -ne $want) { throw "下载文件的校验值对不上（下载损坏或被篡改）" }
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $dest)
        return (Test-Path $exeP)
    } catch {
        Say "5/7 下载动画运行环境失败：$($_.Exception.Message)"
        return $false
    } finally { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
}

$introOk = $false
$electronDir = Join-Path $introDest "electron"
$oldExe = Join-Path $introDest "app\node_modules\electron\dist\electron.exe"
if ($Undo) {
    Get-Process electron -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$introDest*" } | Stop-Process -Force
    if (Test-Path $introDest) { Remove-Item $introDest -Recurse -Force -ErrorAction SilentlyContinue }
    Say "5/7 启动动画已移除"
} elseif ($NoIntro) {
    Say "5/7 跳过启动动画 (-NoIntro)"
} else {
    $src = Join-Path $here "intro\app"
    $appDest = Join-Path $introDest "app"
    Get-Process electron -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$introDest*" } | Stop-Process -Force
    New-Item -ItemType Directory -Force -Path $appDest | Out-Null
    # copy/refresh app files (an older install's node_modules is left alone)
    Get-ChildItem $src | ForEach-Object { Copy-Item $_.FullName $appDest -Recurse -Force }
    if (Install-WbElectron $electronDir) {
        $introOk = $true
        Say "5/7 启动动画已就绪"
    } elseif (Test-Path $oldExe) {
        $introOk = $true
        Say "5/7 启动动画已更新（继续用之前装好的运行环境）"
    } else {
        Say "5/7 提示：没装上动画运行环境（多半是网络问题）。claude 仍然能用，只是没有开场动画；联网后重新运行安装命令即可补上。"
    }
    $charDir = Join-Path $wbDir "characters"
    New-Item -ItemType Directory -Force -Path $charDir | Out-Null
    $cfg = Join-Path $wbDir "intro-config.json"
    if (-not (Test-Path $cfg)) {
        [IO.File]::WriteAllText($cfg, "{`r`n  `"codeOpacity`": 0.28,`r`n  `"speed`": 1,`r`n  `"showHeart`": true`r`n}`r`n", $utf8)
    }
}

# ======================= 6. PowerShell profile: loads ~/.whiteboard/shell.ps1 =======================
# $PROFILE only gets a 3-line block; the functions (claude, claude-quick, claude-plain, claude-wb) live in shell.ps1
$begin = "# >>> whiteboard-claude >>>"
$end   = "# <<< whiteboard-claude <<<"
$block = @"
$begin
if (Test-Path "`$HOME\.whiteboard\shell.ps1") { . "`$HOME\.whiteboard\shell.ps1" }
$end
"@
$profPath = $PROFILE
New-Item -ItemType Directory -Force -Path (Split-Path $profPath) | Out-Null
$old = ""
if (Test-Path $profPath) { $old = [IO.File]::ReadAllText($profPath); Copy-Item $profPath "$profPath.bak-$stamp" }
$pattern = "(?s)\r?\n?" + [regex]::Escape($begin) + ".*?" + [regex]::Escape($end) + "\r?\n?"
$new = [regex]::Replace($old, $pattern, "`r`n")
if (-not $Undo) { $new = $new.TrimEnd() + "`r`n`r`n" + $block + "`r`n" }
[IO.File]::WriteAllText($profPath, $new, (New-Object System.Text.UTF8Encoding($true)))
if ($Undo) { Remove-Item (Join-Path $wbDir "shell.ps1") -Force -ErrorAction SilentlyContinue }
Say "6/7 PowerShell 配置已$(if ($Undo) {'清理'} else {'更新'}): $profPath"

# ======================= 7. execution policy (so the profile loads) =======================
if (-not $Undo -and (Get-ExecutionPolicy) -eq "Restricted") {
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
    Say "7/7 已把当前用户的脚本执行策略设为 RemoteSigned（不然 PowerShell 不会加载 claude 命令）"
} else { Say "7/7 脚本执行策略正常 ($(Get-ExecutionPolicy))" }

if ($Undo) {
    Say "已卸载。字体和 Claude 主题文件保留（不影响别的东西）。重新打开 Windows Terminal 标签页即可。想装回来：重新运行一键安装命令。"
    return
}

# ======================= final self-check: show only what is wrong =======================
Say "正在自检 ..."
$ErrorActionPreference = "Continue"
$report = & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $wbDir "tools\check.ps1") 2>&1 | ForEach-Object { "$_" }
$ErrorActionPreference = "Stop"
# 6b ("claude is the function in THIS window") is about the window the user types in, not about this installer process
$fails = @($report | Where-Object { $_ -match "\[FAIL\]" -and $_ -notmatch "\s6b\s" })
Write-Host ""
if ($fails.Count -eq 0) {
    Write-Host "全部装好了（版本 $version）。动画: $(if ($introOk) {'开'} else {'关'})。" -ForegroundColor Green
} else {
    Write-Host "装好了，但有 $($fails.Count) 项需要注意：" -ForegroundColor Yellow
    $fails | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
}
Write-Host ""
Write-Host "怎么用：" -ForegroundColor Cyan
Write-Host "  cd 到你的项目文件夹，输入  claude          （动画 + 白板窗口；动画里按 Esc 或点「跳过」）"
Write-Host "  日常管理：输入  claude-wb               （更新 / 自检 / 开关动画 / 卸载）"
Write-Host "  第一次进入 Claude Code 后输入 /theme，选 Whiteboard Marker。"
Write-Host "  如果这一行命令是在 Windows Terminal 里粘贴运行的，当前窗口已经能用 claude；否则请新开一个标签页。"
