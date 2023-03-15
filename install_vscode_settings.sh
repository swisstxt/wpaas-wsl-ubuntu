#!/bin/bash

mkdir -p .vscode-server/data/Machine

cat vscode_settings.json | tee .vscode-server/data/Machine/settings.json