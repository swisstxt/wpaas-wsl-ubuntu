#!/bin/bash
# step: jdk
# Temurin JDKs from Adoptium; the highest LTS present becomes the default java/javac.
. "$REPO_ROOT/lib.sh"
fetch_keyring https://packages.adoptium.net/artifactory/api/gpg/key/public /etc/apt/keyrings/adoptium.gpg
write_apt_list adoptium \
  "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(os_codename) main"
apt_update
pkgs=()
for v in $TEMURIN_VERSIONS; do pkgs+=("temurin-${v}-jdk"); done
apt_install "${pkgs[@]}"

default=""
for v in $TEMURIN_LTS; do
  bin="/usr/lib/jvm/temurin-${v}-jdk-amd64/bin/java"
  if [ -x "$bin" ]; then default=$bin; fi
done
if [ -z "$default" ]; then
  echo "no temurin LTS found under /usr/lib/jvm" >&2
  exit 1
fi
sudo update-alternatives --set java "$default"
sudo update-alternatives --set javac "${default%java}javac"
java -version
