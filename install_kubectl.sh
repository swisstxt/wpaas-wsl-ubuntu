#!/bin/bash

# copy pinning file
KUBECTL_PIN_SOURCE=apt/preferences.d/kubectl
KUBECTL_PIN_TARGET=/etc/apt/preferences.d/kubectl

if does_not_exists_or_is_different $KUBECTL_PIN_TARGET $KUBECTL_PIN_SOURCE; then
    echo "$KUBECTL_PIN_TARGET does not appear to be installed - installing"
    sudo cp $KUBECTL_PIN_SOURCE $KUBECTL_PIN_TARGET
else
    echo "$KUBECTL_PIN_TARGET is installed and up to date"
fi

sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg unzip

# If the folder `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.24/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.24/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to work correctly

sudo apt-get update
sudo apt-get install -y kubectl

curl -LO https://github.com/Azure/kubelogin/releases/latest/download/kubelogin-linux-amd64.zip
unzip kubelogin-linux-amd64.zip
sudo mv bin/linux_amd64/kubelogin /usr/local/bin/
rm kubelogin-linux-amd64.zip
rm -r bin/linux_amd64
