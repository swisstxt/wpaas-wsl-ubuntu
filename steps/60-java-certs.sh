#!/bin/bash
# step: java-certs
# Imports the corporate CAs into every Temurin keystore, skipping certs already present.
. "$REPO_ROOT/lib.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Split every source file into single-certificate files (bundles contain several).
for f in certificates/*.crt certificates/*.pem; do
  [ -e "$f" ] || continue
  awk -v out="$tmp/$(basename "$f")" '/-----BEGIN CERTIFICATE-----/{n++} {print > (out "." n)}' "$f"
done

found=0
for kt in /usr/lib/jvm/temurin-*-jdk-amd64/bin/keytool; do
  [ -x "$kt" ] || continue
  found=$((found + 1))
  existing=$("$kt" -list -cacerts -storepass changeit -v | sed -nE 's/^[[:space:]]*SHA256: *//p')
  for c in "$tmp"/*; do
    [ -e "$c" ] || continue
    grep -q 'BEGIN CERTIFICATE' "$c" || continue   # fragment before the first cert holds no certificate
    fp=$(openssl x509 -in "$c" -noout -fingerprint -sha256 | cut -d= -f2)
    if grep -qxF "$fp" <<<"$existing"; then
      echo "$(basename "$c") already in $kt"
      continue
    fi
    alias="wpaas-$(tr -d ':' <<<"$fp" | cut -c1-16 | tr '[:upper:]' '[:lower:]')"
    echo "importing $(basename "$c") as $alias into $kt"
    sudo "$kt" -importcert -file "$c" -alias "$alias" -cacerts -storepass changeit -noprompt
    existing+=$'\n'"$fp"
  done
done
# Without a JDK the loop does nothing; failing keeps the step retryable after the jdk step is fixed.
if [ "$found" -eq 0 ]; then
  echo "no Temurin JDK found under /usr/lib/jvm (did the jdk step fail?)" >&2
  exit 1
fi
