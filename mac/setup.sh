#!/bin/bash
# Claude Whiteboard for macOS (Terminal.app): marker intro + a themed "Claude Whiteboard" tab.
#   bash mac/setup.sh              install (safe to run again)
#   bash mac/setup.sh --no-intro   no animation, just the themed tab
#   bash mac/setup.sh --no-theme   do not switch Claude Code to the Whiteboard Marker theme
#   bash mac/setup.sh --undo       remove the zsh hook and the intro (fonts and profile are kept)
# Nothing here needs sudo. Changed files are backed up as <file>.bak-<time> first.
set -eu

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/.." && pwd)"
stamp="$(date +%Y%m%d-%H%M%S)"
wb="$HOME/.whiteboard"
undo=0
nointro=0
notheme=0
for a in "$@"; do
  case "$a" in
    --undo) undo=1 ;;
    --no-intro) nointro=1 ;;
    --no-theme) notheme=1 ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) echo "unknown option: $a"; exit 1 ;;
  esac
done
say() { echo "[whiteboard] $*"; }

# set / remove "theme": "custom:whiteboard" in ~/.claude/settings.json (JSON edited with the JavaScript that ships with macOS)
claude_theme() { # claude_theme set|unset
  local f="$HOME/.claude/settings.json" js out
  js="$(mktemp -t wbtheme).js"
  cat > "$js" <<'JXA'
function run(argv) {
  ObjC.import('Foundation');
  var p = argv[0], mode = argv[1], fm = $.NSFileManager.defaultManager, obj = {};
  if (fm.fileExistsAtPath(p)) {
    var s = ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(p, $.NSUTF8StringEncoding, null));
    if (s && s.trim()) obj = JSON.parse(s);
  }
  if (mode === 'set') { if (obj.theme === 'custom:whiteboard') return 'already'; obj.theme = 'custom:whiteboard'; }
  else { if (obj.theme !== 'custom:whiteboard') return 'untouched'; delete obj.theme; }
  $(JSON.stringify(obj, null, 2) + '\n').writeToFileAtomicallyEncodingError(p, true, $.NSUTF8StringEncoding, null);
  return 'ok';
}
JXA
  mkdir -p "$HOME/.claude"
  [ -f "$f" ] && cp "$f" "$f.bak-$stamp"
  out="$(osascript -l JavaScript "$js" "$f" "$1" 2>&1)" || { say "could not edit ~/.claude/settings.json ($out) - in Claude Code type /theme and pick Whiteboard Marker"; rm -f "$js"; return 0; }
  rm -f "$js"
  case "$out" in
    ok) [ "$1" = set ] && say "    Claude Code theme switched to Whiteboard Marker (backup ~/.claude/settings.json.bak-$stamp)" || say "    Claude Code theme setting removed" ;;
    already) say "    Claude Code theme already Whiteboard Marker" ;;
    *) : ;;
  esac
}

if [ "$(uname)" != "Darwin" ]; then echo "This installer is for macOS only."; exit 1; fi
if [ ! -d "/System/Applications/Utilities/Terminal.app" ] && [ ! -d "/Applications/Utilities/Terminal.app" ]; then
  echo "Terminal.app not found."; exit 1
fi

