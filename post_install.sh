#!/bin/bash
# exit on error
set -ex

# import bash function library
. ./lib.sh

# load http proxy env vars
. profile.d/http_proxy_env.sh

# post installation for nvidia container runtime
. ./post_install_nvidia_container_toolkit.sh