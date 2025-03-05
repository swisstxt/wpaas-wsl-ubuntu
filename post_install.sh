#!/bin/bash
# exit on error
set -ex

# import global variables
. ./vars.sh

# import bash function library
. ./lib.sh

# load http proxy env vars
. profile.d/http_proxy_env.sh

# post installation for nvidia container runtime
. ./post_install_nvidia_container_toolkit.sh

# install rider (needs to be in post as snap service needs to be running)
. ./post_install_rider.sh

# install intellij ultimate (needs to be in post as snap service needs to be running)
. ./post_install_intellij.sh

# yq yaml processor
. ./post_install_yq.sh

# binfmt config
. ./post_install_binfmt.sh