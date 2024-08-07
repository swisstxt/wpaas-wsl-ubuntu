#!/bin/bash

# exit on error
set -ex

# import bash function library
. ./lib.sh

# load http proxy env vars
# . profile.d/http_proxy_env.sh

# install zscaler and srg root certs
. ./install_certificates.sh

# copy profile extension scripts
. ./install_profile.sh

# make apt work with bad proxies (aka. zscaler)
# . ./install_badproxy.sh

# use proxy for apt
. ./install_apt_zscaler.sh

# install kubectl
. ./install_kubectl.sh

# install nodejs, npm, n and upgrade to LTS version
. ./install_nodejs.sh

# install helper scripts
. ./install_bin.sh

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

# install github cli
. ./install_githubcli.sh

# install powerline
. ./install_powerline.sh

# install latest mesa driver stack (vaapi support)
. ./install_mesa.sh

# install nvidia container toolkit
. ./install_nvidia_container_toolkit.sh

# install pem file for node/npm
. ./install_node_certs.sh

# install some kubernetes contexts
. ./install_kubecontexts.sh

# install wslu for better browser integration
. ./install_wslu.sh

# install whisper
. ./install_whisper.sh

# install ffmpeg
. ./install_ffmpeg.sh

# install mediainfo
. ./install_mediainfo.sh

# install jq
. ./install_jq.sh

# install hushlogin (disables daily login banner)
. ./install_hushlogin.sh

# install install a settings.json file for vscode
. ./install_vscode_settings.sh

# install krew for kubectl (plugin manager)
. ./install_krew.sh

# install kubens and kubectx
. ./install_kubens_kubectx.sh

# install python 3
. ./install_python3.sh

# install and configure vault
. ./install_vault.sh

# install telepresence
. ./install_telepresence.sh

# install rustup/cargo
. ./install_rust.sh

# install github action runner
. ./install_gh_act.sh

## post install (only launch if systemd is running)

if [ "$(ps --no-headers -o comm 1)" = "systemd" ]; then
. ./post_install.sh
fi