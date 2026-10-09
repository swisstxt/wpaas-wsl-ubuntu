#!/bin/bash
# step: gcx
# gcx, the Grafana CLI for dashboards, datasources, alerting and Grafana Cloud resources
# (successor of grafanactl), pinned to GCX_VERSION and checked against the release
# checksum file. Completion and GCX_KEYCHAIN=off come from profile.d/gcx.sh.
. "$REPO_ROOT/lib.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
base="https://github.com/grafana/gcx/releases/download/v${GCX_VERSION}"
asset="gcx_${GCX_VERSION}_linux_amd64.tar.gz"
retry 3 curl -fsSL "$base/$asset" -o "$tmp/$asset"
retry 3 curl -fsSL "$base/gcx_${GCX_VERSION}_checksums.txt" -o "$tmp/checksums.txt"
(cd "$tmp" && grep " $asset\$" checksums.txt | sha256sum -c - >/dev/null) \
  || { echo "gcx: checksum mismatch for $base/$asset" >&2; exit 1; }
tar xzf "$tmp/$asset" -C "$tmp" gcx
sudo install -m 0755 "$tmp/gcx" /usr/local/bin/gcx
/usr/local/bin/gcx --version
