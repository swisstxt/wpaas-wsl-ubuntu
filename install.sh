#!/bin/bash

# exit on error
set -ex

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

# install docker (only if not using docker desktop integration)
. ./install_docker.sh

# install wsl configuration
. ./install_wslconf.sh

# install dotnet 6&7
. ./install_dotnet.sh

# install jdk 11 & 17, set 11 as default
. ./install_jdk.sh

# install essentials
. ./install_essentials.sh
