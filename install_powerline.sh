#!/bin/bash

read -p "Do you want to install powerline? [y/N] " answer

if [[ "$answer" =~ ^[Yy]$ ]]; then
    sudo apt install python3-pip
    pip3 install --user powerline-status
fi