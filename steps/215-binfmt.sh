#!/bin/bash
# step: binfmt
# needs_systemd: 1
# Lets systemd-binfmt keep running Windows executables from WSL.
. "$REPO_ROOT/lib.sh"
tmp=$(mktemp)
echo ':WSLInterop:M::MZ::/init:PF' > "$tmp"
install_file "$tmp" /usr/lib/binfmt.d/WSLInterop.conf
rm -f "$tmp"
sudo systemctl daemon-reload
sudo systemctl restart systemd-binfmt || echo "systemd-binfmt reported a failure; this is expected on WSL, verifying interop directly"
# The unit often ends up failed on WSL; what matters is the registered entry.
entry=/proc/sys/fs/binfmt_misc/WSLInterop
if [ ! -e "$entry" ]; then
  echo "WSLInterop binfmt entry is missing; Windows interop is broken" >&2
  exit 1
fi
if [ "$(head -n1 "$entry")" != enabled ]; then
  echo "WSLInterop binfmt entry is not enabled; Windows interop is broken" >&2
  exit 1
fi
if [ -e /mnt/c/Windows/System32/cmd.exe ]; then
  (cd /mnt/c && /mnt/c/Windows/System32/cmd.exe /c "echo interop ok" >/dev/null) || {
    echo "Windows interop check failed: cmd.exe did not run" >&2
    exit 1
  }
fi
