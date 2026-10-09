#!/bin/bash
# Runs shellcheck over every shell file in the repo. Warnings fail the build.
# Uses a local shellcheck when installed, otherwise the official docker image.
set -u
cd "$(dirname "$0")/.." || exit 1
files=(install.sh lib.sh vars.sh lib/runner.sh bin/wslview bin/kubectl_complete-ns bin/kubectl_complete-krew)
for f in steps/*.sh test/*.sh profile.d/*.sh; do [ -e "$f" ] && files+=("$f"); done
if command -v shellcheck >/dev/null; then
  shellcheck -x -S warning "${files[@]}" && echo "lint OK"
elif command -v docker >/dev/null; then
  docker run --rm -v "$PWD:/mnt:ro" koalaman/shellcheck:stable -x -S warning "${files[@]}" && echo "lint OK"
else
  echo "neither shellcheck nor docker is available" >&2
  exit 2
fi
