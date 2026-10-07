#!/bin/bash
# step: tools
# Small CLI tools, python3, hushlogin and the VS Code server settings.
. "$REPO_ROOT/lib.sh"
apt_install gh jq ffmpeg mediainfo python3 python3-pip python3-venv python3-virtualenv python-is-python3
gh extension install https://github.com/nektos/gh-act || echo "gh-act: already installed or install failed (non-fatal)"
touch ~/.hushlogin
mkdir -p ~/.vscode-server/data/Machine
cp vscode_settings.json ~/.vscode-server/data/Machine/settings.json
