# Ubuntu 26.04 Resilient Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the chain of sourced `install_*.sh` scripts with a step runner that isolates failures, records state for cheap reruns, and targets Ubuntu 26.04 (resolute) with proxy configuration removed and Claude Code / Codex CLIs added.

**Architecture:** `install.sh` is a thin orchestrator over `lib/runner.sh`, which discovers `steps/NN-<name>.sh`, runs each in its own `bash -e -u -o pipefail` child with output teed to a log, writes a `.done` marker on success, and prints a summary. Answers to prompts are collected once up front and persisted. `bootstrap.ps1` installs the `.wsl` image under `ubuntu-wpaas-resolute`, installs the nerd font, configures the Windows Terminal profile, and runs `install.sh` twice (second run picks up systemd-deferred steps).

**Tech Stack:** bash 5, shellcheck, docker (for the `ubuntu:26.04` smoke test), Windows PowerShell 5.1 (bootstrap must stay 5.1-compatible), WSL 2.4.4+.

Spec: `docs/superpowers/specs/2026-10-07-ubuntu-2604-resilient-installer-design.md`

## Global Constraints

- Target release: Ubuntu 26.04.1 LTS, codename `resolute`. Image URL `https://releases.ubuntu.com/26.04/ubuntu-26.04.1-wsl-amd64.wsl`. No 24.04 support.
- Distro name: `ubuntu-wpaas-resolute` (pattern `ubuntu-wpaas-<codename>`). Never read or modify other WSL distributions.
- No proxy configuration anywhere (no `HTTP_PROXY`, apt proxy, npm proxy, git proxy, docker proxy, gradle proxy). CA certificates are still installed for system, Java, Node and Python requests.
- Versions: kubectl minor `1.34` (variable `KUBECTL_MINOR`), helm pin `4.*` (variable `HELM_MAJOR=4`), temurin `11 17 21 25` with highest LTS present as default, Node `n lts`, dotnet = newest `dotnet-sdk-X.Y` apt can see after adding `ppa:dotnet/backports`.
- Font face: `CaskaydiaCove Nerd Font Mono`, from the `CascadiaCode.zip` asset of the latest `ryanoasis/nerd-fonts` release, installed per-user.
- State lives in `~/.wpaas-installer/{state,logs,answers.env}`. Answer keys: `git_name`, `git_email`, `install_kubecontexts`, `azure_email`, `install_jetbrains`; env override `WPAAS_<KEY_UPPERCASED>`.
- Step file header keys: `# step:`, `# required:`, `# needs_systemd:`, `# needs_answers:`.
- Summary statuses: `OK`, `FAILED`, `SKIPPED (done)`, `SKIPPED (flag)`, `DEFERRED (systemd)`.
- Every shell file passes `shellcheck -x -S warning`.
- `sudo` must never receive `VAR=value` arguments (sudo-rs on 26.04 rejects them under `env_reset`); use `sudo env VAR=value cmd`.
- Commit messages end with `Claude-Session: https://claude.ai/code/session_01Lyq6efnKY8j7J228cYywDM`.

---

## File structure

| Path | Responsibility |
|---|---|
| `install.sh` | argument parsing, sudo priming, calls runner |
| `lib/runner.sh` | step discovery, header parsing, isolation, state, logs, answers, summary |
| `lib.sh` | shared helpers for steps: `retry`, `apt_get`, `apt_install`, `apt_update`, `install_file`, `fetch_keyring`, `write_apt_list`, `write_apt_pin`, `os_codename`, plus the two existing helpers |
| `vars.sh` | version knobs only |
| `steps/NN-<name>.sh` | one step each, see spec table |
| `bin/wslview` | URL opener wrapper replacing wslu |
| `profile.d/*.sh` | login environment (proxy file removed, kubeconfig rewritten) |
| `test/lint.sh` | shellcheck over all shell files |
| `test/runner-test.sh` | runner behaviour against dummy steps |
| `test/docker-smoke.sh` | real-repo run inside `ubuntu:26.04` |
| `bootstrap.ps1` | Windows side |
| `README.md` | user documentation |

Removed at the end: all `install_*.sh`, `post_install*.sh`, `apt/`, `systemd/`, `profile.d/http_proxy_env.sh`, `profile.d/node_ssl.sh`, `.vscode-server/`.

---

### Task 1: Step runner, orchestrator and runner test

**Files:**
- Create: `lib/runner.sh`
- Create: `install.sh` (overwrite existing)
- Create: `test/runner-test.sh`
- Modify: `lib.sh` (add `retry`)

**Interfaces:**
- Produces: `retry <n> <cmd...>` (lib.sh). Runner globals `WPAAS_DIR`, `STATE_DIR`, `LOG_DIR`, `ANSWERS_FILE`, `STEPS_DIR`, arrays `ONLY`, `SKIP`, flags `FORCE`, `NON_INTERACTIVE`. Functions `runner_init`, `runner_reset`, `step_id <file>`, `step_meta <file> <key> <default>`, `discover_steps`, `systemd_running`, `run_step <file>`, `runner_run_all`, `runner_summary`, `answers_collect`. Steps receive `REPO_ROOT` and `WPAAS_<KEY>` in their environment and run with cwd = repo root.
- Env overrides used by tests: `WPAAS_DIR`, `STEPS_DIR`, `WPAAS_ASSUME_SYSTEMD` (0/1), `WPAAS_NO_SUDO=1` (skip sudo priming).

- [ ] **Step 1: Write the failing runner test**

Create `test/runner-test.sh`:

