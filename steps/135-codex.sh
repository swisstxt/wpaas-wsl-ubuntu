#!/bin/bash
# step: codex
# OpenAI Codex CLI via the official installer (per-user, lands in ~/.local/bin).
. "$REPO_ROOT/lib.sh"
tmp=$(mktemp)
retry 3 curl --cacert /etc/ssl/certs/ca-certificates.crt -fsSL https://chatgpt.com/codex/install.sh -o "$tmp"
# The installer ends with "Start Codex now?" read straight from /dev/tty, so redirecting
# stdin does not stop it; CODEX_NON_INTERACTIVE answers no to every prompt.
CODEX_NON_INTERACTIVE=1 sh "$tmp" </dev/null
rm -f "$tmp"
"$HOME/.local/bin/codex" --version
