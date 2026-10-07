#!/bin/bash
# step: jetbrains
# needs_systemd: 1
# needs_answers: install_jetbrains
. "$REPO_ROOT/lib.sh"
if [ "${WPAAS_INSTALL_JETBRAINS:-n}" != y ]; then
  echo "JetBrains IDEs not wanted (answer install_jetbrains=n)"
  exit 0
fi
sudo snap install rider --classic
sudo snap install intellij-idea-ultimate --classic
