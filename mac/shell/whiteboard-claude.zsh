# Claude Whiteboard (macOS / Terminal.app) - sourced from ~/.zshrc
#   claude        marker intro, then an orange-themed "Claude Whiteboard" tab in the current folder
#   claude-quick  same tab, no intro
#   claude-plain  run Claude Code right here, no tab
# Set CLAUDE_NO_INTRO=1 to skip the intro for one run.

claude-plain() {
  local real
  real=$(whence -p claude)
  if [[ -z "$real" ]]; then
    echo "claude (Claude Code) not found on PATH"
    return 1
  fi
  "$real" "$@"
}

claude-quick() {
  if [[ "$TERM_PROGRAM" != "Apple_Terminal" ]]; then claude-plain "$@"; return; fi
  "$HOME/.whiteboard/open-tab.sh" "$PWD" "$@"
}

claude() {
  if [[ "$TERM_PROGRAM" != "Apple_Terminal" ]]; then claude-plain "$@"; return; fi
  local app="$HOME/.whiteboard/intro/app"
  local electron="$app/node_modules/electron/dist/Electron.app/Contents/MacOS/Electron"
  if [[ -x "$electron" && -z "$CLAUDE_NO_INTRO" ]]; then
    # one query: window bounds "x1,y1,x2,y2" (points), then the real tab's rows / cols / font / size,
    # then the Claude Whiteboard profile's font / size. Everything is read live, so any Mac's settings work.
    local info rect term tb
    info=$(osascript 2>/dev/null <<'APPLESCRIPT'
tell application "Terminal"
  set w to front window
  set b to bounds of w
  set t to selected tab of w
  set wfn to "Whiteboard Mono"
  set wfs to 13
  try
    set wfn to font name of settings set "Claude Whiteboard"
    set wfs to font size of settings set "Claude Whiteboard"
  end try
  return ((item 1 of b) as text) & "," & ((item 2 of b) as text) & "," & ((item 3 of b) as text) & "," & ((item 4 of b) as text) & "|" & ((number of rows of t) as text) & "|" & ((number of columns of t) as text) & "|" & (font name of t) & "|" & ((font size of t) as text) & "|" & wfn & "|" & (wfs as text)
end tell
APPLESCRIPT
)
    rect=$(print -r -- "$info" | awk -F'|' '{ n=split($1, a, ","); if (n==4) printf "%d,%d,%d,%d", a[1], a[2], a[3]-a[1], a[4]-a[2] }')
    # real title-bar height of this macOS version
    tb=$(osascript -l JavaScript -e 'ObjC.import("AppKit"); $.NSWindow.frameRectForContentRectStyleMask($.NSMakeRect(0,0,100,100),15).size.height-100' 2>/dev/null)
    [[ "$tb" =~ ^[0-9.]+$ ]] || tb=28
    term=$(print -r -- "$info" | awk -F'|' -v tb="$tb" 'NF==7 { printf "{\"rows\":%s,\"cols\":%s,\"font\":\"%s\",\"size\":%s,\"wbFont\":\"%s\",\"wbSize\":%s,\"titlebar\":%s}", $2, $3, $4, $5, $6, $7, tb }')
    if [[ -n "$rect" ]]; then
      # GUI overlay in the background; it opens the real window itself, after it has finished and quit
      local freeze=""
      [[ -n "$CLAUDE_INTRO_FREEZE" ]] && freeze="--freeze=$CLAUDE_INTRO_FREEZE"   # debug: hold the animation at that second
      "$electron" "$app" "--rect=$rect" "--term=$term" $freeze --wt "$HOME/.whiteboard/open-tab.sh" "$PWD" "$@" >/dev/null 2>&1 &!
      return
    fi
  fi
  "$HOME/.whiteboard/open-tab.sh" "$PWD" "$@"
}
