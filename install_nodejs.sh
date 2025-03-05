#!/bin/bash

sudo apt-get install -y nodejs npm
sudo npm install -g n
sudo n 16

# configure npm proxy

npm config set proxy "http://gateway.zscloud.net:10268"
npm config set strict-ssl false # this is REAL BIG BS
