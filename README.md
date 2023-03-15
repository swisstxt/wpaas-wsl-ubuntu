# Ubuntu for Windows Subsystem for Linux (WSL) on Workplace as a Service (WPAAS) Clients

This guide outlines the steps to install and use Ubuntu for Windows Subsystem for Linux (WSL) on Workplace as a Service (WPAAS) clients. The instructions are divided into two sections: one for vanilla installations and another for already running Ubuntu installations.

# What's included

## Configuration

- system ca-certificates for zscaler, stxt and srg
- HTTP_PROXY and HTTPS_PROXY
- Git proxy settings
- Npm proxy and certificates
- Version pinnings for kubectl and helm

# Features

- VA-API Video Hardware decode/encode accelertion via mesa/gallium/d3d12
- GPU containers (nvidia docker runtime)
- CUDA support

## Software Packages

- Docker
- Kubectl (incl alias & completion)
- Helm
- Node
- JDK 11+17 (Temurin)
- Dotnet SDK 6+7
- Git & GitHub CLI
- Powerline
- OpenAI whisper
- Rider
- IntelliJ

## Usage for Vanilla Installations

### Preparation

To begin, follow these steps:

1. Enable Windows Subsystem for Linux and Virtual Machine Platform.
2. Download and extract the contents of this repository to your Windows computer.
3. Launch an elevated PowerShell by running PowerShell as an administrator and selecting your administrative account.
4. Due to the unsigned nature of the script, the PowerShell execution policy must be bypassed using `Set-ExecutionPolicy Unrestricted`.
5. Once the script has finished running, it is recommended to restore the PowerShell execution policy to `Default`.

### Execution

After preparing your system, follow these steps to install Ubuntu:

1. Launch an elevated PowerShell (not using your administrative account) by running PowerShell as an administrator and selecting your regular user.
2. Run the `bootstrap.ps1` script located in the extracted repository using `.\bootstrap.ps1`.
3. The script will guide you through the remaining installation process.

### Notes

- This installation process will not affect any existing WSL installations; instead, it will create a new WSL installation named `ubuntu-wpaas`.
- After completing the installation process, it is recommended to restore the PowerShell execution policy to `Default`.

### Alternative, Non-recommended Installation Method

For a quicker installation method, execute the following PowerShell command directly from GitHub. However, this method is not recommended as it offers no security guarantees.

```
Set-ExecutionPolicy Unrestricted
iex (Invoke-WebRequest -Uri  https://raw.githubusercontent.com/swisstxt/wpaas-wsl-ubuntu/master/bootstrap.ps1).Content
```

## Usage for Already Running Ubuntu Installations

To install Ubuntu for WSL on an already running Ubuntu installation, follow these steps:

1. Download the contents of this repository into your WSL installation.
2. Run the `install.sh` script located in the extracted repository.

