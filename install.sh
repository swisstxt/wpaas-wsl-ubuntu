#!/bin/bash

# exit on error
set -e

# import bash function library
. ./lib.sh

# load http proxy env vars
. profile.d/http_proxy_env.sh

# install zscaler and srg root certs
. ./install_certificates.sh

# copy profile extension scripts
. ./install_profile.sh

# install kubectl
. ./install_kubectl.sh

# install nodejs, npm, n and upgrade to LTS version
. ./install_nodejs.sh

# install helm
. ./install_helm.sh
