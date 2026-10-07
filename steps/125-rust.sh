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
