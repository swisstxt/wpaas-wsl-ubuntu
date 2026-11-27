#!/bin/bash
# step: ssh-agent
# wsl2-ssh-agent bridges the Windows OpenSSH agent (service "OpenSSH Authentication Agent",
# named pipe openssh-ssh-agent) into WSL, so ssh/git use the keys loaded on the host.
# Pinned to WSL2_SSH_AGENT_VERSION and checked against the release checksum file.
# The shell hook that starts it lives in profile.d/ssh_agent.sh.
. "$REPO_ROOT/lib.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
base="https://github.com/mame/wsl2-ssh-agent/releases/download/${WSL2_SSH_AGENT_VERSION}"
retry 3 curl -fsSL "$base/wsl2-ssh-agent" -o "$tmp/wsl2-ssh-agent"
retry 3 curl -fsSL "$base/checksums.txt" -o "$tmp/checksums.txt"
(cd "$tmp" && grep ' wsl2-ssh-agent$' checksums.txt | sha256sum -c - >/dev/null) \
  || { echo "wsl2-ssh-agent: checksum mismatch for $base/wsl2-ssh-agent" >&2; exit 1; }
sudo install -m 0755 "$tmp/wsl2-ssh-agent" /usr/local/bin/wsl2-ssh-agent
# The binary refuses to start without powershell.exe, so the self-check only runs under WSL.
if [ -e /proc/sys/fs/binfmt_misc/WSLInterop ]; then
  /usr/local/bin/wsl2-ssh-agent -version
else
  echo "wsl2-ssh-agent ${WSL2_SSH_AGENT_VERSION} installed (not inside WSL, version check skipped)"
fi
