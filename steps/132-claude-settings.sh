#!/bin/bash
# step: claude-settings
# Claude Code user settings and the two-line status line.
# claude/settings.json is merged into ~/.claude/settings.json: keys the user already
# has win (arrays included), keys they lack are added. "~/" in additionalDirectories is
# expanded to the real home directory. claude/statusline-command.sh goes to ~/.claude.
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

if [ -s "$settings" ] && ! jq empty "$settings" 2>/dev/null; then
  echo "$settings is not valid JSON, leaving it untouched; merge claude/settings.json yourself" >&2
  exit 0
fi
[ -s "$settings" ] || printf '{}\n' > "$settings"
tmp=$(mktemp)
jq --arg home "$HOME" -s '
  (.[0] | .permissions.additionalDirectories |= (. // [] | map(sub("^~/"; $home + "/")))) as $template
  | $template * .[1]' claude/settings.json "$settings" > "$tmp"
if cmp -s "$tmp" "$settings"; then
  echo "$settings is up to date"
  rm -f "$tmp"
else
  mv "$tmp" "$settings"
  echo "updated $settings"
fi
