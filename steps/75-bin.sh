#!/bin/bash
# step: bin
# Helper scripts (including the wslview wrapper) into /usr/local/bin.
. "$REPO_ROOT/lib.sh"
for f in bin/*; do
  install_file "$f" "/usr/local/bin/$(basename "$f")" 0755
done
