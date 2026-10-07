#!/bin/bash
# step: apt-base
# required: 1
# Base tooling every later step relies on.
. "$REPO_ROOT/lib.sh"
apt_update
apt_install ca-certificates curl wget gnupg unzip apt-transport-https \
  software-properties-common lsb-release snapd pkg-config bash-completion
sudo mkdir -p -m 755 /etc/apt/keyrings
