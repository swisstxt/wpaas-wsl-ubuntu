#!/bin/bash
# step: vault
. "$REPO_ROOT/lib.sh"
fetch_keyring https://apt.releases.hashicorp.com/gpg /usr/share/keyrings/hashicorp-archive-keyring.gpg
write_apt_list hashicorp \
  "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(os_codename) main"
apt_update
apt_install vault
vault version
