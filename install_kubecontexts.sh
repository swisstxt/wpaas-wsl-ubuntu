#!/bin/bash

read -p "Do you want to install default k8s contexts [y/N] " answer

if [[ "$answer" =~ ^[Yy]$ ]]; then
    read -p "please enter your swisstxt email address used for azure auth (watch for capitalization):" EMAIL
    mkdir -p ~/.kube
    for config in $(ls kube/); do
        sed "s/\!email\!/${EMAIL}/" kube/$config | tee ~/.kube/$config
        chmod g-r ~/.kube/$config
        chmod o-r ~/.kube/$config
    done
fi

