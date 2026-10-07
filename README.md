# Ubuntu for WSL on WPAAS clients

Installs an Ubuntu 26.04 LTS (resolute) WSL distribution named `ubuntu-wpaas-resolute`
with the SwissTXT developer toolchain. Existing WSL distributions are never touched.

## What you get

- Corporate CA certificates for the system store, Java keystores, Node (`NODE_EXTRA_CA_CERTS`) and Python requests.
  No proxy settings: the Zscaler client connector handles the proxy transparently.
- Docker CE (skipped when Docker Desktop WSL integration is detected), NVIDIA container toolkit
- kubectl 1.34 (pinned) with kubelogin, krew, kubectx/kubens, optional SwissTXT kube contexts
- Helm 4
- Temurin JDK 11, 17, 21, 25 (25 is the default)
- .NET SDK (newest available, currently 10.0)
- Node.js (current LTS via `n`)
- Rust (rustup), Python 3, git + git-flow, GitHub CLI with `gh act`, jq, yq, ffmpeg, mediainfo
- HashiCorp Vault CLI, Telepresence
- Claude Code CLI and OpenAI Codex CLI
- Powerline prompt with the CaskaydiaCove Nerd Font configured in Windows Terminal
- VA-API video acceleration (d3d12), `wslview` to open URLs in the Windows browser
- Optional: Rider and IntelliJ IDEA Ultimate (snap)

## Prerequisites

- Windows 11 with WSL 2.4.4 or newer (`wsl --version`; run `wsl --update` if older)
- Windows Terminal
- A regular (non admin) user session; no elevation needed

## Fresh installation

1. Download or clone this repository on Windows.
2. Open PowerShell as your regular user and allow the script once:
   `Set-ExecutionPolicy -Scope Process Bypass`
3. Run `.\bootstrap.ps1`.
4. When the new distribution starts for the first time, create your Linux user when asked, then type `exit`.
5. Answer the installer's questions (git identity, kube contexts, JetBrains IDEs). They are asked once and remembered.
6. Wait for the summary. The script runs the installer a second time after a restart of the
   distribution to finish steps that need systemd.

`bootstrap.ps1 -Name ubuntu-wpaas-test` installs under another name for testing.

## Reruns, failures and flags

Inside the distribution the installer lives in `~/installer`. Every step runs in isolation,
logs to `~/.wpaas-installer/logs/<step>.log` and is marked done in `~/.wpaas-installer/state/`.
A rerun skips done steps and never asks the saved questions again.

```
cd ~/installer
./install.sh                    # rerun, only not-yet-done steps execute
./install.sh --list             # show steps
./install.sh --only helm --force   # rerun one step
./install.sh --skip jetbrains   # skip a step this run
./install.sh --reset            # forget state, logs and answers
```

Answers can be pre-seeded for unattended runs: `WPAAS_GIT_NAME`, `WPAAS_GIT_EMAIL`,
`WPAAS_INSTALL_KUBECONTEXTS` (y/n), `WPAAS_AZURE_EMAIL`, `WPAAS_INSTALL_JETBRAINS` (y/n),
together with `--non-interactive`.

Steps `certificates` and `apt-base` are required: if one fails the run stops. Any other
failure is reported in the summary and the run continues.

## Updating an existing resolute installation

```
cd ~/installer && git pull && ./install.sh --force
```

## Development

- `test/lint.sh` runs shellcheck over all shell files.
- `test/runner-test.sh` checks the step runner against dummy steps.
- `test/docker-smoke.sh [install.sh args]` runs the installer inside `ubuntu:26.04`
  against the real repositories (systemd steps report DEFERRED there).
- Version knobs live in `vars.sh`. Steps live in `steps/NN-<name>.sh`; the header comments
  `# required: 1`, `# needs_systemd: 1` and `# needs_answers: ...` are read by the runner.
