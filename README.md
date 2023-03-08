# Ubuntu for WSL on WPAAS clients

## Usage for vanilla installations:

### Preparation

- Enable Windows Subsystem for Linux and Virtual Machine Platform
- Download and extract this repo to your windows computer and extract it's content somewhere
- Launch an elevated powershell (NOT using your adm-account) -> powershell -> run as administrator -> select your regular user
- as this script is not signed in any shape or form, we need to bypass the powershell execution policy using `Set-ExecutionPolicy Unrestricted`

### Execution

Launch the bootstrap.ps1 script `.\bootstrap.ps1` and it will guide you trough the further installation steps

### Or the YOLO way of doing things

if you are too lazy and simply don't care too much, just launch the script directly from github (yes, some people might complain)

```
Set-ExecutionPolicy Unrestricted
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/swisstxt/wpaas-wsl-ubuntu/master/bootstrap.ps1'))
```

## Usage for already running Ubuntu installations

- Download contents of this repo into your wsl installation
- Run `./install.sh`