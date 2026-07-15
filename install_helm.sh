#!/bin/bash


# copy pinning file
HELM_PIN_SOURCE=apt/preferences.d/helm
HELM_PIN_TARGET=/etc/apt/preferences.d/helm

if does_not_exists_or_is_different $HELM_PIN_TARGET $HELM_PIN_SOURCE; then
    echo "$HELM_PIN_TARGET does not appear to be installed - installing"
    sudo cp $HELM_PIN_SOURCE $HELM_PIN_TARGET
else
    echo "$HELM_PIN_TARGET is installed and up to date"
fi

curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install -y  --allow-downgrades helm
