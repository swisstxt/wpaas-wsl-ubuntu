#!/bin/bash

# exit on error + echo commands
set -ex

# ----- proxy choice -----------------------------------------------------------
# Usage:
#   ./install.sh                # prompt interactively
#   ./install.sh --proxy        # non-interactive, enable proxy
#   ./install.sh --no-proxy     # non-interactive, disable proxy
#   APPLY_PROXY=1 ./install.sh  # non-interactive env override (1=yes, 0=no)

PROXY_MODE="prompt"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --proxy)    PROXY_MODE="on";  shift;;
    --no-proxy) PROXY_MODE="off"; shift;;
    *) echo "Usage: $0 [--proxy|--no-proxy]"; exit 1;;
  esac
done

if [[ "$PROXY_MODE" == "on" ]]; then
  PROXY_ENABLED=1
elif [[ "$PROXY_MODE" == "off" ]]; then
  PROXY_ENABLED=0
else
  # Prompt only if interactive; otherwise honor APPLY_PROXY env (default 0)
  if [[ -t 0 ]]; then
    read -r -p "Apply corporate proxy/Zscaler settings (apt proxy + CA certs for system/Java/Node)? [y/N] " ans
    case "$ans" in
      [Yy]*) PROXY_ENABLED=1;;
      *)     PROXY_ENABLED=0;;
    esac
  else
    PROXY_ENABLED=${APPLY_PROXY:-0}
  fi
fi

echo "Proxy features: $([[ "$PROXY_ENABLED" -eq 1 ]] && echo ENABLED || echo DISABLED)"

# Helper: source a script only if proxy is enabled (silently skip if missing)
source_if_proxy() {
  local f="$1"
  if [[ "$PROXY_ENABLED" -eq 1 ]]; then
    if [[ -f "$f" ]]; then
      . "$f"
    else
      echo "WARN: proxy script not found: $f"
    fi
  else
    echo "Skipping (proxy disabled): $f"
  fi
}

# Helper: source if present (keeps set -e behavior if the script exists and fails)
source_if_present() {
  local f="$1"
  if [[ -f "$f" ]]; then
    . "$f"
  else
    echo "WARN: script not found: $f"
  fi
}

# Optionally ensure we run from the script dir
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ----- your original flow -----------------------------------------------------

# import global variables
source_if_present "./vars.sh"

# import bash function library
source_if_present "./lib.sh"

# install config files in home directory
source_if_present "./install_home.sh"

# load http proxy env vars (only with proxy)
source_if_proxy "./profile.d/http_proxy_env.sh"

# install zscaler and srg root certs (only with proxy)
source_if_present "./install_certificates.sh"

# copy profile extension scripts
source_if_present "./install_profile.sh"

# make apt work with bad proxies (aka. zscaler) (only with proxy)
source_if_proxy "./install_badproxy.sh"

# use proxy for apt (only with proxy)
source_if_proxy "./install_apt_zscaler.sh"

# install kubectl
source_if_present "./install_kubectl.sh"

# install nodejs, npm, n and upgrade to LTS version
source_if_present "./install_nodejs.sh"

# install helper scripts
source_if_present "./install_bin.sh"

# install helm
#source_if_present "./install_helm.sh"

# install docker (only if not using docker desktop integration)
source_if_present "./install_docker.sh"

# install wsl configuration
source_if_present "./install_wslconf.sh"

# install dotnet 6&7
source_if_present "./install_dotnet.sh"

# install jdk 11 & 17, set 11 as default
source_if_present "./install_jdk.sh"

# install SRG/ZScaler CA certs to java keystore (only with proxy)
source_if_present "./install_java_certs.sh"

# install essentials
source_if_present "./install_essentials.sh"

# install github cli
source_if_present "./install_githubcli.sh"

# install powerline
source_if_present "./install_powerline.sh"

# install latest mesa driver stack (vaapi support)
source_if_present "./install_mesa.sh"

# install nvidia container toolkit
source_if_present "./install_nvidia_container_toolkit.sh"

# install pem file for node/npm (only with proxy)
source_if_proxy "./install_node_certs.sh"

# install some kubernetes contexts
source_if_present "./install_kubecontexts.sh"

# install wslu for better browser integration
source_if_present "./install_wslu.sh"

# install whisper
# source_if_present "./install_whisper.sh"

# install ffmpeg
source_if_present "./install_ffmpeg.sh"

# install mediainfo
source_if_present "./install_mediainfo.sh"

# install jq
source_if_present "./install_jq.sh"

# install hushlogin (disables daily login banner)
source_if_present "./install_hushlogin.sh"

# install install a settings.json file for vscode
source_if_present "./install_vscode_settings.sh"

# install krew for kubectl (plugin manager)
source_if_present "./install_krew.sh"

# install kubens and kubectx
source_if_present "./install_kubens_kubectx.sh"

# install python 3
source_if_present "./install_python3.sh"

# install and configure vault
source_if_present "./install_vault.sh"

# install telepresence
source_if_present "./install_telepresence.sh"

# install rustup/cargo
source_if_present "./install_rust.sh"

# install github action runner
source_if_present "./install_gh_act.sh"

## post install (only launch if systemd is running)
if [ "$(ps --no-headers -o comm 1)" = "systemd" ]; then
  source_if_present "./post_install.sh"
fi
