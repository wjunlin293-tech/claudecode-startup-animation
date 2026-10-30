#!/bin/bash
# Claude Whiteboard - one-line installer / updater for macOS (Terminal.app).
#   curl -fsSL https://raw.githubusercontent.com/wjunlin293-tech/claudecode-startup-animation/main/install.sh | bash
# Safe to run again (that is how you update). Optional, set BEFORE running:
#   CLAUDE_WB_REF=some-branch-or-tag   (default: main)      CLAUDE_WB_REPO=owner/name
#   CLAUDE_WB_NOINTRO=1                no animation
# Needs nothing but macOS itself: no git, no Node.js, no Homebrew, no sudo.
set -eu

repo="${CLAUDE_WB_REPO:-wjunlin293-tech/claudecode-startup-animation}"
ref="${CLAUDE_WB_REF:-main}"

[ "$(uname)" = "Darwin" ] || { echo "这个安装脚本只适用于 macOS (this installer is for macOS only)."; exit 1; }
tmp="$(mktemp -d "${TMPDIR:-/tmp}/claude-wb.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

echo "[claude-wb] 正在下载 $repo ($ref) ..."
if ! curl -fsSL "https://github.com/$repo/archive/refs/heads/$ref.tar.gz" -o "$tmp/src.tgz" 2>/dev/null; then
  curl -fsSL "https://github.com/$repo/archive/refs/tags/$ref.tar.gz" -o "$tmp/src.tgz" || {
    echo "[claude-wb] 下载失败：请检查网络，或者确认 $repo 的 $ref 分支存在。"; exit 1; }
fi
tar -xzf "$tmp/src.tgz" -C "$tmp"
src="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -1)"
[ -f "$src/mac/setup.sh" ] || { echo "[claude-wb] 下载下来的内容不对（找不到 mac/setup.sh）。"; exit 1; }

flags=()
[ -n "${CLAUDE_WB_NOINTRO:-}" ] && flags+=(--no-intro)
CLAUDE_WB_REPO="$repo" CLAUDE_WB_REF="$ref" bash "$src/mac/setup.sh" ${flags[@]+"${flags[@]}"}
