#!/bin/bash
# Runs install.sh non-interactively inside ubuntu:26.04 against the real repositories.
# Steps needing systemd report DEFERRED there. Extra arguments are passed to install.sh,
# e.g.: test/docker-smoke.sh --only certificates --only apt-base
set -u
cd "$(dirname "$0")/.." || exit 1
docker run --rm -t --cap-add IPC_LOCK \
  -v "$PWD:/installer:ro" \
  -e WPAAS_NO_SUDO=1 \
  -e WPAAS_GIT_NAME="Smoke Test" \
  -e WPAAS_GIT_EMAIL="smoke@example.com" \
  -e WPAAS_INSTALL_KUBECONTEXTS=y \
  -e WPAAS_AZURE_EMAIL="smoke@swisstxt.ch" \
  -e WPAAS_INSTALL_JETBRAINS=n \
  -e INSTALL_ARGS="$*" \
  ubuntu:26.04 bash -c '
    set -e
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq && apt-get install -y -qq sudo >/dev/null
    useradd -m -s /bin/bash smoke
    echo "smoke ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/smoke
    cp -r /installer /home/smoke/installer && rm -rf /home/smoke/installer/.git && chown -R smoke:smoke /home/smoke/installer
    exec su -w WPAAS_NO_SUDO,WPAAS_GIT_NAME,WPAAS_GIT_EMAIL,WPAAS_INSTALL_KUBECONTEXTS,WPAAS_AZURE_EMAIL,WPAAS_INSTALL_JETBRAINS - smoke -c "cd ~/installer && bash install.sh --non-interactive $INSTALL_ARGS"
  '
