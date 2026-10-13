#!/bin/bash
# Runs inside the Claude Whiteboard tab. The tab closes when Claude Code exits.
printf '\033]0;Claude Code\007'
if ! command -v claude >/dev/null 2>&1; then
  echo "claude (Claude Code) not found on PATH. Install it first, then try again."
  read -r -n 1 -p "Press any key to close..."
  exit 1
fi
# the Whiteboard Marker theme applies to THIS Claude Code only (--settings), not to claude in your other terminals
exec claude --settings '{"theme":"custom:whiteboard"}' "$@"
