#!/bin/bash
# step: nodejs
# Distro node/npm bootstrap `n`, which then installs the wanted release into /usr/local.
. "$REPO_ROOT/lib.sh"
apt_install --no-install-recommends nodejs npm
sudo npm install -g n
sudo n "$NODE_VERSION"
# TLS goes through NODE_EXTRA_CA_CERTS (profile.d/node_certs.sh); no proxy, strict ssl stays on.
npm config delete proxy
npm config delete https-proxy
npm config set strict-ssl true
hash -r
/usr/local/bin/node --version
