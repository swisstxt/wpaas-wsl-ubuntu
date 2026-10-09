# Ubuntu for WSL on WPAAS clients

Installs an Ubuntu 26.04 LTS (resolute) WSL distribution named `ubuntu-wpaas-resolute`
with the SwissTXT developer toolchain. Existing WSL distributions are never touched.

## What you get

- Corporate CA certificates for the system store, Java keystores, Node (`NODE_EXTRA_CA_CERTS`) and Python requests.
  No proxy settings: the Zscaler client connector handles the proxy transparently.
- Docker CE (skipped when Docker Desktop WSL integration is detected), NVIDIA container toolkit
- kubectl 1.34 (pinned) with kubelogin, openshift-login (the SRGSSR OpenShift credential plugin), krew with the `ns` plugin (`kubectl ns`), kubectx/kubens, optional SwissTXT kube contexts. Tab completion covers `kubectl krew` and `kubectl ns`.
  The `stxt-dev-1`, `stxt-int-1` and `stxt-prd-1` OpenShift contexts expect a local SOCKS proxy on `localhost:1080`.
- Helm 4
- Temurin JDK 11, 17, 21, 25 (25 is the default)
- .NET SDK (newest available, currently 10.0)
- Node.js (current LTS via `n`, no distro node packages)
- Rust (rustup), Python 3, git + git-flow, GitHub CLI (`gh act` extension is installed once you have run `gh auth login`), jq, yq, ffmpeg, mediainfo
- AWS CLI v2 (with tab completion) and s3cmd; credentials go into `~/.aws/credentials` (`aws configure`) and `~/.s3cfg` (`s3cmd --configure`)
- HashiCorp Vault CLI, Telepresence
- gcx (Grafana CLI) with tab completion; connect to a stack with `gcx login <name> --server https://<stack>.grafana.net`, then `gcx config check`. WSL has no OS keyring, so `GCX_KEYCHAIN=off` is set and tokens live in the mode-0600 `~/.config/gcx/config.yaml`
- Akamai CLI with the Property Manager package (`akamai property-manager`, `akamai pipeline`); put your API credentials in `~/.edgerc` with a `[papi]` section
- Claude Code CLI with team settings (permissions, plugins, a two-line status line showing git state, PR, model, context and rate-limit bars) and OpenAI Codex CLI
- Powerline prompt with the CaskaydiaCove Nerd Font configured in Windows Terminal
- VA-API video acceleration (d3d12), `wslview` (also `xdg-open`) to open URLs in the Windows browser; `*.openshiftapps.com` opens in Firefox on the host
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
4. When the new distribution starts for the first time, create your Linux user when asked. The setup returns to bootstrap on its own.
5. Answer the installer's questions (git identity, kube contexts, JetBrains IDEs). They are asked once and remembered.
6. Wait for the summary. The script runs the installer a second time after a restart of the
   distribution to finish steps that need systemd.
7. Open a new terminal for the new distribution afterwards: tools installed under `~/.local/bin` (claude, codex) and snaps (`yq`) only appear on PATH in a fresh login shell.

`bootstrap.ps1 -Name ubuntu-wpaas-test` installs under another name for testing.
`-Branch <name>` makes it download the installer from that branch of this repository instead of `master` (useful for testing changes before they are merged).

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

`~/installer` is an extracted tarball, not a git clone. To update it:

```
cd ~ && curl -fsSL https://github.com/swisstxt/wpaas-wsl-ubuntu/archive/refs/heads/master.tar.gz -o install.tar.gz \
  && rm -rf installer && mkdir installer && tar xzf install.tar.gz -C installer --strip-components=1
cd ~/installer && ./install.sh --force --only <step>    # rerun just the steps you want
```

Avoid a blanket `./install.sh --force`: it reruns every step. Steps never overwrite files you
may have edited (`~/.kube/*.config`, the VS Code server settings), but a full rerun still takes
a long time.

## Development

- `test/lint.sh` runs shellcheck over all shell files.
- `test/runner-test.sh` checks the step runner against dummy steps.
- `test/docker-smoke.sh [install.sh args]` runs the installer inside `ubuntu:26.04`
  against the real repositories (systemd steps report DEFERRED there).
- Version knobs live in `vars.sh`. Steps live in `steps/NN-<name>.sh`; the header comments
  `# required: 1` and `# needs_systemd: 1` are read by the runner; `# needs_answers: ...`
  documents which answers a step uses.

## Tests

Every pull request runs `.github/workflows/tests.yml`: a gitleaks scan of the whole history
(`.gitleaks.toml` allowlists the Azure AD ids in `kube/`), shellcheck and the shell test suites
in `test/`, `test/bootstrap-test.ps1` on a Windows runner, and `test/docker-smoke.sh`, which
runs the whole installer non-interactively in an `ubuntu:26.04` container. All four jobs must
pass before a pull request can be merged, and merges go through the merge queue (`Merge when
ready`), which runs the same jobs on the queued commit. Run the tests locally with
`bash test/<name>.sh`.
