#!/bin/bash

WSL_CONF_SOURCE=wsl.conf
WSL_CONF_TARGET=/etc/wsl.conf

if does_not_exists_or_is_different $WSL_CONF_TARGET $WSL_CONF_SOURCE; then
    echo "$WSL_CONF_TARGET does not appear to be installed"
    sudo cp $WSL_CONF_SOURCE $WSL_CONF_TARGET
else
    echo "$WSL_CONF_TARGET is installed and up to date"
fi