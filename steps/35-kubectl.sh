#!/bin/bash
# step: kubectl
# kubectl from pkgs.k8s.io pinned to KUBECTL_MINOR, plus kubelogin for Azure AD.
. "$REPO_ROOT/lib.sh"
fetch_keyring "https://pkgs.k8s.io/core:/stable:/v${KUBECTL_MINOR}/deb/Release.key" \
  /etc/apt/keyrings/kubernetes-apt-keyring.gpg
write_apt_list kubernetes \
  "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBECTL_MINOR}/deb/ /"
write_apt_pin kubectl kubectl "${KUBECTL_MINOR}.*"
apt_update
apt_install kubectl

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
retry 3 curl -fsSL https://github.com/Azure/kubelogin/releases/latest/download/kubelogin-linux-amd64.zip -o "$tmp/kubelogin.zip"
unzip -q -o "$tmp/kubelogin.zip" -d "$tmp"
sudo install -m 0755 "$tmp/bin/linux_amd64/kubelogin" /usr/local/bin/kubelogin

kubectl version --client
kubelogin --version
