#!/bin/bash
# step: kubecontexts
# needs_answers: install_kubecontexts azure_email
. "$REPO_ROOT/lib.sh"
if [ "${WPAAS_INSTALL_KUBECONTEXTS:-n}" != y ]; then
  echo "kube contexts not wanted (answer install_kubecontexts=n)"
  exit 0
fi
mkdir -p ~/.kube
chmod 700 ~/.kube
for config in kube/*; do
  target="$HOME/.kube/$(basename "$config")"
  sed "s/!email!/${WPAAS_AZURE_EMAIL}/g" "$config" > "$target"
  chmod 600 "$target"
  echo "installed $target"
done
