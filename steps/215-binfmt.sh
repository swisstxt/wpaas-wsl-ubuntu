#!/bin/bash
# step: binfmt
# needs_systemd: 1
# Lets systemd-binfmt keep running Windows executables from WSL.
. "$REPO_ROOT/lib.sh"
tmp=$(mktemp)
echo ':WSLInterop:M::MZ::/init:PF' > "$tmp"
install_file "$tmp" /usr/lib/binfmt.d/WSLInterop.conf
rm -f "$tmp"
sudo systemctl restart systemd-binfmt