```bash
#!/bin/bash
# Exercises lib/runner.sh through install.sh using dummy steps in a temp dir.
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export WPAAS_DIR="$TMP/wpaas"
export STEPS_DIR="$TMP/steps"
export WPAAS_ASSUME_SYSTEMD=0
export WPAAS_NO_SUDO=1
export WPAAS_GIT_NAME="Test User"
export WPAAS_GIT_EMAIL="test@example.com"
export WPAAS_INSTALL_KUBECONTEXTS=n
export WPAAS_INSTALL_JETBRAINS=n
mkdir -p "$STEPS_DIR"

fails=0
assert_eq()      { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$3' got '$2'"; fails=$((fails+1)); fi; }
assert_match()   { if grep -qE -- "$3" <<<"$2"; then echo "ok   $1"; else echo "FAIL $1: /$3/ not found"; fails=$((fails+1)); fi; }
assert_nomatch() { if grep -qE -- "$3" <<<"$2"; then echo "FAIL $1: /$3/ unexpectedly found"; fails=$((fails+1)); else echo "ok   $1"; fi; }
assert_file()    { if [ -e "$2" ]; then echo "ok   $1"; else echo "FAIL $1: $2 missing"; fails=$((fails+1)); fi; }
assert_nofile()  { if [ -e "$2" ]; then echo "FAIL $1: $2 exists"; fails=$((fails+1)); else echo "ok   $1"; fi; }

cat > "$STEPS_DIR/10-alpha.sh" <<'S'
#!/bin/bash
# step: alpha
echo "alpha ran as $WPAAS_GIT_NAME in $PWD"
S
cat > "$STEPS_DIR/20-beta.sh" <<'S'
#!/bin/bash
# step: beta
echo "beta fails"
exit 3
S
cat > "$STEPS_DIR/30-gamma.sh" <<'S'
#!/bin/bash
# step: gamma
# needs_systemd: 1
echo "gamma ran"
S
cat > "$STEPS_DIR/40-delta.sh" <<'S'
#!/bin/bash
# step: delta
echo "delta ran"
S

run() { bash "$REPO_ROOT/install.sh" "$@" 2>&1; }

echo "--- run 1: fresh"
out=$(run --non-interactive); rc=$?
assert_eq    "exit 1 when a step failed" "$rc" 1
assert_match "answers exported to steps" "$out" "alpha ran as Test User in $REPO_ROOT"
assert_match "alpha OK" "$out" "^ +alpha +OK"
assert_match "beta FAILED with log path" "$out" "^ +beta +FAILED +$WPAAS_DIR/logs/beta.log"
assert_match "gamma DEFERRED" "$out" "^ +gamma +DEFERRED \(systemd\)"
assert_match "delta OK" "$out" "^ +delta +OK"
assert_file   "alpha.done" "$WPAAS_DIR/state/alpha.done"
assert_nofile "beta.done absent" "$WPAAS_DIR/state/beta.done"
assert_nofile "gamma.done absent" "$WPAAS_DIR/state/gamma.done"
assert_file   "beta log" "$WPAAS_DIR/logs/beta.log"
assert_match  "beta log content" "$(cat "$WPAAS_DIR/logs/beta.log")" "beta fails"
assert_file   "answers.env" "$WPAAS_DIR/answers.env"
assert_eq     "answers.env mode" "$(stat -c %a "$WPAAS_DIR/answers.env")" 600
assert_match  "answers.env content" "$(cat "$WPAAS_DIR/answers.env")" "^git_name=Test User$"

echo "--- run 2: rerun with systemd"
out=$(WPAAS_ASSUME_SYSTEMD=1 run --non-interactive); rc=$?
assert_match "alpha skipped (done)" "$out" "^ +alpha +SKIPPED \(done\)"
assert_match "beta fails again" "$out" "^ +beta +FAILED"
assert_match "gamma OK now" "$out" "^ +gamma +OK"
assert_match "delta skipped (done)" "$out" "^ +delta +SKIPPED \(done\)"

echo "--- run 3: answers persisted"
out=$(env -u WPAAS_GIT_NAME -u WPAAS_GIT_EMAIL -u WPAAS_INSTALL_KUBECONTEXTS -u WPAAS_INSTALL_JETBRAINS bash "$REPO_ROOT/install.sh" --non-interactive --only alpha --force 2>&1); rc=$?
assert_eq    "exit 0 with persisted answers" "$rc" 0
assert_match "alpha reran from file answers" "$out" "alpha ran as Test User"

echo "--- run 4: --only and --force"
out=$(run --non-interactive --only alpha --force); rc=$?
assert_eq    "exit 0" "$rc" 0
assert_match "alpha OK" "$out" "^ +alpha +OK"
assert_match "beta skipped (flag)" "$out" "^ +beta +SKIPPED \(flag\)"
assert_match "delta skipped (flag)" "$out" "^ +delta +SKIPPED \(flag\)"

echo "--- run 5: --skip"
out=$(run --non-interactive --skip beta); rc=$?
assert_eq    "exit 0 when failing step skipped" "$rc" 0
assert_match "beta skipped (flag)" "$out" "^ +beta +SKIPPED \(flag\)"

echo "--- run 6: --list"
out=$(run --list)
assert_match "list shows alpha" "$out" "^alpha +required=0 needs_systemd=0"
assert_match "list shows gamma" "$out" "^gamma +required=0 needs_systemd=1"

echo "--- run 7: required step aborts"
cat > "$STEPS_DIR/50-epsilon.sh" <<'S'
#!/bin/bash
# step: epsilon
# required: 1
echo "epsilon fails"
exit 1
S
cat > "$STEPS_DIR/60-zeta.sh" <<'S'
#!/bin/bash
# step: zeta
echo "zeta ran"
S
out=$(run --non-interactive --force --skip beta); rc=$?
assert_eq      "exit 1 on required failure" "$rc" 1
assert_match   "epsilon FAILED" "$out" "^ +epsilon +FAILED"
assert_nomatch "zeta not run after required failure" "$out" "zeta"

echo "--- run 8: --reset and missing answer"
out=$(run --reset)
assert_nofile "state dir removed" "$WPAAS_DIR/state"
out=$(env -u WPAAS_GIT_NAME bash "$REPO_ROOT/install.sh" --non-interactive 2>&1); rc=$?
assert_eq    "exit 2 on missing answer" "$rc" 2
assert_match "names the missing answer" "$out" "missing answer git_name \(set WPAAS_GIT_NAME\)"

echo
if [ "$fails" -eq 0 ]; then echo "ALL OK"; else echo "$fails FAILED"; exit 1; fi
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash test/runner-test.sh`
Expected: many `FAIL` lines (install.sh still sources the old scripts and knows no `--non-interactive`), final line `N FAILED`, exit 1.

- [ ] **Step 3: Add `retry` to lib.sh**

Append to `lib.sh`:

```bash
# retry <n> <cmd...>: run cmd up to n times with a growing pause between tries.
retry() {
  local n=$1 i=1
  shift
  until "$@"; do
    if [ "$i" -ge "$n" ]; then
      echo "retry: giving up after $n attempts: $*" >&2
      return 1
    fi
    echo "retry: attempt $i/$n failed, retrying: $*" >&2
    sleep $((i * 2))
    i=$((i + 1))
  done
}
```

Also add `#!/bin/bash` as the first line of `lib.sh` (shellcheck needs it, the file is only ever sourced).

- [ ] **Step 4: Write lib/runner.sh**

Create `lib/runner.sh`:

```bash
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
  (cd "$REPO_ROOT" && bash -e -u -o pipefail "$file") 2>&1 | tee "$log"
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
  local f
  while read -r f; do
    run_step "$f" || break
  done < <(discover_steps)
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
    read -r -p "${ANSWER_PROMPTS[$k]}: " v
    case $k in
      install_*) case $v in [Yy]*) v=y ;; *) v=n ;; esac ;;
    esac
    ANSWERS[$k]=$v
  done
  answers_save
  for k in "${ANSWER_KEYS[@]}"; do
    if [ -n "${ANSWERS[$k]+x}" ]; then export "WPAAS_${k^^}=${ANSWERS[$k]}"; fi
  done
  return 0
}
```

- [ ] **Step 5: Write the new install.sh**

Overwrite `install.sh`:

```bash
#!/bin/bash
# WPAAS WSL installer. Runs every steps/NN-<name>.sh in order, isolating failures.
# See README.md for usage and docs/superpowers/specs/ for the design.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT
cd "$REPO_ROOT" || exit 1

. ./vars.sh
. ./lib.sh
. ./lib/runner.sh

usage() {
  cat <<USAGE
Usage: $0 [options]
  --list              list steps and exit
  --only <step>       run only this step (repeatable)
  --skip <step>       skip this step (repeatable)
  --force             rerun selected steps even if already done
  --reset             delete state, logs and answers, then exit
  --non-interactive   never prompt; a missing answer is an error (exit 2)
  -h, --help          show this help

Answers can be pre-seeded through the environment:
  WPAAS_GIT_NAME, WPAAS_GIT_EMAIL, WPAAS_INSTALL_KUBECONTEXTS (y/n),
  WPAAS_AZURE_EMAIL, WPAAS_INSTALL_JETBRAINS (y/n)
State, logs and answers live in ~/.wpaas-installer.
USAGE
}

LIST=0
while [ $# -gt 0 ]; do
  case $1 in
    --list) LIST=1 ;;
    --only) ONLY+=("$2"); shift ;;
    --skip) SKIP+=("$2"); shift ;;
    --force) FORCE=1 ;;
    --reset) runner_reset; exit 0 ;;
    --non-interactive) NON_INTERACTIVE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

if [ "$LIST" -eq 1 ]; then
  while read -r f; do
    printf '%-24s required=%s needs_systemd=%s\n' \
      "$(step_id "$f")" "$(step_meta "$f" required 0)" "$(step_meta "$f" needs_systemd 0)"
  done < <(discover_steps)
  exit 0
fi

runner_init
answers_collect || exit 2

# Prime sudo once and keep it alive so an unattended run never stalls on a password prompt.
if [ -z "${WPAAS_NO_SUDO:-}" ] && command -v sudo >/dev/null; then
  sudo -v || exit 1
  ( while true; do sudo -n true; sleep 60; done ) 2>/dev/null &
  SUDO_KEEPALIVE=$!
  trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null' EXIT
fi

runner_run_all
runner_summary
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `bash test/runner-test.sh`
Expected: every line starts with `ok`, final line `ALL OK`, exit 0.

- [ ] **Step 7: Commit**

```bash
git add lib/runner.sh install.sh lib.sh test/runner-test.sh
git commit -m "Add step runner with state, logs and up-front answers

Claude-Session: https://claude.ai/code/session_01Lyq6efnKY8j7J228cYywDM"
```

Note: `install.sh` no longer sources the old `install_*.sh` files; they are deleted in Task 6. Until then the old scripts are dead code.

---

### Task 2: Shared step helpers, version knobs and lint

**Files:**
- Modify: `lib.sh` (add helpers)
- Create: `vars.sh` (overwrite existing)
- Create: `test/lint.sh`

**Interfaces:**
- Produces (lib.sh): `apt_get <args...>`, `apt_install <pkgs...>`, `apt_update`, `install_file <src> <dst> [mode]`, `fetch_keyring <url> <dst>`, `write_apt_list <name> <line>`, `write_apt_pin <name> <package> <version-glob>`, `os_codename`.
- Produces (vars.sh): `KUBECTL_MINOR`, `HELM_MAJOR`, `TEMURIN_VERSIONS`, `TEMURIN_LTS`, `NODE_VERSION`, all exported.

- [ ] **Step 1: Write test/lint.sh**

```bash
#!/bin/bash
# Runs shellcheck over every shell file in the repo. Warnings fail the build.
set -u
cd "$(dirname "$0")/.." || exit 1
if ! command -v shellcheck >/dev/null; then
  echo "shellcheck is missing: sudo apt-get install -y shellcheck" >&2
  exit 2
