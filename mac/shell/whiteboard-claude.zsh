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
    # Terminal reports bounds as "x1, y1, x2, y2" in points; the overlay wants "x,y,w,h"
    local bounds rect
    bounds=$(osascript -e 'tell application "Terminal" to get bounds of front window' 2>/dev/null)
    rect=$(print -r -- "$bounds" | awk -F', *' 'NF==4 { printf "%d,%d,%d,%d", $1, $2, $3-$1, $4-$2 }')
    if [[ -n "$rect" ]]; then
      # GUI overlay in the background; it opens the real tab itself once the window is painted over
      "$electron" "$app" "--rect=$rect" --wt "$HOME/.whiteboard/open-tab.sh" "$PWD" "$@" >/dev/null 2>&1 &!
      return
    fi
  fi
  "$HOME/.whiteboard/open-tab.sh" "$PWD" "$@"
}
