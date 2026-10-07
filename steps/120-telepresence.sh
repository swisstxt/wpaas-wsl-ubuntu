#!/bin/bash
# step: telepresence
. "$REPO_ROOT/lib.sh"
tmp=$(mktemp)
retry 3 curl -fsSL https://app.getambassador.io/download/tel2/linux/amd64/latest/telepresence -o "$tmp"
sudo install -m 0755 "$tmp" /usr/local/bin/telepresence
rm -f "$tmp"
# The daemon is not running at install time; only the client version is checked.
/usr/local/bin/telepresence version 2>&1 | grep -E '^Client' || { echo "telepresence client did not report a version" >&2; exit 1; }
