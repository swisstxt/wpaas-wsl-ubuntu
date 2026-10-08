#!/bin/bash
# step: codex
# OpenAI Codex CLI via the official installer (per-user, lands in ~/.local/bin).
. "$REPO_ROOT/lib.sh"
tmp=$(mktemp)
retry 3 curl --cacert /etc/ssl/certs/ca-certificates.crt -fsSL https://chatgpt.com/codex/install.sh -o "$tmp"
sh "$tmp" </dev/null
rm -f "$tmp"
"$HOME/.local/bin/codex" --version
