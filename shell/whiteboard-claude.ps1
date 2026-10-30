# Claude Whiteboard - loaded from $PROFILE (setup.ps1 copies this file to ~/.whiteboard/shell.ps1)
#   claude         marker intro, then an orange "Claude Whiteboard" tab in the current folder
#   claude-quick   same tab, no intro
#   claude-plain   run Claude Code right here, no tab
#   claude-wb      manage this install: update | version | doctor | intro on/off | uninstall
# Set CLAUDE_NO_INTRO=1 to skip the intro for one run.
$Global:WbDir = Join-Path $HOME '.whiteboard'

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
    $h = [WbWin]::GetForegroundWindow()
    $r = New-Object WbWin+RECT
    if ([WbWin]::DwmGetWindowAttribute($h, 9, [ref]$r, [Runtime.InteropServices.Marshal]::SizeOf($r)) -ne 0) { [void][WbWin]::GetWindowRect($h, [ref]$r) }
    $w = $r.Right - $r.Left; $hgt = $r.Bottom - $r.Top
    if ($w -lt 200 -or $hgt -lt 150) { return $null }
    # "x,y,w,h,hwnd": the overlay follows that window if it is moved or resized while the intro plays
    return "{0},{1},{2},{3},{4}" -f $r.Left, $r.Top, $w, $hgt, $h.ToInt64()
}

function Get-WbTabArgs([object[]]$extra) {
    $dir = (Get-Location).ProviderPath
    if ($dir.EndsWith('\')) { $dir = $dir + '.' }
    return @('-w', '0', 'nt', '-p', 'Claude Whiteboard', '-d', $dir,
        'powershell.exe', '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $Global:WbDir 'claude-wb.ps1')) + $extra
}

# the animation runtime: the one setup.ps1 downloads, or the older npm-installed one
function Get-WbElectron {
    foreach ($p in @((Join-Path $Global:WbDir 'intro\electron\electron.exe'), (Join-Path $Global:WbDir 'intro\app\node_modules\electron\dist\electron.exe'))) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Test-WbIntroOn {   # "claude-wb intro off" creates the flag file ~/.whiteboard/no-intro
    return -not (Test-Path (Join-Path $Global:WbDir 'no-intro'))
}

function claude {
    if (-not $env:WT_SESSION) { claude-plain @args; return }
    $tabArgs = Get-WbTabArgs $args
    $intro = Get-WbElectron
    $rect = $null
    if ($intro -and -not $env:CLAUDE_NO_INTRO -and (Test-WbIntroOn)) { try { $rect = Get-WbTerminalRect } catch { $rect = $null } }
    if ($rect) {
        $p = $rect -split ','
        & $intro (Join-Path $Global:WbDir 'intro\app') ("--rect=" + ($p[0..3] -join ',')) ("--hwnd=" + $p[4]) '--wt' @tabArgs
    }
    else { & wt.exe @tabArgs }
}

function claude-quick {
    if (-not $env:WT_SESSION) { claude-plain @args; return }
    $tabArgs = Get-WbTabArgs $args
    & wt.exe @tabArgs
}

function claude-plain {
    $real = Get-Command claude -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $real) { Write-Host "claude (Claude Code) not found on PATH"; return }
    & $real.Source @args
}

# ---------------- claude-wb: update / version / doctor / intro / uninstall ----------------
function Get-WbInstallInfo {
    $info = [ordered]@{ repo = 'wjunlin293-tech/claudecode-startup-animation'; ref = 'main'; version = '?' }
    try {
        $j = Get-Content (Join-Path $Global:WbDir 'install.json') -Raw -ErrorAction Stop | ConvertFrom-Json
        foreach ($k in @('repo', 'ref', 'version')) { if ($j.$k) { $info[$k] = [string]$j.$k } }
    } catch {}
    return [PSCustomObject]$info
}

function claude-wb {
    param([string]$Command = 'help', [string]$Option = '')
    $info = Get-WbInstallInfo
    switch ($Command.ToLower()) {
        'update' {
            Write-Host "Updating from $($info.repo) ($($info.ref)) ..."
            $env:CLAUDE_WB_REPO = $info.repo; $env:CLAUDE_WB_REF = $info.ref
            try { Invoke-Expression (Invoke-RestMethod "https://raw.githubusercontent.com/$($info.repo)/$($info.ref)/install.ps1") }
            catch { Write-Host "更新失败 / update failed: $($_.Exception.Message)" -ForegroundColor Red }
            finally { Remove-Item Env:CLAUDE_WB_REPO, Env:CLAUDE_WB_REF -ErrorAction SilentlyContinue }
        }
        'version' {
            Write-Host "Claude Whiteboard $($info.version)   ($($info.repo) @ $($info.ref))"
            try {
                $remote = ([string](Invoke-RestMethod -TimeoutSec 5 "https://raw.githubusercontent.com/$($info.repo)/$($info.ref)/VERSION")).Trim()
                if ($remote -and $remote -ne $info.version) { Write-Host "有新版本 $remote -> 输入 claude-wb update 更新  (new version available)" -ForegroundColor Yellow }
                else { Write-Host "已经是最新版 (up to date)" -ForegroundColor Green }
            } catch { Write-Host "(没法联网检查新版本 / could not check for updates)" }
        }
        'doctor' {
            $check = Join-Path $Global:WbDir 'tools\check.ps1'
            if (Test-Path $check) { & powershell.exe -ExecutionPolicy Bypass -File $check } else { Write-Host "check.ps1 not found - run: claude-wb update" }
        }
        'intro' {
            $flag = Join-Path $Global:WbDir 'no-intro'
            if ($Option -notin @('on', 'off')) { Write-Host "用法 / usage: claude-wb intro on|off   (现在 / now: $(if (Test-WbIntroOn) { 'on' } else { 'off' }))"; return }
            if ($Option -eq 'on') { Remove-Item $flag -Force -ErrorAction SilentlyContinue; Write-Host "启动动画已开启 (intro on)" }
            else { New-Item -ItemType Directory -Force -Path $Global:WbDir | Out-Null; Set-Content -Path $flag -Value 'claude-wb intro off'; Write-Host "启动动画已关闭，claude 会直接开白板标签页 (intro off)" }
        }
        'uninstall' {
            $setup = Join-Path $Global:WbDir 'tools\setup.ps1'
            if (-not (Test-Path $setup)) { Write-Host "setup.ps1 not found - run: claude-wb update, then claude-wb uninstall"; return }
            if ((Read-Host "确定要卸载 Claude Whiteboard 吗？(y/N)") -ne 'y') { Write-Host "已取消"; return }
            & powershell.exe -ExecutionPolicy Bypass -File $setup -Undo
        }
        default {
            Write-Host "claude-wb  管理 Claude Whiteboard / manage this install"
            Write-Host "  claude-wb update        更新到最新版 / update to the latest version"
            Write-Host "  claude-wb version       查看版本、检查有没有新版本"
            Write-Host "  claude-wb doctor        自检，出问题先跑这个"
            Write-Host "  claude-wb intro on|off  开 / 关启动动画"
            Write-Host "  claude-wb uninstall     卸载"
            Write-Host ""
            Write-Host "  claude        动画 + 白板标签页   claude-quick  不播动画   claude-plain  原样运行"
        }
    }
}
