#!/bin/bash
# step: rust
. "$REPO_ROOT/lib.sh"
if [ -x "$HOME/.cargo/bin/rustup" ]; then
  "$HOME/.cargo/bin/rustup" update stable
  exit 0
fi
tmp=$(mktemp)
retry 3 curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs -o "$tmp"
# rustup-init's stdout carries cc-rs build-script directives (cargo:rerun-if-env-changed ...)
# from its linker probe; its progress ("info:") goes to stderr and stays visible.
sh "$tmp" -y >/dev/null
rm -f "$tmp"
echo
"$HOME/.cargo/bin/rustc" --version
"$HOME/.cargo/bin/cargo" --version
