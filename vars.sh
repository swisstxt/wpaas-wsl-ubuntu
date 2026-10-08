#!/bin/bash
# Version knobs for the installer. Sourced by install.sh, exported to every step.
KUBECTL_MINOR="1.34"         # pkgs.k8s.io repo and apt pin: kubectl ${KUBECTL_MINOR}.*
HELM_MAJOR="4"               # apt pin: helm ${HELM_MAJOR}.*
TEMURIN_VERSIONS="11 17 21 25"  # temurin-<v>-jdk packages to install
TEMURIN_LTS="11 17 21 25"       # ascending; the highest one installed becomes the default java
NODE_VERSION="lts"           # argument to `n`
OPENSHIFT_LOGIN_VERSION="v0.1.0"  # SRGSSR/openshift-login release tag
export KUBECTL_MINOR HELM_MAJOR TEMURIN_VERSIONS TEMURIN_LTS NODE_VERSION OPENSHIFT_LOGIN_VERSION
