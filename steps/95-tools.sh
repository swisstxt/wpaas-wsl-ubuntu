#!/bin/bash
# step: tools
# Small CLI tools, python3, hushlogin and the VS Code server settings.
. "$REPO_ROOT/lib.sh"
apt_install gh jq ffmpeg mediainfo python3 python3-pip python3-venv python3-virtualenv python-is-python3
if gh auth status >/dev/null 2>&1; then
  gh extension install https://github.com/nektos/gh-act || echo "gh-act: install failed (non-fatal)"
else
  echo "gh is not logged in; run 'gh auth login' and then 'gh extension install https://github.com/nektos/gh-act'"
fi
touch ~/.hushlogin
mkdir -p ~/.vscode-server/data/Machine
if [ -e ~/.vscode-server/data/Machine/settings.json ]; then
  echo "$HOME/.vscode-server/data/Machine/settings.json exists, leaving it untouched"
else
  cp vscode_settings.json ~/.vscode-server/data/Machine/settings.json
fi
