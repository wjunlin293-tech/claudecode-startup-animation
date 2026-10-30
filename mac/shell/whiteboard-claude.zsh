# Claude Whiteboard (macOS / Terminal.app) - sourced from ~/.zshrc
#   claude        marker intro, then an orange-themed "Claude Whiteboard" tab in the current folder
#   claude-quick  same tab, no intro
#   claude-plain  run Claude Code right here, no tab
#   claude-wb     manage this install: update | version | doctor | intro on/off | uninstall
# Set CLAUDE_NO_INTRO=1 to skip the intro for one run.

# the animation runtime: the one setup.sh downloads, or the older npm-installed one
_wb_electron() {
  local e
  for e in "$HOME/.whiteboard/intro/electron/Electron.app/Contents/MacOS/Electron" \
           "$HOME/.whiteboard/intro/app/node_modules/electron/dist/Electron.app/Contents/MacOS/Electron"; do
    [[ -x "$e" ]] && { print -r -- "$e"; return; }
  done
}
# "claude-wb intro off" creates the flag file ~/.whiteboard/no-intro
_wb_intro_on() { [[ ! -e "$HOME/.whiteboard/no-intro" ]]; }

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
  local electron
  electron=$(_wb_electron)
  if [[ -n "$electron" && -z "$CLAUDE_NO_INTRO" ]] && _wb_intro_on; then
    # one query: window bounds "x1,y1,x2,y2" (points), then the real tab's rows / cols / font / size,
    # then the Claude Whiteboard profile's font / size. Everything is read live, so any Mac's settings work.
    local info rect term tb winid
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
  return ((item 1 of b) as text) & "," & ((item 2 of b) as text) & "," & ((item 3 of b) as text) & "," & ((item 4 of b) as text) & "|" & ((number of rows of t) as text) & "|" & ((number of columns of t) as text) & "|" & (font name of t) & "|" & ((font size of t) as text) & "|" & wfn & "|" & (wfs as text) & "|" & ((id of w) as text)
end tell
APPLESCRIPT
)
    rect=$(print -r -- "$info" | awk -F'|' '{ n=split($1, a, ","); if (n==4) printf "%d,%d,%d,%d", a[1], a[2], a[3]-a[1], a[4]-a[2] }')
    # id of the window, so the overlay can follow it if it is moved or resized while the intro plays
    winid=$(print -r -- "$info" | awk -F'|' 'NF==8 { print $8 }')
    # real title-bar height of this macOS version
    tb=$(osascript -l JavaScript -e 'ObjC.import("AppKit"); $.NSWindow.frameRectForContentRectStyleMask($.NSMakeRect(0,0,100,100),15).size.height-100' 2>/dev/null)
    [[ "$tb" =~ ^[0-9.]+$ ]] || tb=28
    term=$(print -r -- "$info" | awk -F'|' -v tb="$tb" 'NF==8 { printf "{\"rows\":%s,\"cols\":%s,\"font\":\"%s\",\"size\":%s,\"wbFont\":\"%s\",\"wbSize\":%s,\"titlebar\":%s}", $2, $3, $4, $5, $6, $7, tb }')
    if [[ -n "$rect" ]]; then
      # GUI overlay in the background; it opens the real window itself, after it has finished and quit
      local freeze=""
      [[ -n "$CLAUDE_INTRO_FREEZE" ]] && freeze="--freeze=$CLAUDE_INTRO_FREEZE"   # debug: hold the animation at that second
      "$electron" "$app" "--rect=$rect" "--term=$term" "--winid=$winid" $freeze --wt "$HOME/.whiteboard/open-tab.sh" "$PWD" "$@" >/dev/null 2>&1 &!
      return
    fi
  fi
  "$HOME/.whiteboard/open-tab.sh" "$PWD" "$@"
}

# ---------------- claude-wb: update / version / doctor / intro / uninstall ----------------
_wb_json() { sed -n "s/.*\"$1\": *\"\([^\"]*\)\".*/\1/p" "$HOME/.whiteboard/install.json" 2>/dev/null | head -1; }

claude-wb() {
  local wb="$HOME/.whiteboard" repo ref ver remote
  repo=$(_wb_json repo); ref=$(_wb_json ref); ver=$(_wb_json version)
  : ${repo:=wjunlin293-tech/claudecode-startup-animation}; : ${ref:=main}; : ${ver:=?}
  case "${1:-help}" in
    update)
      echo "Updating from $repo ($ref) ..."
      curl -fsSL "https://raw.githubusercontent.com/$repo/$ref/install.sh" | CLAUDE_WB_REPO="$repo" CLAUDE_WB_REF="$ref" bash
      ;;
    version)
      echo "Claude Whiteboard $ver   ($repo @ $ref)"
      remote=$(curl -fsS --max-time 5 "https://raw.githubusercontent.com/$repo/$ref/VERSION" 2>/dev/null | tr -d '[:space:]')
      if [[ -z "$remote" ]]; then echo "(没法联网检查新版本 / could not check for updates)"
      elif [[ "$remote" != "$ver" ]]; then echo "有新版本 $remote -> 输入 claude-wb update 更新  (new version available)"
      else echo "已经是最新版 (up to date)"; fi
      ;;
    doctor)
      if [[ -f "$wb/tools/check.sh" ]]; then bash "$wb/tools/check.sh"; else echo "check.sh not found - run: claude-wb update"; fi
      ;;
    intro)
      case "$2" in
        on)  rm -f "$wb/no-intro"; echo "启动动画已开启 (intro on)" ;;
        off) mkdir -p "$wb"; echo "claude-wb intro off" > "$wb/no-intro"; echo "启动动画已关闭，claude 会直接开白板窗口 (intro off)" ;;
        *)   echo "用法 / usage: claude-wb intro on|off   (现在 / now: $(_wb_intro_on && echo on || echo off))" ;;
      esac
      ;;
    uninstall)
      if [[ ! -f "$wb/tools/setup.sh" ]]; then echo "setup.sh not found - run: claude-wb update, then claude-wb uninstall"; return 1; fi
      if read -q "?确定要卸载 Claude Whiteboard 吗？(y/N) "; then echo; bash "$wb/tools/setup.sh" --undo; else echo; echo "已取消"; fi
      ;;
    *)
      echo "claude-wb  管理 Claude Whiteboard / manage this install"
      echo "  claude-wb update        更新到最新版 / update to the latest version"
      echo "  claude-wb version       查看版本、检查有没有新版本"
      echo "  claude-wb doctor        自检，出问题先跑这个"
      echo "  claude-wb intro on|off  开 / 关启动动画"
      echo "  claude-wb uninstall     卸载"
      echo
      echo "  claude        动画 + 白板窗口   claude-quick  不播动画   claude-plain  原样运行"
      ;;
  esac
}
