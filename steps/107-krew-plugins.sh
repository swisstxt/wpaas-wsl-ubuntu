#!/bin/bash
# step: krew-plugins
# kubectl plugins installed through krew. Completion for them lives in bin/.
. "$REPO_ROOT/lib.sh"
plugins=(ns)
krew="$HOME/.krew/bin/kubectl-krew"
[ -x "$krew" ] || { echo "krew is not installed; run the krew step first" >&2; exit 1; }
installed=$("$krew" list 2>/dev/null)
for p in "${plugins[@]}"; do
  if grep -qxF "$p" <<<"$installed"; then
    echo "krew plugin $p already installed"
  else
    retry 3 "$krew" install "$p"
  fi
done
