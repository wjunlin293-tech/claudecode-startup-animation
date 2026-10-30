# Read-only check: is everything written in? Changes nothing.
# Usage: claude-wb doctor      (or: powershell -ExecutionPolicy Bypass -File .\check.ps1)
$ErrorActionPreference = "Continue"
$script:bad = 0
function Row($ok, $name, $hint) {
    if ($ok) { Write-Host ("[ OK ] " + $name) -ForegroundColor Green }
    else { $script:bad++; Write-Host ("[FAIL] " + $name + "  ->  " + $hint) -ForegroundColor Red }
}
$wbDir = Join-Path $HOME ".whiteboard"

# fonts
$fontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
Row (Test-Path (Join-Path $fontDir "WhiteboardMono-Regular.ttf")) "1 font Whiteboard Mono" "重新运行一键安装命令（README 第一段）"

# assets
Row ((Test-Path (Join-Path $wbDir "whiteboard-bg.png")) -and (Test-Path (Join-Path $wbDir "claude-wb.ps1"))) "2 background + launcher in ~/.whiteboard" "重新运行一键安装命令（README 第一段）"

# claude theme + statusline
$cs = Join-Path $HOME ".claude\settings.json"
$hasStatus = $false
if (Test-Path $cs) { $hasStatus = ([IO.File]::ReadAllText($cs) -match "statusline\.ps1") }
Row ((Test-Path (Join-Path $HOME ".claude\themes\whiteboard.json")) -and $hasStatus) "3 Claude Code theme + status line" "重新运行一键安装命令（README 第一段）"

# Windows Terminal
$wtCandidates = @(
    (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"),
    (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"),
    (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json")
)
$wt = $wtCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($wt) {
    $clean = ([IO.File]::ReadAllText($wt) -split "`n" | Where-Object { $_.TrimStart() -notlike "//*" }) -join "`n"
    $j = $clean | ConvertFrom-Json
    $d = $j.profiles.defaults
    $dirty = $d -and (($d.colorScheme -eq "Whiteboard Marker") -or ("$($d.font.face)" -like "Whiteboard Mono*") -or ("$($d.backgroundImage)" -like "*whiteboard*"))
    Row (-not $dirty) "4a normal tabs are NOT whiteboard (profiles.defaults clean)" "重新运行一键安装命令（README 第一段）"
    Row (@($j.schemes | Where-Object { $_.name -eq "Whiteboard Marker" }).Count -gt 0) "4b color scheme Whiteboard Marker" "重新运行一键安装命令（README 第一段）"
    $p = @($j.profiles.list | Where-Object { $_.name -eq "Claude Whiteboard" }) | Select-Object -First 1
    Row ($null -ne $p) "4c profile Claude Whiteboard" "重新运行一键安装命令（README 第一段）"
    if ($p) {
        Row ("$($p.font.face)" -like "Whiteboard Mono*") "4d profile font = Whiteboard Mono" "重新运行一键安装命令（README 第一段）"
        Row ($p.font.builtinGlyphs -eq $true) "4e builtinGlyphs=true inside font (crisp mascot)" "重新运行一键安装命令（README 第一段）"
    }
} else { Row $false "4 Windows Terminal settings.json" "install Windows Terminal, open it once" }

# intro
$exe = Join-Path $wbDir "intro\electron\electron.exe"
$oldExe = Join-Path $wbDir "intro\app\node_modules\electron\dist\electron.exe"
if ((Test-Path $exe) -or (Test-Path $oldExe)) { Row $true "5 intro animation installed" "" }
else { Write-Host "[ -- ] 5 intro animation not installed (optional; needs internet once: re-run the one-line installer)" -ForegroundColor Yellow }
$chars = @(Get-ChildItem (Join-Path $wbDir "characters") -Include *.png,*.webp,*.gif,*.jpg -Recurse -ErrorAction SilentlyContinue)
Write-Host ("[info] your character pictures: " + $chars.Count + "  (" + (Join-Path $wbDir "characters") + ")")

# profile + function
$profOk = (Test-Path $PROFILE) -and ([IO.File]::ReadAllText($PROFILE) -match "whiteboard-claude")
Row $profOk "6 PowerShell profile block" "重新运行一键安装命令（README 第一段）"
$shellFile = Join-Path $wbDir "shell.ps1"
Row (Test-Path $shellFile) "6a ~/.whiteboard/shell.ps1 (claude / claude-wb functions)" "重新运行一键安装命令（README 第一段）"
$cmd = Get-Command claude -ErrorAction SilentlyContinue
Row ($cmd -and $cmd.CommandType -eq "Function") "6b 'claude' is the whiteboard function in THIS window" "open a NEW terminal tab (old tabs keep the old command)"
$shellText = ""; if (Test-Path $shellFile) { $shellText = [IO.File]::ReadAllText($shellFile) }
Row (($shellText -match "Get-WbTerminalRect") -and ($shellText -match "claude-wb")) "6c shell.ps1 is the current version (intro + claude-wb)" "重新运行一键安装命令（旧的 claude-only.ps1 会把它改回去，别再用）"
$real = Get-Command claude -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
Row ($null -ne $real) "6d real Claude Code found on PATH" "先安装 Claude Code（官方文档 https://code.claude.com/docs ），再重新运行 claude-wb doctor"

# policy
Row ((Get-ExecutionPolicy) -ne "Restricted") "7 execution policy lets the profile load" "重新运行一键安装命令（README 第一段）"

Write-Host ""
if ($script:bad -eq 0) { Write-Host "All written in." -ForegroundColor Green } else { Write-Host "$($script:bad) item(s) missing - see FAIL lines." -ForegroundColor Red }
