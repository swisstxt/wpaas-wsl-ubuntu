#!/bin/bash
# Two-line status line for Claude Code (installed by steps/132-claude-statusline.sh).
# Line 1: user@host  dir  branch(+staged ~modified ?untracked ↑ahead ↓behind)  worktree  PR  agent  vim
# Line 2: model  effort  thinking  ctx bar  5h bar+reset  7d bar+reset  spend  cache state
# Segments whose data is missing are omitted. The branch glyph needs the nerd font that
# bootstrap.ps1 configures in Windows Terminal. Input schema: https://code.claude.com/docs/en/statusline

input=$(cat)
j() { echo "$input" | jq -r "$1 // empty"; }

R=$'\033[0m'; DIM=$'\033[2m'; B=$'\033[1m'
GREEN=$'\033[32m'; YEL=$'\033[33m'; RED=$'\033[31m'; BLUE=$'\033[34m'
MAG=$'\033[35m'; CYAN=$'\033[36m'
SEP=" ${DIM}│${R} "

# color by percentage: green <50, yellow <80, red otherwise
pcol() { local p=${1%.*}; if [ "$p" -ge 80 ]; then printf '%s' "$RED"; elif [ "$p" -ge 50 ]; then printf '%s' "$YEL"; else printf '%s' "$GREEN"; fi; }
# 10-cell bar
bar() {
  local p=${1%.*} n i out=""
  [ "$p" -gt 100 ] && p=100
  n=$(( (p + 5) / 10 ))
  for ((i=0;i<10;i++)); do if [ $i -lt $n ]; then out+="█"; else out+="░"; fi; done
  printf '%s' "$out"
}
# time until epoch
until_fmt() {
  local d=$(( $1 - $(date +%s) ))
  [ "$d" -le 0 ] && return
  if [ "$d" -ge 86400 ]; then printf '%dd%dh' $((d/86400)) $((d%86400/3600))
  elif [ "$d" -ge 3600 ]; then printf '%dh%02dm' $((d/3600)) $((d%3600/60))
  else printf '%dm' $((d/60)); fi
}
limit_seg() { # label pct resets_at
  local pct=$2 c; c=$(pcol "$pct")
  local s
  s="${DIM}$1${R} ${c}$(bar "$pct") $(printf '%.0f' "$pct")%${R}"
  if [ -n "$3" ]; then local t; t=$(until_fmt "$3"); [ -n "$t" ] && s+=" ${DIM}↻${t}${R}"; fi
  printf '%s' "$s"
}

# ---------- Line 1 ----------
cwd=$(j '.workspace.current_dir'); [ -z "$cwd" ] && cwd="$PWD"
case "$cwd" in
  "$HOME") dir="~" ;;
  "$HOME"/*) dir="~${cwd#"$HOME"}" ;;
  *) dir="$cwd" ;;
esac

chroot=""
[ -r /etc/debian_chroot ] && chroot="($(cat /etc/debian_chroot)) "

l1="${chroot}${B}${GREEN}$(whoami)@$(hostname -s)${R} ${B}${BLUE}${dir}${R}"

# git (skip optional locks)
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  export GIT_OPTIONAL_LOCKS=0
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  st=$(git -C "$cwd" status --porcelain 2>/dev/null)
  staged=$(printf '%s\n' "$st" | grep -c '^[MADRC]')
  modified=$(printf '%s\n' "$st" | grep -c '^.[MD]')
  untracked=$(printf '%s\n' "$st" | grep -c '^??')
  g=" ${MAG} ${branch}${R}"
  [ "$staged" -gt 0 ] && g+=" ${GREEN}+${staged}${R}"
  [ "$modified" -gt 0 ] && g+=" ${YEL}~${modified}${R}"
  [ "$untracked" -gt 0 ] && g+=" ${DIM}?${untracked}${R}"
  ab=$(git -C "$cwd" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)
  if [ -n "$ab" ]; then
    behind=${ab%%[[:space:]]*}; ahead=${ab##*[[:space:]]}
    [ "$ahead" -gt 0 ] && g+=" ${CYAN}↑${ahead}${R}"
    [ "$behind" -gt 0 ] && g+=" ${RED}↓${behind}${R}"
  fi
  l1+="$g"
fi

wt=$(j '.workspace.git_worktree // .worktree.name')
[ -n "$wt" ] && l1+="${SEP}${DIM}wt${R} ${wt}"

prn=$(j '.pr.number')
if [ -n "$prn" ]; then
  [ "$(j '.pr.kind')" = "mr" ] && lbl="MR !$prn" || lbl="PR #$prn"
  rs=$(j '.pr.review_state')
  case "$rs" in
    approved) rc=$GREEN ;; changes_requested) rc=$RED ;; *) rc=$YEL ;;
  esac
  l1+="${SEP}${CYAN}${lbl}${R}"
  [ -n "$rs" ] && l1+=" ${rc}${rs}${R}"
fi

ag=$(j '.agent.name'); [ -n "$ag" ] && l1+="${SEP}${DIM}agent${R} ${ag}"
vm=$(j '.vim.mode'); [ -n "$vm" ] && l1+="${SEP}${B}${vm}${R}"

# ---------- Line 2 ----------
parts=()
model=$(j '.model.display_name // .model.id')
[ -n "$model" ] && parts+=("${B}${MAG}${model}${R}")

effort=$(j '.effort.level')
[ -n "$effort" ] && parts+=("${DIM}effort${R} ${effort}")
[ "$(j '.thinking.enabled')" = "true" ] && parts+=("${DIM}thinking${R}")

used=$(j '.context_window.used_percentage')
if [ -n "$used" ]; then
  tok=$(echo "$input" | jq -r 'if .context_window.total_input_tokens != null and .context_window.context_window_size != null then " \((.context_window.total_input_tokens/1000)|floor)k/\((.context_window.context_window_size/1000)|floor)k" else "" end')
  c=$(pcol "$used")
  parts+=("${DIM}ctx${R} ${c}$(bar "$used") $(printf '%.0f' "$used")%${R}${DIM}${tok}${R}")
fi

five=$(j '.rate_limits.five_hour.used_percentage')
[ -n "$five" ] && parts+=("$(limit_seg 5h "$five" "$(j '.rate_limits.five_hour.resets_at')")")
week=$(j '.rate_limits.seven_day.used_percentage')
[ -n "$week" ] && parts+=("$(limit_seg 7d "$week" "$(j '.rate_limits.seven_day.resets_at')")")

spend=$(j '.rate_limits.spend_limit.used_percentage')
[ -n "$spend" ] && parts+=("$(limit_seg spend "$spend" "$(j '.rate_limits.spend_limit.resets_at')")")

cold=$(echo "$input" | jq -r 'if .prompt_cache.caching_observed == true and .prompt_cache.warm == false then (.prompt_cache.last_miss_cause.causes[0] // "cold") else empty end')
[ -n "$cold" ] && parts+=("${YEL}cache cold: ${cold}${R}")

l2=""
for p in "${parts[@]}"; do
  [ -n "$l2" ] && l2+="$SEP"
  l2+="$p"
done

printf '%s' "$l1"
[ -n "$l2" ] && printf '\n%s' "$l2"
exit 0
