#!/bin/bash
# step: aws
# AWS CLI v2 and s3cmd from the Ubuntu archive (26.04 ships awscli 2.x). The awscli
# package brings its own bash-completion file, s3cmd has none.
. "$REPO_ROOT/lib.sh"
apt_install awscli s3cmd
aws --version
s3cmd --version