# ---------- 1. fonts (per user) ----------
if [ "$undo" -eq 0 ]; then
  fontsrc="$repo/fonts"
  [ -d "$fontsrc" ] || fontsrc="$here/fonts"
  if [ ! -f "$fontsrc/WhiteboardMono-Regular.ttf" ]; then
    echo "fonts/ not found next to mac/. Download the whole repository, not just the mac folder."; exit 1
  fi
  mkdir -p "$HOME/Library/Fonts"
  cp "$fontsrc/WhiteboardMono-Regular.ttf" "$fontsrc/WhiteboardMono-Bold.ttf" "$HOME/Library/Fonts/"
  say "1/5 fonts installed to ~/Library/Fonts"

  # ---------- 2. launcher scripts + shell hook ----------
  mkdir -p "$wb"
  cp "$here/bin/claude-wb.sh" "$here/bin/open-tab.sh" "$wb/"
  chmod +x "$wb/claude-wb.sh" "$wb/open-tab.sh"
  cp "$here/shell/whiteboard-claude.zsh" "$wb/shell.zsh"
  say "2/5 launcher scripts copied to $wb"
  if [ -f "$repo/claude/whiteboard.json" ]; then
    mkdir -p "$HOME/.claude/themes"
    cp "$repo/claude/whiteboard.json" "$HOME/.claude/themes/whiteboard.json"
    say "    Claude Code theme file copied"
    if [ "$notheme" -eq 0 ]; then claude_theme set; else say "    theme not switched (--no-theme): pick it in Claude Code with /theme"; fi
  fi

  # ---------- 3. intro animation ----------
  electron="$wb/intro/app/node_modules/electron/dist/Electron.app/Contents/MacOS/Electron"
  if [ "$nointro" -eq 1 ]; then
    say "3/5 intro skipped (--no-intro)"
  else
    mkdir -p "$wb/intro/app" "$wb/characters"
    rsync -a --exclude node_modules "$here/intro/app/" "$wb/intro/app/"
    if [ -x "$electron" ]; then
      say "3/5 intro updated (Electron runtime already present)"
    elif command -v npm >/dev/null 2>&1; then
      say "3/5 downloading the Electron runtime (about 100 MB, one time)..."
      (cd "$wb/intro/app" && npm install --no-audit --no-fund --loglevel=error) || true
      if [ -x "$electron" ]; then say "3/5 intro installed"
      else say "3/5 WARNING: npm install did not produce Electron - 'claude' will open the tab without the intro"; fi
    else
      say "3/5 WARNING: Node.js not found, intro skipped. Install it (brew install node), then run this again."
    fi
    if [ ! -f "$wb/intro-config.json" ]; then
      printf '{\n  "codeOpacity": 0.28,\n  "speed": 1,\n  "showHeart": true\n}\n' > "$wb/intro-config.json"
    fi
  fi

  # ---------- 4. Terminal.app profile ----------
  if defaults read com.apple.Terminal "Window Settings" 2>/dev/null | grep -q '"Claude Whiteboard"'; then
    say "4/5 Terminal profile 'Claude Whiteboard' already imported"
  else
    open "$here/terminal/Claude-Whiteboard.terminal"
    say "4/5 Terminal profile imported - a new Terminal window with it just opened, you can close that window"
    sleep 1
  fi
fi

# ---------- 5. ~/.zshrc hook ----------
begin="# >>> whiteboard-claude >>>"
end="# <<< whiteboard-claude <<<"
zrc="$HOME/.zshrc"
touch "$zrc"
cp "$zrc" "$zrc.bak-$stamp"
tmp="$(mktemp)"
awk -v b="$begin" -v e="$end" 'index($0,b){skip=1} !skip{print} index($0,e){skip=0}' "$zrc" > "$tmp"
cat "$tmp" > "$zrc"
rm -f "$tmp"
if [ "$undo" -eq 0 ]; then
  {
    echo ""
    echo "$begin"
    echo '[ -f "$HOME/.whiteboard/shell.zsh" ] && source "$HOME/.whiteboard/shell.zsh"'
    echo "$end"
  } >> "$zrc"
  say "5/5 ~/.zshrc updated (backup .bak-$stamp)"
else
  rm -rf "$wb/intro"
  claude_theme unset
  say "5/5 ~/.zshrc cleaned and the intro removed (backup .bak-$stamp)"
  say "The 'Claude Whiteboard' profile and the font are kept (harmless). To delete the profile: Terminal > Settings > Profiles > Claude Whiteboard > '-'."
fi

if [ "$undo" -eq 0 ]; then
  say "Done. Open a NEW Terminal tab, cd into a project and type: claude"
  say "First run: macOS asks whether Electron / Terminal may control Terminal - click OK."
  say "Check anything with: bash mac/check.sh"
fi
