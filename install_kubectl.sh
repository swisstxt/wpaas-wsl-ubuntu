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

curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubectl unzip


curl -LO https://github.com/Azure/kubelogin/releases/latest/download/kubelogin-linux-amd64.zip
unzip kubelogin-linux-amd64.zip
sudo mv bin/linux_amd64/kubelogin /usr/local/bin/
rm kubelogin-linux-amd64.zip
rm -r bin/linux_amd64
