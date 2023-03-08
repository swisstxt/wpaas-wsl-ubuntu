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

sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubectl