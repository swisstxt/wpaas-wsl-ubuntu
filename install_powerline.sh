#!/bin/bash

read -p "Do you want to install powerline? [y/N] " answer

if [[ "$answer" =~ ^[Yy]$ ]]; then
    sudo apt-get install -y powerline-gitstatus
fi