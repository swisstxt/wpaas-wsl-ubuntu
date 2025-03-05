#!/bin/bash

sudo apt-get install -y nodejs npm
sudo npm install -g n
sudo n 16

# configure npm proxy

npm config set proxy "$HTTP_PROXY"
npm config set strict-ssl false # this is REAL BIG BS
