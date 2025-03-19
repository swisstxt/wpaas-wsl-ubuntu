#!/bin/bash

for f in $(find home -type f); do
    target="$HOME/$(dirname $f | cut -d/ -f2-)"
    mkdir -p $target
    cp $f $target
done