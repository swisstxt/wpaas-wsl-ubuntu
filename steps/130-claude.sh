#!/bin/bash
# step: claude
# Claude Code via the official native installer (per-user, self-updating).
. "$REPO_ROOT/lib.sh"
tmp=$(mktemp)
retry 3 curl --cacert /etc/ssl/certs/ca-certificates.crt -fsSL https://claude.ai/install.sh -o "$tmp"
bash "$tmp"
rm -f "$tmp"
"$HOME/.local/bin/claude" --version
