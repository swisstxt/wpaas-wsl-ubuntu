#!/bin/bash
# step: telepresence
. "$REPO_ROOT/lib.sh"
tmp=$(mktemp)
retry 3 curl -fsSL https://app.getambassador.io/download/tel2/linux/amd64/latest/telepresence -o "$tmp"
sudo install -m 0755 "$tmp" /usr/local/bin/telepresence
rm -f "$tmp"
telepresence version || true
