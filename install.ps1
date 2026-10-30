# Claude Whiteboard - one-line installer / updater for Windows.
#   irm https://raw.githubusercontent.com/wjunlin293-tech/claudecode-startup-animation/main/install.ps1 | iex
# Safe to run again (that is how you update). Optional, set BEFORE running:
#   $env:CLAUDE_WB_REF = 'some-branch-or-tag'   (default: main)
#   $env:CLAUDE_WB_REPO = 'owner/name'
#   $env:CLAUDE_WB_NOINTRO = 1   no animation        $env:CLAUDE_WB_NOSHADER = 1   no paper-grain filter
# This file is plain ASCII on purpose: it is run straight from the web and must survive any console encoding.
# It never calls `exit`, so it can not close your terminal window.
$wbRepo = if ($env:CLAUDE_WB_REPO) { $env:CLAUDE_WB_REPO } else { 'wjunlin293-tech/claudecode-startup-animation' }
$wbRef  = if ($env:CLAUDE_WB_REF)  { $env:CLAUDE_WB_REF }  else { 'main' }
$wbTmp  = Join-Path ([IO.Path]::GetTempPath()) ('claude-wb-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$wbOldProgress = $ProgressPreference
try {
    if ($env:OS -ne 'Windows_NT') { throw 'This installer is for Windows. On macOS use install.sh.' }
    if ($PSVersionTable.PSVersion.Major -lt 5) { throw 'Windows PowerShell 5.1 or newer is needed (it comes with Windows 10/11).' }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'   # the progress bar makes Windows PowerShell 5.1 downloads many times slower

    Write-Host "[claude-wb] downloading $wbRepo ($wbRef) ..."
    New-Item -ItemType Directory -Force -Path $wbTmp | Out-Null
    $zip = Join-Path $wbTmp 'src.zip'
    try { Invoke-WebRequest -UseBasicParsing "https://github.com/$wbRepo/archive/refs/heads/$wbRef.zip" -OutFile $zip }
    catch { Invoke-WebRequest -UseBasicParsing "https://github.com/$wbRepo/archive/refs/tags/$wbRef.zip" -OutFile $zip }   # a tag instead of a branch
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $wbTmp)
    $src = Get-ChildItem $wbTmp -Directory | Select-Object -First 1
    if (-not $src -or -not (Test-Path (Join-Path $src.FullName 'setup.ps1'))) { throw 'The download does not look like Claude Whiteboard (setup.ps1 missing).' }

    $wbFlags = @()
    if ($env:CLAUDE_WB_NOINTRO)  { $wbFlags += '-NoIntro' }
    if ($env:CLAUDE_WB_NOSHADER) { $wbFlags += '-NoShader' }
    $env:CLAUDE_WB_REPO = $wbRepo; $env:CLAUDE_WB_REF = $wbRef   # setup.ps1 records them, so `claude-wb update` follows the same source
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $src.FullName 'setup.ps1') @wbFlags
    if ($LASTEXITCODE -ne 0) { throw "setup.ps1 stopped with exit code $LASTEXITCODE (see the message above)." }

    # make `claude` work in THIS window right away (no restart needed)
    if (Test-Path $PROFILE) { try { . $PROFILE } catch { Write-Host "[claude-wb] open a new tab to start using it." } }
}
catch {
    Write-Host ""
    Write-Host "[claude-wb] FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[claude-wb] Nothing was left half-installed that a re-run can not fix. Run the same command again, or paste this message to get help." -ForegroundColor Red
}
finally {
    $ProgressPreference = $wbOldProgress
    Remove-Item $wbTmp -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item Env:CLAUDE_WB_REPO, Env:CLAUDE_WB_REF -ErrorAction SilentlyContinue
    Remove-Variable wbRepo, wbRef, wbTmp, wbOldProgress, wbFlags, zip, src -ErrorAction SilentlyContinue
}
