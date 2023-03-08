#!/bin/bash

wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb

# this will install dotnet 7 sdk and dotnet/asp.net runtime for 6.0
sudo apt-get update && sudo apt-get install -y dotnet-sdk-7.0 aspnetcore-runtime-6.0