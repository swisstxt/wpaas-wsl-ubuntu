#!/bin/bash

mkdir -p ~/.kube
touch ~/.kube/config
touch ~/.kube/empty.config

chmod g-r ~/.kube/config
chmod g-r ~/.kube/*.config
chmod o-r ~/.kube/config
chmod o-r ~/.kube/*.config

export KUBECONFIG=~/.kube/config:$(ls -a ~/.kube/*.config | xargs | sed 's/ /:/g') 
# export NO_PROXY="$NO_PROXY,$(find ~/.kube/ -name '*.config' -exec cat {} \; | grep server: | cut -d: -f3- | cut -d/ -f3- | grep -E swisstxt.ch\|media.int | cut -d: -f1 | sort | uniq |  sed -z 's/\n/,/g')"
export KUBECONFIG_INSTALLED=yes