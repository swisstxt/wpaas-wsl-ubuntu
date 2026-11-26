#!/bin/bash
# Use the keys held by the Windows OpenSSH agent: wsl2-ssh-agent relays the host's
# openssh-ssh-agent named pipe to a socket in ~/.ssh and prints the SSH_AUTH_SOCK export.
# It is a no-op when the bridge is already running. Skipped outside WSL (no interop).
if [ -e /proc/sys/fs/binfmt_misc/WSLInterop ] && command -v wsl2-ssh-agent >/dev/null 2>&1; then
  eval "$(wsl2-ssh-agent)"
fi
