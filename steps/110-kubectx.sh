#!/bin/bash
# step: kubectx
. "$REPO_ROOT/lib.sh"
if [ ! -e /opt/kubectx/kubectx ]; then
  sudo rm -rf /opt/kubectx
  retry 3 sudo git clone --depth 1 https://github.com/ahmetb/kubectx /opt/kubectx
fi
sudo ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -sf /opt/kubectx/kubens /usr/local/bin/kubens
compdir=$(pkg-config --variable=completionsdir bash-completion)
sudo ln -sf /opt/kubectx/completion/kubens.bash "$compdir/kubens"
sudo ln -sf /opt/kubectx/completion/kubectx.bash "$compdir/kubectx"