fi
files=(install.sh lib.sh vars.sh lib/runner.sh bin/wslview)
for f in steps/*.sh test/*.sh profile.d/*.sh; do [ -e "$f" ] && files+=("$f"); done
shellcheck -x -S warning "${files[@]}" && echo "lint OK"
```

- [ ] **Step 2: Install shellcheck and run lint to see it fail**

Run: `sudo apt-get install -y shellcheck && bash test/lint.sh`
Expected: shellcheck errors (`bin/wslview` does not exist yet, `vars.sh` has no shebang, `profile.d/kubeconfig.sh` warns on `ls` parsing), exit non-zero.

- [ ] **Step 3: Write vars.sh**

Overwrite `vars.sh`:

```bash
#!/bin/bash
# Version knobs for the installer. Sourced by install.sh, exported to every step.
KUBECTL_MINOR="1.34"         # pkgs.k8s.io repo and apt pin: kubectl ${KUBECTL_MINOR}.*
HELM_MAJOR="4"               # apt pin: helm ${HELM_MAJOR}.*
TEMURIN_VERSIONS="11 17 21 25"  # temurin-<v>-jdk packages to install
TEMURIN_LTS="11 17 21 25"       # ascending; the highest one installed becomes the default java
NODE_VERSION="lts"           # argument to `n`
export KUBECTL_MINOR HELM_MAJOR TEMURIN_VERSIONS TEMURIN_LTS NODE_VERSION
```

- [ ] **Step 4: Add helpers to lib.sh**

Append to `lib.sh` (after `retry`):

```bash
# os_codename: "resolute"
os_codename() {
  # shellcheck disable=SC1091
  (. /etc/os-release && echo "$VERSION_CODENAME")
}

# apt_get <args...>: non-interactive apt-get with download retries.
# Uses `sudo env VAR=..` because sudo-rs rejects VAR=.. arguments under env_reset.
apt_get() {
  sudo env DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=3 "$@"
}

apt_install() { apt_get install -y "$@"; }

apt_update() { retry 3 apt_get update; }

# install_file <src> <dst> [mode]: copy as root only when missing or different.
install_file() {
  local src=$1 dst=$2 mode=${3:-0644}
  if does_not_exists_or_is_different "$dst" "$src"; then
    echo "installing $dst"
    sudo install -D -m "$mode" "$src" "$dst"
  else
    echo "$dst is up to date"
  fi
}

# fetch_keyring <url> <dst>: download an ASCII-armored key once, store dearmored.
fetch_keyring() {
  local url=$1 dst=$2 tmp
  if [ -s "$dst" ]; then
    echo "keyring $dst present"
    return 0
  fi
  tmp=$(mktemp)
  retry 3 curl -fsSL "$url" -o "$tmp.asc"
  gpg --dearmor < "$tmp.asc" > "$tmp"
  sudo install -D -m 0644 "$tmp" "$dst"
  rm -f "$tmp" "$tmp.asc"
}

# write_apt_list <name> <line>: /etc/apt/sources.list.d/<name>.list is overwritten, never appended.
write_apt_list() {
  local tmp
  tmp=$(mktemp)
  printf '%s\n' "$2" > "$tmp"
  install_file "$tmp" "/etc/apt/sources.list.d/$1.list"
  rm -f "$tmp"
}

# write_apt_pin <name> <package> <version-glob>: /etc/apt/preferences.d/<name>
write_apt_pin() {
  local tmp
  tmp=$(mktemp)
  printf 'Package: %s\nPin: version %s\nPin-Priority: 1000\n' "$2" "$3" > "$tmp"
  install_file "$tmp" "/etc/apt/preferences.d/$1"
  rm -f "$tmp"
}
```

- [ ] **Step 5: Rewrite profile.d/kubeconfig.sh and create a placeholder-free bin/wslview**

Overwrite `profile.d/kubeconfig.sh`:

```bash
#!/bin/bash
mkdir -p ~/.kube
touch ~/.kube/config ~/.kube/empty.config
chmod go-r ~/.kube/config ~/.kube/*.config

KUBECONFIG=~/.kube/config
for f in ~/.kube/*.config; do
  KUBECONFIG="$KUBECONFIG:$f"
done
export KUBECONFIG
export KUBECONFIG_INSTALLED=yes
```

Create `bin/wslview` (mode 0755), the real wrapper from the spec:

```bash
#!/bin/bash
# Opens a URL or local path with the Windows default handler. Replaces wslu's wslview.
set -eu
if [ $# -ne 1 ]; then
  echo "usage: wslview <url|path>" >&2
  exit 2
fi
target=$1
case $target in
  http://*|https://*|mailto:*) ;;
  *)
    if [ -e "$target" ]; then
      target=$(wslpath -w "$(realpath "$target")")
    fi
    ;;
esac
exec /mnt/c/Windows/System32/rundll32.exe url.dll,FileProtocolHandler "$target"
```

Run: `chmod +x bin/wslview`

- [ ] **Step 6: Run lint and the runner test**

Run: `bash test/lint.sh && bash test/runner-test.sh`
Expected: `lint OK` and `ALL OK`. If shellcheck reports warnings in other `profile.d` files, fix them in place (they are short) rather than excluding files.

- [ ] **Step 7: Commit**

```bash
git add lib.sh vars.sh test/lint.sh profile.d/kubeconfig.sh bin/wslview
git commit -m "Add apt/file helpers, version knobs, wslview wrapper and shellcheck lint

Claude-Session: https://claude.ai/code/session_01Lyq6efnKY8j7J228cYywDM"
```

---

### Task 3: Base steps and the docker smoke harness

**Files:**
- Create: `steps/10-home.sh`, `steps/15-certificates.sh`, `steps/20-profile.sh`, `steps/25-apt-base.sh`, `steps/30-essentials.sh`, `steps/70-wslconf.sh`, `steps/75-bin.sh`, `steps/95-tools.sh`, `steps/100-powerline.sh`, `steps/215-binfmt.sh`
- Create: `test/docker-smoke.sh`
- Delete: `profile.d/http_proxy_env.sh`, `profile.d/node_ssl.sh`
- Modify: `home/.gradle/gradle.properties` (remove the four `systemProp.*proxy*` lines; leave the other lines untouched)

**Interfaces:**
- Consumes: lib.sh helpers from Task 2, `WPAAS_GIT_NAME`, `WPAAS_GIT_EMAIL` from the runner.
- Produces: `/etc/nodecerts.pem` (used by `profile.d/node_certs.sh`), `/usr/local/bin/wslview`.

- [ ] **Step 1: Write test/docker-smoke.sh**

```bash
#!/bin/bash
# Runs install.sh non-interactively inside ubuntu:26.04 against the real repositories.
# Steps needing systemd report DEFERRED there. Extra arguments are passed to install.sh,
# e.g.: test/docker-smoke.sh --only certificates --only apt-base
set -u
cd "$(dirname "$0")/.." || exit 1
docker run --rm -t \
  -v "$PWD:/installer:ro" \
  -e WPAAS_NO_SUDO=1 \
  -e WPAAS_GIT_NAME="Smoke Test" \
  -e WPAAS_GIT_EMAIL="smoke@example.com" \
  -e WPAAS_INSTALL_KUBECONTEXTS=y \
  -e WPAAS_AZURE_EMAIL="smoke@swisstxt.ch" \
  -e WPAAS_INSTALL_JETBRAINS=n \
  -e INSTALL_ARGS="$*" \
  ubuntu:26.04 bash -c '
    set -e
    apt-get update -qq && apt-get install -y -qq sudo >/dev/null
    useradd -m -s /bin/bash smoke
    echo "smoke ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/smoke
    cp -r /installer /home/smoke/installer && chown -R smoke:smoke /home/smoke/installer
    exec su - smoke -c "cd ~/installer && bash install.sh --non-interactive $INSTALL_ARGS"
  '
```

- [ ] **Step 2: Run the smoke test to see it do nothing useful yet**

Run: `bash test/docker-smoke.sh`
Expected: an empty `Summary:` (no steps exist yet), exit 0.

- [ ] **Step 3: Write the base steps**

`steps/10-home.sh`:

```bash
#!/bin/bash
# step: home
# Copies everything under home/ into $HOME, keeping the relative layout.
. "$REPO_ROOT/lib.sh"
while IFS= read -r -d '' f; do
  target="$HOME/${f#home/}"
  mkdir -p "$(dirname "$target")"
  cp "$f" "$target"
  echo "installed $target"
done < <(find home -type f -print0)
```

`steps/15-certificates.sh`:

```bash
#!/bin/bash
# step: certificates
# required: 1
# Installs the corporate CA certificates into the system store and builds the Node bundle.
. "$REPO_ROOT/lib.sh"
package_installed ca-certificates || apt_install ca-certificates

# update-ca-certificates only picks up *.crt, so bundles in *.pem are installed under a .crt name.
for cert in certificates/*.crt certificates/*.pem; do
  [ -e "$cert" ] || continue
  name=$(basename "$cert")
  name="${name%.pem}.crt"
  install_file "$cert" "/usr/local/share/ca-certificates/$name"
done
sudo update-ca-certificates

# All local CA certs as one PEM bundle for NODE_EXTRA_CA_CERTS (profile.d/node_certs.sh).
tmp=$(mktemp)
cat /usr/local/share/ca-certificates/*.crt > "$tmp"
install_file "$tmp" /etc/nodecerts.pem
rm -f "$tmp"
```

`steps/20-profile.sh`:

```bash
#!/bin/bash
# step: profile
# Installs login environment snippets into /etc/profile.d and removes retired ones.
. "$REPO_ROOT/lib.sh"
for script in profile.d/*.sh; do
  install_file "$script" "/etc/profile.d/$(basename "$script")"
done
sudo rm -f /etc/profile.d/http_proxy_env.sh /etc/profile.d/node_ssl.sh
```

`steps/25-apt-base.sh`:

```bash
#!/bin/bash
# step: apt-base
# required: 1
# Base tooling every later step relies on.
. "$REPO_ROOT/lib.sh"
apt_update
apt_install ca-certificates curl wget gnupg unzip apt-transport-https \
  software-properties-common lsb-release snapd pkg-config bash-completion
sudo mkdir -p -m 755 /etc/apt/keyrings
```

`steps/30-essentials.sh`:

```bash
#!/bin/bash
# step: essentials
# needs_answers: git_name git_email
. "$REPO_ROOT/lib.sh"
apt_install git build-essential git-flow
git config --global --unset-all http.proxy || true
git config --global user.name "$WPAAS_GIT_NAME"
git config --global user.email "$WPAAS_GIT_EMAIL"
git config --global --get user.email
```

`steps/70-wslconf.sh`:

```bash
#!/bin/bash
# step: wslconf
. "$REPO_ROOT/lib.sh"
install_file wsl.conf /etc/wsl.conf
```

`steps/75-bin.sh`:

```bash
#!/bin/bash
# step: bin
# Helper scripts (including the wslview wrapper) into /usr/local/bin.
. "$REPO_ROOT/lib.sh"
for f in bin/*; do
  install_file "$f" "/usr/local/bin/$(basename "$f")" 0755
done
```

`steps/95-tools.sh`:

```bash
#!/bin/bash
# step: tools
# Small CLI tools, python3, hushlogin and the VS Code server settings.
. "$REPO_ROOT/lib.sh"
apt_install gh jq ffmpeg mediainfo python3 python3-pip python3-venv python3-virtualenv python-is-python3
gh extension install https://github.com/nektos/gh-act || echo "gh-act: already installed or install failed (non-fatal)"
touch ~/.hushlogin
mkdir -p ~/.vscode-server/data/Machine
cp vscode_settings.json ~/.vscode-server/data/Machine/settings.json
```

`steps/100-powerline.sh`:

```bash
#!/bin/bash
# step: powerline
# Always installed: bootstrap.ps1 guarantees the nerd font on the Windows side.
. "$REPO_ROOT/lib.sh"
apt_install powerline powerline-gitstatus
```

`steps/215-binfmt.sh`:

```bash
#!/bin/bash
# step: binfmt
# needs_systemd: 1
# Lets systemd-binfmt keep running Windows executables from WSL.
. "$REPO_ROOT/lib.sh"
tmp=$(mktemp)
echo ':WSLInterop:M::MZ::/init:PF' > "$tmp"
install_file "$tmp" /usr/lib/binfmt.d/WSLInterop.conf
rm -f "$tmp"
sudo systemctl restart systemd-binfmt
```

- [ ] **Step 4: Remove proxy artifacts from profile.d and gradle properties**

```bash
git rm profile.d/http_proxy_env.sh profile.d/node_ssl.sh
sed -i '/^systemProp\.https\?\.proxy/d' home/.gradle/gradle.properties
```

- [ ] **Step 5: Lint and smoke-test the base steps**

Run: `bash test/lint.sh && bash test/docker-smoke.sh`
Expected: `lint OK`; smoke summary shows `home`, `certificates`, `profile`, `apt-base`, `essentials`, `wslconf`, `bin`, `tools`, `powerline` as `OK` and `binfmt` as `DEFERRED (systemd)`; exit 0.

- [ ] **Step 6: Commit**

```bash
git add steps test/docker-smoke.sh home/.gradle/gradle.properties
git commit -m "Add base steps (certs, apt, profile, tools) and docker smoke harness

Claude-Session: https://claude.ai/code/session_01Lyq6efnKY8j7J228cYywDM"
```

---

### Task 4: Toolchain steps (kubectl, helm, node, dotnet, jdk, java certs)

**Files:**
- Create: `steps/35-kubectl.sh`, `steps/40-helm.sh`, `steps/45-nodejs.sh`, `steps/50-dotnet.sh`, `steps/55-jdk.sh`, `steps/60-java-certs.sh`

**Interfaces:**
- Consumes: `KUBECTL_MINOR`, `HELM_MAJOR`, `TEMURIN_VERSIONS`, `TEMURIN_LTS`, `NODE_VERSION` from vars.sh; `fetch_keyring`, `write_apt_list`, `write_apt_pin`, `os_codename`, `apt_*`, `retry` from lib.sh.

- [ ] **Step 1: Write the steps**

`steps/35-kubectl.sh`:

```bash
#!/bin/bash
# step: kubectl
# kubectl from pkgs.k8s.io pinned to KUBECTL_MINOR, plus kubelogin for Azure AD.
. "$REPO_ROOT/lib.sh"
fetch_keyring "https://pkgs.k8s.io/core:/stable:/v${KUBECTL_MINOR}/deb/Release.key" \
  /etc/apt/keyrings/kubernetes-apt-keyring.gpg
write_apt_list kubernetes \
  "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBECTL_MINOR}/deb/ /"
write_apt_pin kubectl kubectl "${KUBECTL_MINOR}.*"
apt_update
apt_install kubectl

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
retry 3 curl -fsSL https://github.com/Azure/kubelogin/releases/latest/download/kubelogin-linux-amd64.zip -o "$tmp/kubelogin.zip"
unzip -q -o "$tmp/kubelogin.zip" -d "$tmp"
sudo install -m 0755 "$tmp/bin/linux_amd64/kubelogin" /usr/local/bin/kubelogin

kubectl version --client
kubelogin --version
```

`steps/40-helm.sh`:

```bash
#!/bin/bash
# step: helm
. "$REPO_ROOT/lib.sh"
fetch_keyring https://packages.buildkite.com/helm-linux/helm-debian/gpgkey /usr/share/keyrings/helm.gpg
write_apt_list helm-stable-debian \
  "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main"
write_apt_pin helm helm "${HELM_MAJOR}.*"
apt_update
apt_install helm
helm version
```

`steps/45-nodejs.sh`:

```bash
#!/bin/bash
# step: nodejs
# Distro node/npm bootstrap `n`, which then installs the wanted release into /usr/local.
. "$REPO_ROOT/lib.sh"
apt_install nodejs npm
sudo npm install -g n
sudo n "$NODE_VERSION"
# TLS goes through NODE_EXTRA_CA_CERTS (profile.d/node_certs.sh); no proxy, strict ssl stays on.
npm config delete proxy
npm config delete https-proxy
npm config set strict-ssl true
hash -r
/usr/local/bin/node --version
```

`steps/50-dotnet.sh`:

```bash
#!/bin/bash
# step: dotnet
# Newest dotnet-sdk the archive plus the backports PPA can offer (10.0 at the time of writing).
. "$REPO_ROOT/lib.sh"
sudo add-apt-repository -y ppa:dotnet/backports
apt_update
latest=$(apt-cache search --names-only '^dotnet-sdk-[0-9]+\.[0-9]+$' | cut -d' ' -f1 | sort -V | tail -n1)
if [ -z "$latest" ]; then
  echo "no dotnet-sdk package found" >&2
  exit 1
fi
echo "installing $latest"
apt_install "$latest"
dotnet --list-sdks
```

`steps/55-jdk.sh`:

```bash
#!/bin/bash
# step: jdk
# Temurin JDKs from Adoptium; the highest LTS present becomes the default java/javac.
. "$REPO_ROOT/lib.sh"
fetch_keyring https://packages.adoptium.net/artifactory/api/gpg/key/public /etc/apt/keyrings/adoptium.gpg
write_apt_list adoptium \
  "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(os_codename) main"
apt_update
pkgs=()
for v in $TEMURIN_VERSIONS; do pkgs+=("temurin-${v}-jdk"); done
apt_install "${pkgs[@]}"

default=""
for v in $TEMURIN_LTS; do
  bin="/usr/lib/jvm/temurin-${v}-jdk-amd64/bin/java"
  if [ -x "$bin" ]; then default=$bin; fi
done
if [ -z "$default" ]; then
  echo "no temurin LTS found under /usr/lib/jvm" >&2
  exit 1
fi
sudo update-alternatives --set java "$default"
sudo update-alternatives --set javac "${default%java}javac"
java -version
```

`steps/60-java-certs.sh`:

```bash
#!/bin/bash
# step: java-certs
# Imports the corporate CAs into every Temurin keystore, skipping certs already present.
. "$REPO_ROOT/lib.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Split every source file into single-certificate files (bundles contain several).
for f in certificates/*.crt certificates/*.pem; do
  [ -e "$f" ] || continue
  awk -v out="$tmp/$(basename "$f")" '/-----BEGIN CERTIFICATE-----/{n++} {print > (out "." n)}' "$f"
done

for kt in /usr/lib/jvm/temurin-*-jdk-amd64/bin/keytool; do
  [ -x "$kt" ] || continue
  existing=$(sudo "$kt" -list -cacerts -storepass changeit -v 2>/dev/null | sed -nE 's/^[[:space:]]*SHA256: *//p')
  for c in "$tmp"/*; do
    grep -q 'BEGIN CERTIFICATE' "$c" || continue   # fragment before the first cert holds no certificate
    fp=$(openssl x509 -in "$c" -noout -fingerprint -sha256 | cut -d= -f2)
    if grep -qxF "$fp" <<<"$existing"; then
      echo "$(basename "$c") already in $kt"
      continue
    fi
    alias="wpaas-$(tr -d ':' <<<"$fp" | cut -c1-16 | tr '[:upper:]' '[:lower:]')"
    echo "importing $(basename "$c") as $alias into $kt"
    sudo "$kt" -importcert -file "$c" -alias "$alias" -cacerts -storepass changeit -noprompt
  done
done
```

- [ ] **Step 2: Lint and smoke-test only these steps**

Run: `bash test/lint.sh && bash test/docker-smoke.sh --only certificates --only apt-base --only kubectl --only helm --only nodejs --only dotnet --only jdk --only java-certs`
Expected: all eight `OK`. In the log output check: `kubectl` prints a `v1.34.x` client, `helm version` prints `v4.x`, node prints `v24.x` (current LTS), `dotnet --list-sdks` lists `10.0.x`, `java -version` prints Temurin 25, java-certs prints `importing` lines for each JDK on first run.

- [ ] **Step 3: Verify java-certs is rerun-safe**

The smoke harness starts a fresh container every time, so run the step twice inside one container by hand:

```bash
docker run --rm -t -v "$PWD:/installer:ro" -e WPAAS_NO_SUDO=1 -e WPAAS_GIT_NAME=x -e WPAAS_GIT_EMAIL=x@x -e WPAAS_INSTALL_KUBECONTEXTS=n -e WPAAS_INSTALL_JETBRAINS=n ubuntu:26.04 bash -c '
  set -e; apt-get update -qq && apt-get install -y -qq sudo >/dev/null
  useradd -m -s /bin/bash smoke; echo "smoke ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/smoke
  cp -r /installer /home/smoke/installer && chown -R smoke:smoke /home/smoke/installer
  su - smoke -c "cd ~/installer && bash install.sh --non-interactive --only certificates --only apt-base --only jdk --only java-certs"
  su - smoke -c "cd ~/installer && bash install.sh --non-interactive --only java-certs --force" | grep -c "already in"'
```
Expected: the final number is greater than 0 and no `importing` line appears in the second run.

- [ ] **Step 4: Commit**

```bash
git add steps
git commit -m "Add toolchain steps: kubectl 1.34, helm 4, node lts, newest dotnet, temurin with LTS default

Claude-Session: https://claude.ai/code/session_01Lyq6efnKY8j7J228cYywDM"
```

---

### Task 5: Remaining steps (docker, GPU, kube contexts, CLIs, systemd-deferred)

**Files:**
- Create: `steps/65-docker.sh`, `steps/80-mesa.sh`, `steps/85-nvidia-toolkit.sh`, `steps/90-kubecontexts.sh`, `steps/105-krew.sh`, `steps/110-kubectx.sh`, `steps/115-vault.sh`, `steps/120-telepresence.sh`, `steps/125-rust.sh`, `steps/130-claude.sh`, `steps/135-codex.sh`, `steps/200-nvidia-runtime.sh`, `steps/205-jetbrains.sh`, `steps/210-yq.sh`

**Interfaces:**
- Consumes: `WPAAS_INSTALL_KUBECONTEXTS`, `WPAAS_AZURE_EMAIL`, `WPAAS_INSTALL_JETBRAINS`; lib.sh helpers.

- [ ] **Step 1: Write the steps**

`steps/65-docker.sh`:

```bash
#!/bin/bash
# step: docker
# Docker CE from download.docker.com unless Docker Desktop integration is present.
. "$REPO_ROOT/lib.sh"
if [ -e /mnt/wsl/docker-desktop/cli-tools/usr/bin/docker ]; then
  echo "Docker Desktop WSL integration active, not installing docker"
  exit 0
fi
sudo rm -f /etc/systemd/system/docker.service.d/http-proxy.conf
for p in docker docker.io containerd runc; do
  package_installed "$p" && apt_get remove -y "$p"
done
fetch_keyring https://download.docker.com/linux/ubuntu/gpg /etc/apt/keyrings/docker.gpg
write_apt_list docker \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(os_codename) stable"
apt_update
apt_install docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin
sudo usermod -aG docker "$USER"
docker --version
```

`steps/80-mesa.sh`:

```bash
#!/bin/bash
# step: mesa
# VA-API via the d3d12 gallium driver that ships in base mesa (mesa-libgallium). No PPA.
. "$REPO_ROOT/lib.sh"
apt_install vainfo mesa-libgallium libgl1-mesa-dri
sudo usermod -aG video "$USER"
```

`steps/85-nvidia-toolkit.sh`:

```bash
#!/bin/bash
# step: nvidia-toolkit
. "$REPO_ROOT/lib.sh"
fetch_keyring https://nvidia.github.io/libnvidia-container/gpgkey /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
tmp=$(mktemp)
retry 3 curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list -o "$tmp"
sed -i 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' "$tmp"
install_file "$tmp" /etc/apt/sources.list.d/nvidia-container-toolkit.list
rm -f "$tmp"
apt_update
apt_install nvidia-container-toolkit
nvidia-ctk --version
```

`steps/90-kubecontexts.sh`:

```bash
#!/bin/bash
# step: kubecontexts
# needs_answers: install_kubecontexts azure_email
. "$REPO_ROOT/lib.sh"
if [ "${WPAAS_INSTALL_KUBECONTEXTS:-n}" != y ]; then
  echo "kube contexts not wanted (answer install_kubecontexts=n)"
  exit 0
fi
mkdir -p ~/.kube
chmod 700 ~/.kube
for config in kube/*; do
  target="$HOME/.kube/$(basename "$config")"
  sed "s/!email!/${WPAAS_AZURE_EMAIL}/g" "$config" > "$target"
  chmod 600 "$target"
  echo "installed $target"
done
```

`steps/105-krew.sh`:

```bash
#!/bin/bash
# step: krew
. "$REPO_ROOT/lib.sh"
if [ -x "$HOME/.krew/bin/kubectl-krew" ]; then
  echo "krew already installed"
  exit 0
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
KREW="krew-linux_amd64"
retry 3 curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz"
tar zxf "${KREW}.tar.gz"
./"$KREW" install krew
```

`steps/110-kubectx.sh`:

```bash
#!/bin/bash
# step: kubectx
. "$REPO_ROOT/lib.sh"
if [ ! -e /opt/kubectx ]; then
  sudo git clone --depth 1 https://github.com/ahmetb/kubectx /opt/kubectx
fi
sudo ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -sf /opt/kubectx/kubens /usr/local/bin/kubens
compdir=$(pkg-config --variable=completionsdir bash-completion)
sudo ln -sf /opt/kubectx/completion/kubens.bash "$compdir/kubens"
sudo ln -sf /opt/kubectx/completion/kubectx.bash "$compdir/kubectx"
```

`steps/115-vault.sh`:

```bash
#!/bin/bash
# step: vault
. "$REPO_ROOT/lib.sh"
fetch_keyring https://apt.releases.hashicorp.com/gpg /usr/share/keyrings/hashicorp-archive-keyring.gpg
write_apt_list hashicorp \
  "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(os_codename) main"
apt_update
apt_install vault
vault version
```

`steps/120-telepresence.sh`:

```bash
#!/bin/bash
# step: telepresence
. "$REPO_ROOT/lib.sh"
tmp=$(mktemp)
retry 3 curl -fsSL https://app.getambassador.io/download/tel2/linux/amd64/latest/telepresence -o "$tmp"
sudo install -m 0755 "$tmp" /usr/local/bin/telepresence
rm -f "$tmp"
telepresence version || true
```

`steps/125-rust.sh`:

```bash
#!/bin/bash
# step: rust
. "$REPO_ROOT/lib.sh"
if [ -x "$HOME/.cargo/bin/rustup" ]; then
  "$HOME/.cargo/bin/rustup" update stable
  exit 0
fi
tmp=$(mktemp)
retry 3 curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs -o "$tmp"
sh "$tmp" -y
rm -f "$tmp"
"$HOME/.cargo/bin/cargo" --version
```

`steps/130-claude.sh`:

```bash
#!/bin/bash
# step: claude
# Claude Code via the official native installer (per-user, self-updating).
. "$REPO_ROOT/lib.sh"
tmp=$(mktemp)
retry 3 curl --cacert /etc/ssl/certs/ca-certificates.crt -fsSL https://claude.ai/install.sh -o "$tmp"
bash "$tmp"
rm -f "$tmp"
"$HOME/.local/bin/claude" --version
```

`steps/135-codex.sh`:

```bash
#!/bin/bash
# step: codex
# OpenAI Codex CLI via the official installer (per-user, lands in ~/.local/bin).
. "$REPO_ROOT/lib.sh"
tmp=$(mktemp)
retry 3 curl --cacert /etc/ssl/certs/ca-certificates.crt -fsSL https://chatgpt.com/codex/install.sh -o "$tmp"
sh "$tmp"
rm -f "$tmp"
"$HOME/.local/bin/codex" --version
```

`steps/200-nvidia-runtime.sh`:

```bash
#!/bin/bash
# step: nvidia-runtime
# needs_systemd: 1
. "$REPO_ROOT/lib.sh"
if ! command -v docker >/dev/null || [ -e /mnt/wsl/docker-desktop/cli-tools/usr/bin/docker ]; then
  echo "no local docker daemon, skipping runtime configuration"
  exit 0
fi
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl daemon-reload
sudo systemctl restart docker
```

`steps/205-jetbrains.sh`:

```bash
#!/bin/bash
# step: jetbrains
# needs_systemd: 1
# needs_answers: install_jetbrains
. "$REPO_ROOT/lib.sh"
if [ "${WPAAS_INSTALL_JETBRAINS:-n}" != y ]; then
  echo "JetBrains IDEs not wanted (answer install_jetbrains=n)"
  exit 0
fi
sudo snap install rider --classic
sudo snap install intellij-idea-ultimate --classic
```

`steps/210-yq.sh`:

```bash
#!/bin/bash
# step: yq
# needs_systemd: 1
. "$REPO_ROOT/lib.sh"
sudo snap install yq
yq --version
```

- [ ] **Step 2: Lint, list, and run the full smoke test**

Run: `bash test/lint.sh && bash install.sh --list && bash test/docker-smoke.sh`
Expected: `lint OK`; `--list` prints 30 steps in numeric order with `certificates` and `apt-base` as `required=1` and `binfmt`, `nvidia-runtime`, `jetbrains`, `yq` as `needs_systemd=1`; the smoke summary shows every non-systemd step `OK` and the four systemd steps `DEFERRED (systemd)`; exit 0. The smoke run takes 10 to 20 minutes.

If a step fails in the container, read its log line in the output, fix the step, and rerun the smoke test with `--only <step>` plus any steps it depends on (`certificates`, `apt-base`).

- [ ] **Step 3: Commit**

```bash
git add steps
git commit -m "Add docker, GPU, kube context, CLI (claude, codex) and systemd-deferred steps

Claude-Session: https://claude.ai/code/session_01Lyq6efnKY8j7J228cYywDM"
```

---

### Task 6: Remove the legacy scripts and rewrite the README

**Files:**
- Delete: `install_*.sh`, `post_install.sh`, `post_install_*.sh`, `apt/` (whole directory), `systemd/` (whole directory), `.vscode-server/` (accidental output of the old vscode step)
- Modify: `README.md` (overwrite)

- [ ] **Step 1: Delete legacy files**

```bash
git rm -r install_*.sh post_install.sh post_install_*.sh apt systemd .vscode-server
```

- [ ] **Step 2: Confirm nothing references the removed files**

Run: `grep -rn --exclude-dir=.git --exclude-dir=docs -E 'install_[a-z_]+\.sh|post_install|apt/|systemd/|http_proxy_env|vpnkit|zscloud|HTTP_PROXY' .`
Expected: exactly one match outside `docs/`: the `sudo rm -f /etc/profile.d/http_proxy_env.sh` cleanup line in `steps/20-profile.sh`. If `bootstrap.ps1` still matches, that is fixed in Task 7; everything else must be clean.

- [ ] **Step 3: Rewrite README.md**

```markdown
# Ubuntu for WSL on WPAAS clients

Installs an Ubuntu 26.04 LTS (resolute) WSL distribution named `ubuntu-wpaas-resolute`
with the SwissTXT developer toolchain. Existing WSL distributions are never touched.

## What you get

- Corporate CA certificates for the system store, Java keystores, Node (`NODE_EXTRA_CA_CERTS`) and Python requests.
  No proxy settings: the Zscaler client connector handles the proxy transparently.
- Docker CE (skipped when Docker Desktop WSL integration is detected), NVIDIA container toolkit
- kubectl 1.34 (pinned) with kubelogin, krew, kubectx/kubens, optional SwissTXT kube contexts
- Helm 4
- Temurin JDK 11, 17, 21, 25 (25 is the default)
- .NET SDK (newest available, currently 10.0)
- Node.js (current LTS via `n`)
- Rust (rustup), Python 3, git + git-flow, GitHub CLI with `gh act`, jq, yq, ffmpeg, mediainfo
- HashiCorp Vault CLI, Telepresence
- Claude Code CLI and OpenAI Codex CLI
- Powerline prompt with the CaskaydiaCove Nerd Font configured in Windows Terminal
- VA-API video acceleration (d3d12), `wslview` to open URLs in the Windows browser
- Optional: Rider and IntelliJ IDEA Ultimate (snap)

## Prerequisites

- Windows 11 with WSL 2.4.4 or newer (`wsl --version`; run `wsl --update` if older)
- Windows Terminal
- A regular (non admin) user session; no elevation needed

## Fresh installation

1. Download or clone this repository on Windows.
2. Open PowerShell as your regular user and allow the script once:
   `Set-ExecutionPolicy -Scope Process Bypass`
3. Run `.\bootstrap.ps1`.
4. When the new distribution starts for the first time, create your Linux user when asked, then type `exit`.
5. Answer the installer's questions (git identity, kube contexts, JetBrains IDEs). They are asked once and remembered.
6. Wait for the summary. The script runs the installer a second time after a restart of the
   distribution to finish steps that need systemd.

`bootstrap.ps1 -Name ubuntu-wpaas-test` installs under another name for testing.

## Reruns, failures and flags

Inside the distribution the installer lives in `~/installer`. Every step runs in isolation,
logs to `~/.wpaas-installer/logs/<step>.log` and is marked done in `~/.wpaas-installer/state/`.
A rerun skips done steps and never asks the saved questions again.

```
cd ~/installer
./install.sh                    # rerun, only not-yet-done steps execute
./install.sh --list             # show steps
./install.sh --only helm --force   # rerun one step
./install.sh --skip jetbrains   # skip a step this run
./install.sh --reset            # forget state, logs and answers
```

Answers can be pre-seeded for unattended runs: `WPAAS_GIT_NAME`, `WPAAS_GIT_EMAIL`,
`WPAAS_INSTALL_KUBECONTEXTS` (y/n), `WPAAS_AZURE_EMAIL`, `WPAAS_INSTALL_JETBRAINS` (y/n),
together with `--non-interactive`.

Steps `certificates` and `apt-base` are required: if one fails the run stops. Any other
failure is reported in the summary and the run continues.

## Updating an existing resolute installation

```
cd ~/installer && git pull && ./install.sh --force
```

## Development

- `test/lint.sh` runs shellcheck over all shell files.
- `test/runner-test.sh` checks the step runner against dummy steps.
- `test/docker-smoke.sh [install.sh args]` runs the installer inside `ubuntu:26.04`
  against the real repositories (systemd steps report DEFERRED there).
- Version knobs live in `vars.sh`. Steps live in `steps/NN-<name>.sh`; the header comments
  `# required: 1`, `# needs_systemd: 1` and `# needs_answers: ...` are read by the runner.
```

- [ ] **Step 4: Lint and run the runner test again**

Run: `bash test/lint.sh && bash test/runner-test.sh`
Expected: `lint OK`, `ALL OK`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Remove legacy install scripts, proxy config and vpnkit; rewrite README

Claude-Session: https://claude.ai/code/session_01Lyq6efnKY8j7J228cYywDM"
```

---

### Task 7: bootstrap.ps1 for the .wsl image, nerd font and terminal profile

**Files:**
- Create: `bootstrap.ps1` (overwrite)
- Create: `test/bootstrap-test.ps1`

**Interfaces:**
- Parameters: `-Name` (distro name override), `-Release` (default `26.04.1`), `-Codename` (default `resolute`), `-Branch` (default `master`), `-TerminalSettingsPath` (override for tests), `-SkipInstall` (only font + terminal profile, for tests).
- Functions: `Test-DistroExists`, `Assert-WslVersion`, `Install-NerdFont`, `Set-TerminalProfileFont`, `Invoke-Installer`.

- [ ] **Step 1: Write the terminal-profile test**

Create `test/bootstrap-test.ps1` (run with Windows PowerShell 5.1 from the repo root):

```powershell
# Verifies Set-TerminalProfileFont against a temp copy of a settings.json. Run: powershell -NoProfile -File test/bootstrap-test.ps1
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\bootstrap.ps1" -SkipInstall -LoadOnly

$tmp = Join-Path $env:TEMP ("wpaas-bt-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
$settings = Join-Path $tmp "settings.json"
$fails = 0
function Assert($name, $cond) { if ($cond) { Write-Output "ok   $name" } else { Write-Output "FAIL $name"; $script:fails++ } }

# case 1: profile exists without font
@'
{ "profiles": { "defaults": {}, "list": [ { "name": "ubuntu-wpaas-resolute", "source": "Microsoft.WSL", "guid": "{1}" }, { "name": "other", "guid": "{2}" } ] } }
'@ | Set-Content $settings
Set-TerminalProfileFont -DistName "ubuntu-wpaas-resolute" -Face "CaskaydiaCove Nerd Font Mono" -SettingsPath $settings
$j = Get-Content $settings -Raw | ConvertFrom-Json
Assert "font set on existing profile" (($j.profiles.list | Where-Object name -eq "ubuntu-wpaas-resolute").font.face -eq "CaskaydiaCove Nerd Font Mono")
Assert "other profile untouched" (($j.profiles.list | Where-Object name -eq "other").PSObject.Properties.Name -notcontains "font")
Assert "backup written" ((Get-ChildItem $tmp -Filter "settings.json.bak-*").Count -eq 1)

# case 2: profile missing -> appended
@'
{ "profiles": { "list": [ { "name": "other", "guid": "{2}" } ] } }
'@ | Set-Content $settings
Set-TerminalProfileFont -DistName "ubuntu-wpaas-resolute" -Face "CaskaydiaCove Nerd Font Mono" -SettingsPath $settings
$j = Get-Content $settings -Raw | ConvertFrom-Json
$p = $j.profiles.list | Where-Object name -eq "ubuntu-wpaas-resolute"
Assert "profile appended" ($null -ne $p)
Assert "appended profile has source" ($p.source -eq "Microsoft.WSL")
Assert "appended profile has font" ($p.font.face -eq "CaskaydiaCove Nerd Font Mono")
Assert "list still has other" (@($j.profiles.list).Count -eq 2)

# case 3: existing font object keeps other keys
@'
{ "profiles": { "list": [ { "name": "ubuntu-wpaas-resolute", "font": { "size": 11, "face": "Consolas" } } ] } }
'@ | Set-Content $settings
Set-TerminalProfileFont -DistName "ubuntu-wpaas-resolute" -Face "CaskaydiaCove Nerd Font Mono" -SettingsPath $settings
$j = Get-Content $settings -Raw | ConvertFrom-Json
Assert "font size kept" ($j.profiles.list[0].font.size -eq 11)
Assert "font face replaced" ($j.profiles.list[0].font.face -eq "CaskaydiaCove Nerd Font Mono")

Remove-Item -Recurse -Force $tmp
if ($fails -eq 0) { Write-Output "ALL OK" } else { Write-Output "$fails FAILED"; exit 1 }
```

- [ ] **Step 2: Run the test to verify it fails**

Run from WSL: `/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w test/bootstrap-test.ps1)"`
Expected: error that `-SkipInstall`/`-LoadOnly` are not parameters of bootstrap.ps1, exit non-zero.

- [ ] **Step 3: Write bootstrap.ps1**

```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
  Installs the ubuntu-wpaas-<codename> WSL distribution and runs the installer inside it.
.PARAMETER Name
  Distribution name override (default ubuntu-wpaas-<Codename>), e.g. for test installs.
.PARAMETER LoadOnly
  Dot-source the functions without running anything (used by test/bootstrap-test.ps1).
#>
[CmdletBinding()]
param(
    [string]$Name = "",
    [string]$Release = "26.04.1",
    [string]$Codename = "resolute",
    [string]$Branch = "master",
    [string]$TerminalSettingsPath = "",
    [switch]$SkipInstall,
    [switch]$LoadOnly
)

$ErrorActionPreference = "Stop"
$series = $Release.Substring(0, 5)                       # 26.04
$dist = if ($Name) { $Name } else { "ubuntu-wpaas-$Codename" }
$image = "ubuntu-$Release-wsl-amd64.wsl"
$imageUrl = "https://releases.ubuntu.com/$series/$image"
$fontFace = "CaskaydiaCove Nerd Font Mono"
$fontZipUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip"
$repoTarball = "https://github.com/swisstxt/wpaas-wsl-ubuntu/archive/refs/heads/$Branch.tar.gz"
$wsl = "$env:SystemRoot\System32\wsl.exe"

function Get-WslText {
    # wsl.exe prints UTF-16; strip the NULs PowerShell 5.1 leaves behind.
    param([string[]]$WslArgs)
    (& $wsl @WslArgs | ForEach-Object { $_ -replace "`0", "" }) | Where-Object { $_ -ne $null }
}

function Test-DistroExists([string]$DistName) {
    $list = Get-WslText @("-l", "-q") | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    return $list -contains $DistName
}

function Assert-WslVersion {
    $line = Get-WslText @("--version") | Select-Object -First 1
    if (-not $line -or $line -notmatch "(\d+)\.(\d+)\.(\d+)") {
        throw "Could not read the WSL version. Run 'wsl --update' and try again."
    }
    $v = [version]("{0}.{1}.{2}" -f $Matches[1], $Matches[2], $Matches[3])
    if ($v -lt [version]"2.4.4") { throw "WSL $v is too old, 2.4.4 or newer is required. Run 'wsl --update'." }
    Write-Output "WSL version $v"
}

function Install-NerdFont {
    $fontsKey = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
    if (-not (Test-Path $fontsKey)) { New-Item -Path $fontsKey -Force | Out-Null }
    $names = (Get-ItemProperty $fontsKey).PSObject.Properties.Name
    if ($names | Where-Object { $_ -like "CaskaydiaCove Nerd Font Mono*" -or $_ -like "CaskaydiaCoveNerdFontMono-*" }) {
        Write-Output "Font already installed: $fontFace"
        return
    }
    Write-Output "Installing $fontFace for the current user"
    $zip = Join-Path $env:TEMP "CascadiaCode.zip"
    $dir = Join-Path $env:TEMP "CascadiaCodeNF"
    Start-BitsTransfer -Source $fontZipUrl -Destination $zip
    if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
    Expand-Archive -Path $zip -DestinationPath $dir
    $fontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
    Add-Type -Namespace Win32 -Name Font -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern int AddFontResource(string lpFileName);
[DllImport("user32.dll")] public static extern int SendNotifyMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
'@
    foreach ($f in Get-ChildItem $dir -Filter "CaskaydiaCoveNerdFontMono-*.ttf") {
        $dest = Join-Path $fontDir $f.Name
        Copy-Item $f.FullName $dest -Force
        # The value name is informational; Windows reads the face name from the file.
        New-ItemProperty -Path $fontsKey -Name "$($f.BaseName) (TrueType)" -Value $dest -PropertyType String -Force | Out-Null
        [Win32.Font]::AddFontResource($dest) | Out-Null
    }
    [Win32.Font]::SendNotifyMessage([IntPtr]0xffff, 0x1D, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null   # WM_FONTCHANGE
    Remove-Item -Recurse -Force $dir, $zip
}

function Set-TerminalProfileFont {
    param([string]$DistName, [string]$Face, [string]$SettingsPath = "")
    if (-not $SettingsPath) {
        $candidates = @(
            (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"),
            (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json"))
        $SettingsPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    if (-not $SettingsPath -or -not (Test-Path $SettingsPath)) {
        Write-Warning "Windows Terminal settings.json not found. Set the font of profile '$DistName' to '$Face' manually."
        return
    }
    try {
        $json = Get-Content $SettingsPath -Raw | ConvertFrom-Json
    } catch {
        Write-Warning "Could not parse $SettingsPath ($($_.Exception.Message)). Set the font of profile '$DistName' to '$Face' manually."
        return
    }
    Copy-Item $SettingsPath ("{0}.bak-{1}" -f $SettingsPath, (Get-Date -Format "yyyyMMddHHmmss"))
    $list = @($json.profiles.list)
    $profile = $list | Where-Object { $_.name -eq $DistName } | Select-Object -First 1
    if ($profile) {
        if ($profile.PSObject.Properties.Name -contains "font" -and $profile.font -is [System.Management.Automation.PSCustomObject]) {
            $profile.font | Add-Member -NotePropertyName face -NotePropertyValue $Face -Force
        } else {
            $profile | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{ face = $Face }) -Force
        }
    } else {
        $list += [pscustomobject]@{ name = $DistName; source = "Microsoft.WSL"; font = [pscustomobject]@{ face = $Face } }
    }
    $json.profiles | Add-Member -NotePropertyName list -NotePropertyValue $list -Force
    $json | ConvertTo-Json -Depth 64 | Set-Content $SettingsPath -Encoding UTF8
    Write-Output "Windows Terminal profile '$DistName' uses font '$Face'"
}

function Invoke-Installer([string]$DistName, [string]$User) {
    & $wsl -d $DistName -u $User --cd "~" -- bash -c "curl --insecure -fsSL '$repoTarball' -o install.tar.gz && rm -rf installer && mkdir installer && tar xzf install.tar.gz -C installer --strip-components=1"
    if ($LASTEXITCODE -ne 0) { throw "Downloading the installer into $DistName failed ($LASTEXITCODE)" }
    & $wsl -d $DistName -u $User --cd "~/installer" -- bash install.sh
    $first = $LASTEXITCODE
    Write-Output "Restarting $DistName so systemd and wsl.conf take effect"
    & $wsl --terminate $DistName
    & $wsl -d $DistName -u $User --cd "~/installer" -- bash install.sh
    $second = $LASTEXITCODE
    if ($first -ne 0 -or $second -ne 0) {
        Write-Warning "Some installer steps failed. Logs: \\wsl.localhost\$DistName\home\$User\.wpaas-installer\logs. Rerun with: wsl -d $DistName -u $User --cd ~/installer -- bash install.sh"
    }
}

if ($LoadOnly) { return }

try {
    if (-not $SkipInstall) {
        Assert-WslVersion
        if (Test-DistroExists $dist) { throw "A WSL distribution named '$dist' already exists. Use -Name to pick another name or unregister it first." }
        if (-not (Test-Path $image)) {
            Write-Output "Downloading $imageUrl ... please be patient"
            Start-BitsTransfer -Source $imageUrl -Destination $image
        }
        & $wsl --install --from-file $image --name $dist --no-launch
        if ($LASTEXITCODE -ne 0) { throw "wsl --install failed ($LASTEXITCODE)" }
        Write-Output ""
        Write-Output "Starting $dist for the first time. Create your Linux user when asked, then type 'exit'."
        & $wsl -d $dist
        $user = (Get-WslText @("-d", $dist, "--", "id", "-un", "1000") | Select-Object -First 1)
        if (-not $user) { throw "No user with uid 1000 exists in $dist. Launch 'wsl -d $dist', finish the user setup, then rerun with the same -Name." }
        $user = $user.Trim()
        Write-Output "Linux user: $user"
    }
    Install-NerdFont
    Set-TerminalProfileFont -DistName $dist -Face $fontFace -SettingsPath $TerminalSettingsPath
    if (-not $SkipInstall) {
        Invoke-Installer -DistName $dist -User $user
        Write-Output "Done. Open '$dist' from Windows Terminal."
    }
} catch {
    Write-Output $_.ScriptStackTrace
    Write-Output "failed to set up WSL: $($_.Exception.Message)"
    exit 1
}
```

- [ ] **Step 4: Run the terminal-profile test and a syntax check**

Run from WSL:

```bash
PS=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
"$PS" -NoProfile -ExecutionPolicy Bypass -File "$(wslpath -w test/bootstrap-test.ps1)"
"$PS" -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile('$(wslpath -w bootstrap.ps1)', [ref]\$null, [ref]\$e) | Out-Null; \$e.Count"
```
Expected: `ALL OK` from the test; `0` parse errors.

- [ ] **Step 5: Exercise the font and profile functions for real with -SkipInstall**

Run from Windows PowerShell in the repo directory: `.\bootstrap.ps1 -SkipInstall -Name ubuntu-wpaas-test`
Expected: `Font already installed: CaskaydiaCove Nerd Font Mono` (on this machine) and `Windows Terminal profile 'ubuntu-wpaas-test' uses font ...`. Open Windows Terminal settings and confirm a `ubuntu-wpaas-test` profile appeared with the font; then remove that profile entry again (or restore from the `.bak-*` file).

- [ ] **Step 6: Commit**

```bash
git add bootstrap.ps1 test/bootstrap-test.ps1
git commit -m "Rewrite bootstrap for the 26.04 .wsl image, nerd font and terminal profile

Claude-Session: https://claude.ai/code/session_01Lyq6efnKY8j7J228cYywDM"
```

---

### Task 8: Acceptance run on a real WSL (manual, with the user)

This task is executed by the user on their machine; the implementer prepares the checklist and records the outcome in the plan.

- [ ] **Step 1: Push the branch so bootstrap can fetch it**

`bootstrap.ps1 -Branch <branch>` downloads the installer from GitHub, so the work must be pushed. Push the feature branch and use its name.

- [ ] **Step 2: Run bootstrap against a throwaway name**

From Windows PowerShell as the regular user, in the repo directory:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\bootstrap.ps1 -Name ubuntu-wpaas-test -Branch <branch>
```

Expected: image download, `wsl --install`, first-run user creation, four questions, two installer passes, a summary with every step `OK` (jetbrains shows `OK` with "not wanted" if answered n).

- [ ] **Step 3: Verify inside the new distro**

```bash
wsl -d ubuntu-wpaas-test
claude --version && codex --version
kubectl version --client && helm version && java -version && dotnet --list-sdks && node --version
vainfo | head -5
wslview https://example.com     # opens the Windows browser
cd ~/installer && ./install.sh   # second manual rerun: every step SKIPPED (done), no prompts
```

Also open the `ubuntu-wpaas-test` profile in Windows Terminal and confirm the powerline prompt renders without missing glyphs.

- [ ] **Step 4: Clean up and record**

`wsl --unregister ubuntu-wpaas-test`, remove the `ubuntu-wpaas-test` profile from Windows Terminal (or restore the `.bak-*`), and note any failing step and its fix in the commit that fixes it.
