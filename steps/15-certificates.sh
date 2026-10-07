#!/bin/bash
# step: certificates
# required: 1
# Installs the corporate CA certificates into the system store and builds the Node bundle.
. "$REPO_ROOT/lib.sh"
package_installed ca-certificates || { apt_update; apt_install ca-certificates; }

# update-ca-certificates only picks up *.crt, so bundles in *.pem are installed under a .crt name.
for cert in certificates/*.crt certificates/*.pem; do
  [ -e "$cert" ] || continue
  name=$(basename "$cert")
  name="${name%.pem}.crt"
  install_file "$cert" "/usr/local/share/ca-certificates/$name"
done
sudo update-ca-certificates

# All local CA certs as one PEM bundle for NODE_EXTRA_CA_CERTS (profile.d/node_certs.sh).
tmp=$(mktemp)
for c in /usr/local/share/ca-certificates/*.crt; do [ -e "$c" ] || continue; cat "$c"; echo; done > "$tmp"
install_file "$tmp" /etc/nodecerts.pem
rm -f "$tmp"
