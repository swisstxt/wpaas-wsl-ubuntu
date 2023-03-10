export PATH=$PATH:$HOME/.local/bin

POWERLINE=/usr/share/powerline/bindings/bash/powerline.sh

# Powerline configuration
if [ -f "$POWERLINE" ]; then
    /usr/bin/powerline-daemon -q
    POWERLINE_BASH_CONTINUATION=1
    POWERLINE_BASH_SELECT=1
    source "$POWERLINE"
fi