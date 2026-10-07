#!/bin/bash
# step: helm
. "$REPO_ROOT/lib.sh"
fetch_keyring https://packages.buildkite.com/helm-linux/helm-debian/gpgkey /usr/share/keyrings/helm.gpg
write_apt_list helm-stable-debian \
  "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main"
write_apt_pin helm helm "${HELM_MAJOR}.*"
apt_update
apt_install helm
helm version
