#!/bin/bash
# step: docker
# Docker CE from download.docker.com unless Docker Desktop integration is present.
. "$REPO_ROOT/lib.sh"
if [ -e /mnt/wsl/docker-desktop/cli-tools/usr/bin/docker ]; then
  echo "Docker Desktop WSL integration active, not installing docker"
  exit 0
fi
sudo rm -f /etc/systemd/system/docker.service.d/http-proxy.conf
for p in docker docker.io containerd runc; do
  package_installed "$p" && apt_get remove -y "$p"
done
fetch_keyring https://download.docker.com/linux/ubuntu/gpg /etc/apt/keyrings/docker.gpg
write_apt_list docker \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(os_codename) stable"
apt_update
apt_install docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin
sudo usermod -aG docker "$USER"
docker --version
