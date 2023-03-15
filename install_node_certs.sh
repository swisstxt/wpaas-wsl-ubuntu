#!/bin/bash

ls /usr/local/share/ca-certificates/*.crt | xargs -I% openssl x509 -in %  -outform PEM | sudo tee /etc/nodecerts.pem