#!/bin/bash



# CHECK IF CA-CERTIFICATES IS INSTALLED

CA_CERTIFICATES_PACKAGE_NAME=ca-certificates

if package_installed "$CA_CERTIFICATES_PACKAGE_NAME"; then
  echo "$CA_CERTIFICATES_PACKAGE_NAME is already installed"
else
  echo "$CA_CERTIFICATES_PACKAGE_NAME is not installed... installing"
  sudo apt-get install -y "$CA_CERTIFICATES_PACKAGE_NAME"
fi

# INSTALL CERTIFICATES

CA_CERTIFICATES_SOURCE_DIR=certificates
CA_CERTIFICATES_TARGET_DIR=/usr/local/share/ca-certificates

for cert in $(ls $CA_CERTIFICATES_SOURCE_DIR/*.crt); do
    target="$CA_CERTIFICATES_TARGET_DIR/$(basename $cert)"
    if does_not_exists_or_is_different $target $cert; then
        echo "$cert does not appear to be installed"
        sudo cp $cert $target
    else
        echo "$cert is installed and up to date"
    fi
done

sudo update-ca-certificates