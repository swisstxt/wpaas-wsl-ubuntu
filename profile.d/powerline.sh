export PATH=$PATH:$HOME/.local/bin

if command -v python3 >/dev/null 2>&1; then 
    SITE=$(python3 -c "import site; print(site.USER_SITE)")
fi

# Powerline configuration
if [ -f "$SITE/powerline/bindings/bash/powerline.sh" ]; then
    $HOME/.local/bin/powerline-daemon -q
    POWERLINE_BASH_CONTINUATION=1
    POWERLINE_BASH_SELECT=1
    source "$SITE/powerline/bindings/bash/powerline.sh"
fi