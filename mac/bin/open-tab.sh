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
    if (count of windows) is 0 then
      set t to do script (item 1 of argv)
    else
      set t to do script (item 1 of argv) in front window
    end if
    try
      set current settings of t to settings set "Claude Whiteboard"
    end try
    activate
  end tell
end run
APPLESCRIPT
