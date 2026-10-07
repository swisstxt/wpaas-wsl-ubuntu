#!/bin/bash
export PATH=$PATH:$HOME/.local/bin

POWERLINE=/usr/share/powerline/bindings/bash/powerline.sh

# Powerline configuration
if [ -f "$POWERLINE" ]; then
    powerline-daemon -q
    export POWERLINE_BASH_CONTINUATION=1
    export POWERLINE_BASH_SELECT=1
    # shellcheck source=/dev/null
    source "$POWERLINE"
fi