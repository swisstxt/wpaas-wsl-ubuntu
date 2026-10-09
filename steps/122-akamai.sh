#!/bin/bash
# step: akamai
# Akamai CLI pinned to AKAMAI_CLI_VERSION (checksum verified against the release .sig)
# plus the Property Manager package (`akamai property-manager`, CDN properties).
# The package is a Node.js project cloned into ~/.akamai-cli, so nodejs must be installed.
. "$REPO_ROOT/lib.sh"
bin=/usr/local/bin/akamai
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

base="https://github.com/akamai/cli/releases/download/${AKAMAI_CLI_VERSION}/akamai-${AKAMAI_CLI_VERSION}-linuxamd64"
retry 3 curl -fsSL "$base" -o "$tmp/akamai"
retry 3 curl -fsSL "$base.sig" -o "$tmp/akamai.sig"
# the .sig file holds the plain sha256 of the binary
echo "$(tr -d '[:space:]' < "$tmp/akamai.sig")  $tmp/akamai" | sha256sum -c - >/dev/null \
  || { echo "akamai: checksum mismatch for $base" >&2; exit 1; }
sudo install -m 0755 "$tmp/akamai" "$bin"
"$bin" --version

# The package is installed with npm. Node trusts the corporate CA only through
# NODE_EXTRA_CA_CERTS (profile.d/node_certs.sh), which a running installer has not sourced
# yet; without it every registry fetch fails three times with a backoff behind Zscaler.
export NODE_EXTRA_CA_CERTS="${NODE_EXTRA_CA_CERTS:-/etc/nodecerts.pem}"

# Unknown commands print the usage with exit code 0 and `akamai install` reports an
# existing package with exit code 0 too, so look for a version number instead.
pm_version() { "$bin" property-manager --version </dev/null 2>/dev/null | grep -E '^[0-9]+\.[0-9]+'; }
if v=$(pm_version); then
  echo "akamai property-manager $v already installed"
else
  if [ -d "$HOME/.akamai-cli/src/cli-property-manager" ]; then
    "$bin" uninstall property-manager </dev/null || true   # half-installed leftover
  fi
  retry 3 "$bin" install property-manager </dev/null
  v=$(pm_version) || { echo "akamai property-manager did not report a version after the install" >&2; exit 1; }
  echo "akamai property-manager $v installed"
fi
