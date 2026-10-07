#!/bin/bash
# step: profile
# Installs login environment snippets into /etc/profile.d and removes retired ones.
. "$REPO_ROOT/lib.sh"
for script in profile.d/*.sh; do
  install_file "$script" "/etc/profile.d/$(basename "$script")"
done
sudo rm -f /etc/profile.d/http_proxy_env.sh /etc/profile.d/node_ssl.sh
