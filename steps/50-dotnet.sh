#!/bin/bash
# step: dotnet
# Newest dotnet-sdk the archive plus the backports PPA can offer (10.0 at the time of writing).
. "$REPO_ROOT/lib.sh"
retry 3 sudo add-apt-repository -y ppa:dotnet/backports
apt_update
latest=$(apt-cache search --names-only '^dotnet-sdk-[0-9]+\.[0-9]+$' | cut -d' ' -f1 | sort -V | tail -n1)
if [ -z "$latest" ]; then
  echo "no dotnet-sdk package found" >&2
  exit 1
fi
echo "installing $latest"
apt_install "$latest"
dotnet --list-sdks
