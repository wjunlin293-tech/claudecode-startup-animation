# Claude Whiteboard - FINAL all-in-one setup (replaces install.ps1 + claude-only.ps1 + install-intro.ps1)
#  - normal Windows Terminal tabs stay dark
#  - typing `claude` plays the marker intro, then opens an orange "Claude Whiteboard" tab in the current folder
# Usage (from this folder):
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1              full install (safe to run again)
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1 -NoIntro     no animation, just the whiteboard tab
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1 -NoShader    no wobble/grain filter
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Undo        remove profile, scheme, intro, claude function
param([switch]$NoIntro, [switch]$NoShader, [switch]$Undo)
$ErrorActionPreference = "Stop"
$here  = Split-Path -Parent $MyInvocation.MyCommand.Path
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
    Say "1/7 fonts installed"

# ======================= 2. assets + launcher =======================
    New-Item -ItemType Directory -Force -Path $wbDir | Out-Null
    Copy-Item (Join-Path $here "assets\whiteboard-bg.png") $wbDir -Force
    Copy-Item (Join-Path $here "assets\whiteboard.hlsl")   $wbDir -Force
    $launcherText = "`$Host.UI.RawUI.WindowTitle = `"Claude Code`"`r`n& claude @args`r`n"
    [IO.File]::WriteAllText($launcher, $launcherText, $utf8)
    Say "2/7 background, filter and launcher copied to $wbDir"

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
    Say "3/7 Claude Code theme + status line installed"
}

# ======================= 4. Windows Terminal =======================
$wtCandidates = @(
    (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"),
    (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"),
    (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json")
)
$wt = $wtCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $wt) { throw "Windows Terminal settings.json not found. Install Windows Terminal from the Microsoft Store, open it once, then run this again." }
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
Say "4/7 Windows Terminal: normal tabs default, profile '$profName' $(if ($Undo) {'removed'} else {'written'}) (backup .bak-$stamp)"

# ======================= 5. intro animation =======================
$introOk = $false
$exe = Join-Path $introDest "app\node_modules\electron\dist\electron.exe"
if ($Undo) {
    Get-Process electron -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$introDest*" } | Stop-Process -Force
    if (Test-Path $introDest) { Remove-Item $introDest -Recurse -Force -ErrorAction SilentlyContinue }
    Say "5/7 intro removed"
} elseif ($NoIntro) {
    Say "5/7 intro skipped (-NoIntro)"
} else {
    $src = Join-Path $here "intro\app"
    $appDest = Join-Path $introDest "app"
    Get-Process electron -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$introDest*" } | Stop-Process -Force
    New-Item -ItemType Directory -Force -Path $appDest | Out-Null
    # copy/refresh app files, keep an existing node_modules (no re-download)
    Get-ChildItem $src | ForEach-Object { Copy-Item $_.FullName $appDest -Recurse -Force }
    if (Test-Path $exe) {
        $introOk = $true
        Say "5/7 intro updated (Electron runtime already present)"
    } elseif (Get-Command npm -ErrorAction SilentlyContinue) {
        Push-Location $appDest
        try {
            Say "5/7 downloading the Electron runtime (about 100 MB, one time)..."
            & npm install --no-audit --no-fund --loglevel=error
        } finally { Pop-Location }
        if (Test-Path $exe) { $introOk = $true; Say "5/7 intro installed" }
        else { Say "5/7 WARNING: npm install did not produce electron.exe - 'claude' will open the tab without the intro" }
    } else {
        Say "5/7 WARNING: Node.js not found, intro skipped. To add it: winget install OpenJS.NodeJS.LTS, open a new terminal, run setup.ps1 again"
    }
    $charDir = Join-Path $wbDir "characters"
    New-Item -ItemType Directory -Force -Path $charDir | Out-Null
    $cfg = Join-Path $wbDir "intro-config.json"
    if (-not (Test-Path $cfg)) {
        [IO.File]::WriteAllText($cfg, "{`r`n  `"codeOpacity`": 0.28,`r`n  `"speed`": 1,`r`n  `"showHeart`": true`r`n}`r`n", $utf8)
    }
}

# ======================= 6. PowerShell profile: claude / claude-quick / claude-plain =======================
$begin = "# >>> whiteboard-claude >>>"
$end   = "# <<< whiteboard-claude <<<"
$block = @"
$begin
function Get-WbTerminalRect {
    if (-not ('WbWin' -as [type])) {
        Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public static class WbWin {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr hwnd, int attr, out RECT rect, int size);
}
'@
    }
    `$h = [WbWin]::GetForegroundWindow()
    `$r = New-Object WbWin+RECT
    if ([WbWin]::DwmGetWindowAttribute(`$h, 9, [ref]`$r, [Runtime.InteropServices.Marshal]::SizeOf(`$r)) -ne 0) { [void][WbWin]::GetWindowRect(`$h, [ref]`$r) }
    `$w = `$r.Right - `$r.Left; `$hgt = `$r.Bottom - `$r.Top
    if (`$w -lt 200 -or `$hgt -lt 150) { return `$null }
    return "{0},{1},{2},{3}" -f `$r.Left, `$r.Top, `$w, `$hgt
}
function Get-WbTabArgs([object[]]`$extra) {
    `$dir = (Get-Location).ProviderPath
    if (`$dir.EndsWith('\')) { `$dir = `$dir + '.' }
    return @('-w', '0', 'nt', '-p', '$profName', '-d', `$dir,
        'powershell.exe', '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', '$launcher') + `$extra
}
function claude {
    if (-not `$env:WT_SESSION) { claude-plain @args; return }
    `$tabArgs = Get-WbTabArgs `$args
    `$appDir = Join-Path `$HOME '.whiteboard\intro\app'
    `$intro = Join-Path `$appDir 'node_modules\electron\dist\electron.exe'
    `$rect = `$null
    if ((Test-Path `$intro) -and -not `$env:CLAUDE_NO_INTRO) { try { `$rect = Get-WbTerminalRect } catch { `$rect = `$null } }
    if (`$rect) { & `$intro `$appDir "--rect=`$rect" '--wt' @tabArgs }
    else { & wt.exe @tabArgs }
}
function claude-quick {
    if (-not `$env:WT_SESSION) { claude-plain @args; return }
    `$tabArgs = Get-WbTabArgs `$args
    & wt.exe @tabArgs
}
function claude-plain {
    `$real = Get-Command claude -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not `$real) { Write-Host "claude (Claude Code) not found on PATH"; return }
    & `$real.Source @args
}
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
Say "6/7 PowerShell profile $(if ($Undo) {'cleaned'} else {'updated'}): $profPath"

# ======================= 7. execution policy (so the profile loads) =======================
if (-not $Undo -and (Get-ExecutionPolicy) -eq "Restricted") {
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
    Say "7/7 execution policy for current user set to RemoteSigned"
} else { Say "7/7 execution policy OK ($(Get-ExecutionPolicy))" }

if ($Undo) {
    Say "Undone. Fonts and the Claude theme file are kept (harmless). Close ALL Windows Terminal windows and reopen."
} else {
    Say "Done. Intro: $(if ($introOk) {'ON'} else {'OFF'}). Close ALL Windows Terminal windows, reopen, then run:  powershell -ExecutionPolicy Bypass -File .\check.ps1"
}
