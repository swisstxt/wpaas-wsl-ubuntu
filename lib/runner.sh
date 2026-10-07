#!/bin/bash
# Step runner: discovery, isolation, state, logs, answers, summary.
# Caller must set and export REPO_ROOT and source lib.sh first.

WPAAS_DIR="${WPAAS_DIR:-$HOME/.wpaas-installer}"
STATE_DIR="$WPAAS_DIR/state"
LOG_DIR="$WPAAS_DIR/logs"
ANSWERS_FILE="$WPAAS_DIR/answers.env"
STEPS_DIR="${STEPS_DIR:-$REPO_ROOT/steps}"

FORCE=0
NON_INTERACTIVE=0
ONLY=()
SKIP=()
RESULTS=()   # entries: "<id>|<status>|<log or empty>"

ANSWER_KEYS=(git_name git_email install_kubecontexts azure_email install_jetbrains)
declare -A ANSWER_PROMPTS=(
  [git_name]="Full name used as git author"
  [git_email]="Email address used as git author"
  [install_kubecontexts]="Install default k8s contexts? [y/N]"
  [azure_email]="swisstxt email address used for Azure auth (watch for capitalization)"
  [install_jetbrains]="Install Rider and IntelliJ IDEA (snap)? [y/N]"
)
declare -A ANSWERS=()

runner_init() {
  mkdir -p "$STATE_DIR" "$LOG_DIR"
  chmod 700 "$WPAAS_DIR"
}

runner_reset() {
  rm -rf "$WPAAS_DIR"
  echo "removed $WPAAS_DIR (state, logs and answers)"
}

# step_id <file>: "steps/15-certificates.sh" -> "certificates"
step_id() {
  local b
  b=$(basename "$1" .sh)
  echo "${b#*-}"
}

# step_meta <file> <key> <default>: reads "# key: value" from the file header
step_meta() {
  local v
  v=$(sed -nE "s/^# $2: *(.*)$/\1/p" "$1" | head -n1)
  echo "${v:-$3}"
}

discover_steps() {
  local f
  for f in "$STEPS_DIR"/[0-9]*-*.sh; do
    [ -e "$f" ] && echo "$f"
  done | sort
}

systemd_running() {
  if [ -n "${WPAAS_ASSUME_SYSTEMD:-}" ]; then
    [ "$WPAAS_ASSUME_SYSTEMD" = 1 ]
    return
  fi
  [ "$(ps --no-headers -o comm 1)" = "systemd" ]
}

in_list() {
  local x=$1 e
  shift
  for e in "$@"; do [ "$e" = "$x" ] && return 0; done
  return 1
}

record() { RESULTS+=("$1|$2|${3:-}"); }

# run_step <file>: returns 1 only when a required step failed (caller stops).
run_step() {
  local file=$1 id required needs_systemd rc log
  id=$(step_id "$file")
  required=$(step_meta "$file" required 0)
  needs_systemd=$(step_meta "$file" needs_systemd 0)
  log="$LOG_DIR/$id.log"

  if [ ${#ONLY[@]} -gt 0 ] && ! in_list "$id" "${ONLY[@]}"; then record "$id" "SKIPPED (flag)"; return 0; fi
  if [ ${#SKIP[@]} -gt 0 ] && in_list "$id" "${SKIP[@]}"; then record "$id" "SKIPPED (flag)"; return 0; fi
  if [ "$FORCE" -eq 0 ] && [ -e "$STATE_DIR/$id.done" ]; then record "$id" "SKIPPED (done)"; return 0; fi
  if [ "$needs_systemd" = 1 ] && ! systemd_running; then record "$id" "DEFERRED (systemd)"; return 0; fi

  echo
  echo "==> $id  (log: $log)"
  # Explicit stdin: the terminal when we have one, else nothing (never a pipe we own).
  local in=/dev/null
  if [ -t 0 ]; then in=/dev/tty; fi
  (cd "$REPO_ROOT" && bash -e -u -o pipefail "$file") <"$in" 2>&1 | tee "$log"
  rc=${PIPESTATUS[0]}
  if [ "$rc" -eq 0 ]; then
    date -u +%FT%TZ > "$STATE_DIR/$id.done"
    record "$id" OK
    return 0
  fi
  record "$id" FAILED "$log"
  if [ "$required" = 1 ]; then
    echo "required step '$id' failed (exit $rc), aborting" >&2
    return 1
  fi
  return 0
}

runner_run_all() {
  local f steps
  mapfile -t steps < <(discover_steps)
  for f in "${steps[@]}"; do
    run_step "$f" || break
  done
}

# runner_summary: prints the table, returns 1 if any step FAILED.
runner_summary() {
  local r id status log failed=0
  echo
  echo "Summary:"
  for r in "${RESULTS[@]}"; do
    IFS='|' read -r id status log <<<"$r"
    if [ -n "$log" ]; then
      printf '  %-24s %-20s %s\n' "$id" "$status" "$log"
    else
      printf '  %-24s %s\n' "$id" "$status"
    fi
    if [ "$status" = FAILED ]; then failed=1; fi
  done
  if [ "$failed" -eq 1 ]; then
    echo
    echo "Some steps failed. Fix the cause and rerun ./install.sh (done steps are skipped)."
  fi
  return "$failed"
}

answers_load() {
  [ -f "$ANSWERS_FILE" ] || return 0
  local k v
  while IFS='=' read -r k v; do
    [ -n "$k" ] && ANSWERS[$k]=$v
  done < "$ANSWERS_FILE"
}

answers_save() {
  local k
  : > "$ANSWERS_FILE"
  chmod 600 "$ANSWERS_FILE"
  for k in "${ANSWER_KEYS[@]}"; do
    if [ -n "${ANSWERS[$k]+x}" ]; then printf '%s=%s\n' "$k" "${ANSWERS[$k]}" >> "$ANSWERS_FILE"; fi
  done
}

# answer_needed <key>: azure_email is only needed when kube contexts are wanted
answer_needed() {
  case $1 in
    azure_email) [ "${ANSWERS[install_kubecontexts]:-n}" = y ] ;;
    *) return 0 ;;
  esac
}

# answers_collect: env WPAAS_<KEY> > answers.env > prompt. Exports WPAAS_<KEY>.
answers_collect() {
  local k env v
  answers_load
  for k in "${ANSWER_KEYS[@]}"; do
    env="WPAAS_${k^^}"
    if [ -n "${!env:-}" ]; then
      ANSWERS[$k]=${!env}
      continue
    fi
    if [ -n "${ANSWERS[$k]+x}" ]; then continue; fi
    answer_needed "$k" || continue
    if [ "$NON_INTERACTIVE" -eq 1 ]; then
      echo "missing answer $k (set $env)" >&2
      return 1
    fi
    case $k in
      install_*)
        read -r -p "${ANSWER_PROMPTS[$k]}: " v
        case $v in [Yy]*) v=y ;; *) v=n ;; esac ;;
      *)
        v=""
        while [ -z "$v" ]; do read -r -p "${ANSWER_PROMPTS[$k]}: " v || return 1; done ;;
    esac
    ANSWERS[$k]=$v
  done
  answers_save
  for k in "${ANSWER_KEYS[@]}"; do
    if [ -n "${ANSWERS[$k]+x}" ]; then export "WPAAS_${k^^}=${ANSWERS[$k]}"; fi
  done
  return 0
}
