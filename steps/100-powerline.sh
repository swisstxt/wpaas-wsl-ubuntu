#!/bin/bash
# step: powerline
# Always installed: bootstrap.ps1 guarantees the nerd font on the Windows side.
. "$REPO_ROOT/lib.sh"
apt_install powerline powerline-gitstatus
