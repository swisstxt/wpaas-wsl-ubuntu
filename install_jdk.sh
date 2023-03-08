#!/bin/bash

sudo apt-get install -y wget apt-transport-https
sudo mkdir -p /etc/apt/keyrings
wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo tee /etc/apt/keyrings/adoptium.asc
sudo apt-get update
sudo apt-get install -y temurin-17-jdk temurin-11-jdk

default=$(update-alternatives --list java | grep temurin-11)
sudo update-alternatives --set java $default