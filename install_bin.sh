#!/bin/bash

SOURCE_DIR=bin
TARGET_DIR=/usr/local/bin

for bin in $(ls $SOURCE_DIR/*); do
    target="$TARGET_DIR/$(basename $bin)"
    if does_not_exists_or_is_different $target $bin; then
        echo "$bin does not appear to be installed"
        sudo cp $bin $target
    else
        echo "$bin is installed and up to date"
    fi
done