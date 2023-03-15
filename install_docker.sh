#!/bin/bash

WSL_DOCKER=/mnt/wsl/docker-desktop/cli-tools/usr/bin/docker

if [ ! -e "$WSL_DOCKER" ]; then  # only install docker if no docker desktop integration found

    sudo mkdir -p  /etc/systemd/system/docker.service.d

    sudo cp systemd/http-proxy.conf /etc/systemd/system/docker.service.d

    sudo apt-get -y remove docker docker-engine docker.io containerd runc
    sudo apt-get update
    sudo apt-get -y install \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        apt-transport-https \
        build-essential

    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    sudo adduser $USER docker
else
    echo "Docker desktop WSL integration active, not installing docker in wsl"
fi