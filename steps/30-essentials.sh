#!/bin/bash
# step: essentials
# needs_answers: git_name git_email
. "$REPO_ROOT/lib.sh"
apt_install git build-essential git-flow
git config --global --unset-all http.proxy || true
git config --global user.name "$WPAAS_GIT_NAME"
git config --global user.email "$WPAAS_GIT_EMAIL"
git config --global --get user.email
