#!/bin/bash
# step: nvidia-runtime
# needs_systemd: 1
. "$REPO_ROOT/lib.sh"
if ! command -v docker >/dev/null || [ -e /mnt/wsl/docker-desktop/cli-tools/usr/bin/docker ]; then
  echo "no local docker daemon, skipping runtime configuration"
  exit 0
fi
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl daemon-reload
sudo systemctl restart docker
