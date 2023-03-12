#!/bin/bash

sudo add-apt-repository -y ppa:oibaf/graphics-drivers
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y mesa-va-drivers vainfo
sudo adduser $USER video