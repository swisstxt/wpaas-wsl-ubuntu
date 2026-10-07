#!/bin/bash
# step: home
# Copies everything under home/ into $HOME, keeping the relative layout.
. "$REPO_ROOT/lib.sh"
if [ ! -d home ]; then echo "no home/ files to install"; exit 0; fi
while IFS= read -r -d '' f; do
  target="$HOME/${f#home/}"
  mkdir -p "$(dirname "$target")"
  cp "$f" "$target"
  echo "installed $target"
done < <(find home -type f -print0)
