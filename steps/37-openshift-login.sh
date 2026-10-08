#!/bin/bash
# step: openshift-login
# openshift-login, the SRGSSR OpenShift kubectl credential plugin, pinned to OPENSHIFT_LOGIN_VERSION.
. "$REPO_ROOT/lib.sh"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
retry 3 curl -fsSL "https://github.com/SRGSSR/openshift-login/releases/download/${OPENSHIFT_LOGIN_VERSION}/openshift-login-linux-amd64" -o "$tmp"
sudo install -m 0755 "$tmp" /usr/local/bin/openshift-login

# The plugin only works when started by kubectl; run bare, it must report the missing exec info.
out=$(/usr/local/bin/openshift-login 2>&1 || true)
grep -q KUBERNETES_EXEC_INFO <<<"$out" || { echo "openshift-login did not start correctly:" >&2; echo "$out" >&2; exit 1; }
echo "openshift-login ${OPENSHIFT_LOGIN_VERSION} installed"
