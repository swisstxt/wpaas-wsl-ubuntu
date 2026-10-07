#!/bin/bash
# step: nvidia-toolkit
. "$REPO_ROOT/lib.sh"
fetch_keyring https://nvidia.github.io/libnvidia-container/gpgkey /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
tmp=$(mktemp)
retry 3 curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list -o "$tmp"
sed -i 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' "$tmp"
install_file "$tmp" /etc/apt/sources.list.d/nvidia-container-toolkit.list
rm -f "$tmp"
apt_update
apt_install nvidia-container-toolkit
nvidia-ctk --version
