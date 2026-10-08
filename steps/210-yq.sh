#!/bin/bash
# step: yq
# needs_systemd: 1
. "$REPO_ROOT/lib.sh"
sudo snap install yq
/snap/bin/yq --version
