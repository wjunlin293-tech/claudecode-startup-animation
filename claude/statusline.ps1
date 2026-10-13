# Whiteboard status line for Claude Code (reads session JSON on stdin)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$data = $input | Out-String | ConvertFrom-Json

$e      = [char]27
$orange = "$e[38;2;229;101;60m"
$gray   = "$e[38;2;107;111;105m"
$ink    = "$e[38;2;34;34;34m"
$reset  = "$e[0m"
$pen    = [char]0x270E   # pencil
$dot    = [char]0x00B7   # middle dot

$model = $data.model.display_name
$dir   = Split-Path $data.workspace.current_dir -Leaf
$pct   = $data.context_window.used_percentage

$branch = ""
try {
    $b = git -C $data.workspace.current_dir branch --show-current 2>$null
    if ($b) { $branch = " $gray$dot $ink$b" }
} catch {}

$ctx = ""
if ($pct -ne $null) {
    $n = [math]::Floor([double]$pct)
    $filled = [math]::Min(10, [math]::Floor($n / 10))
    $bar = ("~" * $filled) + ("." * (10 - $filled))
    $ctx = " $gray$dot ctx $orange$bar$gray $n%"
}

Write-Output "$orange$pen $ink$model $gray$dot $ink$dir$branch$ctx$reset"
