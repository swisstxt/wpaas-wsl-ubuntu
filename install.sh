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
