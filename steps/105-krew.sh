#!/bin/bash
# step: krew
. "$REPO_ROOT/lib.sh"
if [ -x "$HOME/.krew/bin/kubectl-krew" ]; then
  echo "krew already installed"
  exit 0
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp" || exit 1
KREW="krew-linux_amd64"
retry 3 curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz"
tar zxf "${KREW}.tar.gz"
./"$KREW" install krew
