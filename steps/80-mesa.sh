#!/bin/bash
# step: mesa
# VA-API via the d3d12 gallium driver that ships in base mesa (mesa-libgallium). No PPA.
. "$REPO_ROOT/lib.sh"
apt_install vainfo mesa-libgallium libgl1-mesa-dri
sudo usermod -aG video "$USER"
