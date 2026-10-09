#!/bin/bash
# gcx keeps tokens in the OS keyring (Secret Service), which WSL does not provide and
# cannot unlock at login. "off" is the documented fallback: tokens stay in the
# mode-0600 ~/.config/gcx/config.yaml instead.
export GCX_KEYCHAIN=off

if command -v gcx >/dev/null 2>&1; then
   eval "$(gcx completion bash)"
fi
