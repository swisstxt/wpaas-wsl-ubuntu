#!/bin/bash
# Runs the status line script against sample payloads and the claude-statusline
# step against a temporary HOME. Needs jq and git, no network.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$REPO_ROOT" || exit 1

fails=0
assert_match()   { if grep -qE -- "$3" <<<"$2"; then echo "ok   $1"; else echo "FAIL $1: /$3/ not found in: $2"; fails=$((fails+1)); fi; }
assert_nomatch() { if grep -qE -- "$3" <<<"$2"; then echo "FAIL $1: /$3/ unexpectedly found in: $2"; fails=$((fails+1)); else echo "ok   $1"; fi; }
assert_eq()      { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$3' got '$2'"; fails=$((fails+1)); fi; }

SL="$REPO_ROOT/claude/statusline-command.sh"
plain() { sed 's/\x1b\[[0-9;]*m//g'; }   # strip colors

# a repo with one staged, one modified and one untracked file
repo="$TMP/repo"
git init -q "$repo" && git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
printf a > "$repo/a" && git -C "$repo" add a && printf b > "$repo/a" && printf c > "$repo/b"

now=$(date +%s)
full=$(cat <<J
{"workspace":{"current_dir":"$repo"},"model":{"display_name":"Opus"},"effort":{"level":"high"},"thinking":{"enabled":true},
 "context_window":{"used_percentage":37.4,"total_input_tokens":74800,"context_window_size":200000},
 "rate_limits":{"five_hour":{"used_percentage":62,"resets_at":$((now+5400))},"seven_day":{"used_percentage":91,"resets_at":$((now+200000))}},
 "pr":{"number":42,"review_state":"approved"},"vim":{"mode":"NORMAL"},
 "prompt_cache":{"caching_observed":true,"warm":false,"last_miss_cause":{"causes":["ttl_expired"]}}}
J
)
out=$(bash "$SL" <<<"$full" | plain)
assert_eq    "two lines"                    "$(wc -l <<<"$out")" "2"
assert_match "line 1: user, host, dir"      "$out" "^$(whoami)@$(hostname -s) $repo"
assert_match "line 1: branch and counters"  "$out" "(master|main) \+1 ~1 \?1"
assert_match "line 1: PR with review state" "$out" "PR #42 approved"
assert_match "line 1: vim mode"             "$out" "NORMAL"
assert_match "line 2: model and effort"     "$out" "^Opus │ effort high │ thinking"
assert_match "line 2: context bar"          "$out" "ctx ████░░░░░░ 37% 74k/200k"
assert_match "line 2: 5h limit with reset"  "$out" "5h ██████░░░░ 62% ↻1h(29|30)m"
assert_match "line 2: 7d limit with reset"  "$out" "7d █████████░ 91% ↻2d7h"
assert_match "line 2: cache warning"        "$out" "cache cold: ttl_expired"

out=$(bash "$SL" <<<'{"workspace":{"current_dir":"/"},"model":{"display_name":"Opus"},"context_window":{"used_percentage":null}}' | plain)
assert_eq    "sparse input: line 2 is just the model" "$(sed -n 2p <<<"$out")" "Opus"
assert_match "sparse input: no git segment" "$out" "^$(whoami)@$(hostname -s) / ?$"
assert_nomatch "sparse input: no ctx segment" "$out" "ctx"

# --- the step against a temporary HOME ---
export HOME="$TMP/home"
export WPAAS_NO_SUDO=1
step() { bash "$REPO_ROOT/steps/132-claude-statusline.sh" 2>&1; }

out=$(step)
assert_match "fresh home: script installed" "$out" "installing $HOME/.claude/statusline-command.sh"
assert_match "fresh home: settings created" "$out" "created $HOME/.claude/settings.json"
assert_eq    "fresh home: settings point at the script" "$(jq -r .statusLine.command "$HOME/.claude/settings.json")" "bash ~/.claude/statusline-command.sh"
[ -x "$HOME/.claude/statusline-command.sh" ] && echo "ok   fresh home: script is executable" || { echo "FAIL fresh home: script not executable"; fails=$((fails+1)); }

out=$(step)
assert_match "rerun: script up to date"     "$out" "is up to date"
assert_match "rerun: statusLine kept"       "$out" "already has a statusLine entry"

printf '{"model": "opus", "permissions": {"allow": ["Bash(ls:*)"]}}\n' > "$HOME/.claude/settings.json"
out=$(step)
assert_match "existing settings: statusLine added" "$out" "added statusLine"
assert_eq    "existing settings: other keys kept"  "$(jq -c '[.model, .permissions.allow[0], .statusLine.type]' "$HOME/.claude/settings.json")" '["opus","Bash(ls:*)","command"]'

printf '{"statusLine": {"type": "command", "command": "mine"}}\n' > "$HOME/.claude/settings.json"
out=$(step)
assert_match "own statusLine: left alone"   "$out" "already has a statusLine entry"
assert_eq    "own statusLine: unchanged"    "$(jq -r .statusLine.command "$HOME/.claude/settings.json")" "mine"

printf '{ broken\n' > "$HOME/.claude/settings.json"
out=$(step); rc=$?
assert_eq    "broken settings: step still succeeds" "$rc" "0"
assert_match "broken settings: warned"      "$out" "not valid JSON"
assert_eq    "broken settings: untouched"   "$(cat "$HOME/.claude/settings.json")" "{ broken"

[ "$fails" -eq 0 ] && echo "all tests passed" || { echo "$fails test(s) failed"; exit 1; }
