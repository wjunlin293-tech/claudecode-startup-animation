#!/bin/bash
# Open a new "Claude Whiteboard" tab in Terminal.app, in <dir>, running Claude Code.
# usage: open-tab.sh <dir> [claude args...]
dir="${1:-$HOME}"
[ $# -gt 0 ] && shift

cmd="cd $(printf '%q' "$dir") && exec $(printf '%q' "$HOME/.whiteboard/claude-wb.sh")"
for a in "$@"; do cmd+=" $(printf '%q' "$a")"; done

/usr/bin/osascript - "$cmd" <<'APPLESCRIPT'
on run argv
  tell application "Terminal"
    -- open a NEW WINDOW exactly over the one you typed `claude` in (no extra tab bar, so the grid matches the intro);
    -- applying the profile makes Terminal resize it (its own rows/columns + font), so put the frame back afterwards
    set hasWin to ((count of windows) > 0)
    if hasWin then set b to bounds of front window
    set t to do script (item 1 of argv)
    try
      set current settings of t to settings set "Claude Whiteboard"
    end try
    if hasWin then
      delay 0.2
      try
        set bounds of front window to b
      end try
    end if
    activate
  end tell
end run
APPLESCRIPT
