#!/bin/bash
mkdir -p ~/.kube
touch ~/.kube/config ~/.kube/empty.config
chmod go-r ~/.kube/config ~/.kube/*.config

KUBECONFIG=~/.kube/config
for f in ~/.kube/*.config; do
  KUBECONFIG="$KUBECONFIG:$f"
done
export KUBECONFIG
export KUBECONFIG_INSTALLED=yes
