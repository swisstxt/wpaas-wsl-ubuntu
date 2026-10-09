#!/bin/bash
# step: claude-statusline
# Two-line Claude Code status line: copies claude/statusline-command.sh to
# ~/.claude and points settings.json at it. Other settings are kept; an existing
# statusLine entry is left alone.
. "$REPO_ROOT/lib.sh"
dir="$HOME/.claude"
script="$dir/statusline-command.sh"
settings="$dir/settings.json"
mkdir -p "$dir"
if does_not_exists_or_is_different "$script" claude/statusline-command.sh; then
  echo "installing $script"
  install -m 0755 claude/statusline-command.sh "$script"
else
  echo "$script is up to date"
fi
if [ ! -s "$settings" ]; then
  printf '{\n  "statusLine": {\n    "type": "command",\n    "command": "bash ~/.claude/statusline-command.sh"\n  }\n}\n' > "$settings"
  echo "created $settings"
elif ! jq empty "$settings" 2>/dev/null; then
  echo "$settings is not valid JSON, leaving it untouched; add the statusLine entry yourself" >&2
elif [ "$(jq -r '.statusLine // empty' "$settings")" ]; then
  echo "$settings already has a statusLine entry, leaving it untouched"
else
  tmp=$(mktemp)
  jq '.statusLine = {type: "command", command: "bash ~/.claude/statusline-command.sh"}' "$settings" > "$tmp" && mv "$tmp" "$settings"
  echo "added statusLine to $settings"
fi
