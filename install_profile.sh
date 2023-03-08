#!/bin/bash

PROFILE_SOURCE_DIR=profile.d
PROFILE_TARGET_DIR=/etc/profile.d

for script in $(ls $PROFILE_SOURCE_DIR/*.sh); do
    target="$PROFILE_TARGET_DIR/$(basename $script)"
    if does_not_exists_or_is_different $target $script; then
        echo "$target does not appear to be installed - installing"
        sudo cp $script $target
    else
        echo "$target is installed and up to date"
    fi
done