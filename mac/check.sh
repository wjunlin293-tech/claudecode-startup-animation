#!/bin/bash
# Read-only check: is everything in place? Changes nothing.
#   bash mac/check.sh
bad=0
wb="$HOME/.whiteboard"
row() { # row <ok 0/1> <name> <hint>
  if [ "$1" -eq 0 ]; then printf '[ OK ] %s\n' "$2"; else bad=$((bad+1)); printf '[FAIL] %s  ->  %s\n' "$2" "$3"; fi
}

row "$([ "$(uname)" = Darwin ]; echo $?)" "0 running on macOS" "this package is for macOS"
row "$([ -f "$HOME/Library/Fonts/WhiteboardMono-Regular.ttf" ]; echo $?)" "1 font Whiteboard Mono" "run mac/setup.sh"
row "$([ -x "$wb/open-tab.sh" ] && [ -x "$wb/claude-wb.sh" ] && [ -f "$wb/shell.zsh" ]; echo $?)" "2 launcher scripts in ~/.whiteboard" "run mac/setup.sh"
prof=1
defaults read com.apple.Terminal "Window Settings" 2>/dev/null | grep -q '"Claude Whiteboard"' && prof=0
row "$prof" "3 Terminal profile 'Claude Whiteboard'" "run mac/setup.sh (it opens the .terminal file)"
bg=$(osascript -e 'tell application "Terminal" to get background color of settings set "Claude Whiteboard"' 2>/dev/null | awk -F', *' '{print $1}')
row "$([ -n "$bg" ] && [ "${bg:-0}" -gt 55000 ] 2>/dev/null; echo $?)" "3b profile background is the light whiteboard color (got: ${bg:-none})" "run mac/setup.sh again (it sets the colors through Terminal)"
row "$(grep -q 'whiteboard-claude' "$HOME/.zshrc" 2>/dev/null; echo $?)" "4 ~/.zshrc hook" "run mac/setup.sh"
if [ -x "$wb/intro/app/node_modules/electron/dist/Electron.app/Contents/MacOS/Electron" ]; then
  row 0 "5 intro animation installed" ""
else
  echo "[ -- ] 5 intro animation not installed (optional: brew install node, then run mac/setup.sh)"
fi
n=$(ls "$wb/characters" 2>/dev/null | grep -ciE '\.(png|webp|gif|jpg)$')
echo "[info] your character pictures: ${n:-0}  ($wb/characters)"
row "$(command -v claude >/dev/null 2>&1; echo $?)" "6 real Claude Code found on PATH" "install Claude Code first"
echo "[info] TERM_PROGRAM=${TERM_PROGRAM:-unset} (the intro only runs inside Apple_Terminal)"
echo
if [ "$bad" -eq 0 ]; then echo "All in place."; else echo "$bad item(s) missing - see FAIL lines."; fi
