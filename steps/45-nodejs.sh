#!/bin/bash
# step: nodejs
# Installs `n` (a standalone bash script) straight from GitHub, then the wanted Node release into /usr/local.
# No distro nodejs/npm: on 26.04 that pulls webpack and hundreds of packages we never use.
. "$REPO_ROOT/lib.sh"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
retry 3 curl -fsSL https://raw.githubusercontent.com/tj/n/master/bin/n -o "$tmp"
sudo install -m 0755 "$tmp" /usr/local/bin/n
sudo n "$NODE_VERSION"
# TLS goes through NODE_EXTRA_CA_CERTS (profile.d/node_certs.sh); no proxy, strict ssl stays on.
/usr/local/bin/npm config delete proxy
/usr/local/bin/npm config delete https-proxy
/usr/local/bin/npm config set strict-ssl true
/usr/local/bin/node --version
/usr/local/bin/npm --version
