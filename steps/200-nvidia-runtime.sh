#!/bin/bash
# step: nvidia-runtime
# needs_systemd: 1
. "$REPO_ROOT/lib.sh"
if [ -e /mnt/wsl/docker-desktop/cli-tools/usr/bin/docker ]; then
  echo "Docker Desktop WSL integration active, nothing to configure"
  exit 0
fi
if ! command -v docker >/dev/null; then
  echo "docker is not installed (did the docker step fail?), cannot configure the NVIDIA runtime" >&2
  exit 1
fi
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl daemon-reload
sudo systemctl restart docker
