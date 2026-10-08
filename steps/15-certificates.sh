#!/bin/bash
# step: certificates
# required: 1
# Installs the corporate CA certificates into the system store and builds the Node bundle.
. "$REPO_ROOT/lib.sh"
package_installed ca-certificates || { apt_update; apt_install ca-certificates; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# update-ca-certificates appends every *.crt to the bundle file but creates the hash links
# (CApath lookup) only for files holding exactly one certificate. Bundles are therefore
# split into <bundle>-<nnn>.crt files first; everything outside BEGIN/END is dropped.
for cert in certificates/*.crt certificates/*.pem; do
  [ -e "$cert" ] || continue
  base=$(basename "$cert")
  base=${base%.*}
  if [ "$(grep -c 'BEGIN CERTIFICATE' "$cert")" -le 1 ]; then
    cp "$cert" "$tmp/$base.crt"
  else
    awk -v out="$tmp/$base" '
      /-----BEGIN CERTIFICATE-----/ { n++; p = 1; f = sprintf("%s-%03d.crt", out, n) }
      p { print > f }
      /-----END CERTIFICATE-----/ { p = 0 }' "$cert"
  fi
done
for c in "$tmp"/*.crt; do
  install_file "$c" "/usr/local/share/ca-certificates/$(basename "$c")"
done
sudo update-ca-certificates

# All local CA certs as one PEM bundle for NODE_EXTRA_CA_CERTS (profile.d/node_certs.sh).
bundle="$tmp/nodecerts.pem"
for c in /usr/local/share/ca-certificates/*.crt; do [ -e "$c" ] || continue; cat "$c"; echo; done > "$bundle"
install_file "$bundle" /etc/nodecerts.pem
