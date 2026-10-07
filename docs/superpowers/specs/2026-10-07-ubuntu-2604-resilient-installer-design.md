# Ubuntu 26.04 upgrade and resilient installer — design

Date: 2026-10-07
Status: approved in brainstorming, pending written review

## Goal

Move the WPAAS WSL installer from Ubuntu 24.04 (noble) to Ubuntu 26.04 LTS
(resolute) as a hard switch, and restructure it so that a single failing step
no longer aborts the whole run and reruns are cheap, non-interactive and
idempotent.

Out of scope: supporting 24.04 and 26.04 from one codebase, migrating existing
WSL installations in place, and the mongodb/pgdg repos some machines carry.

## Findings that drive the design

Research done 2026-10-07 against the live repositories:

| Dependency | Ubuntu 26.04 status | Consequence |
|---|---|---|
| Ubuntu WSL image | Only published as `ubuntu-26.04.1-wsl-amd64.wsl` on releases.ubuntu.com; nothing under cloud-images.ubuntu.com/wsl/releases | New download URL; image ships an out-of-box (OOBE) user-creation hook expecting uid 1000 |
| Docker apt repo | `resolute` published | none |
| Adoptium | `resolute` published with temurin 8/11/17/21/25/26/27 | temurin-23 no longer exists |
| dotnet | `ppa:dotnet/backports` on resolute has 8.0/9.0; `dotnet-sdk-10.0` is in the archive; 6.0/7.0 are gone | install the newest SDK only |
| Mesa VA-API | `mesa-va-drivers` merged into `mesa-libgallium` (base mesa); oibaf PPA resolute dist is empty | drop PPA, install only `vainfo` |
| wslu | PPA stops at oracular; deleted from the 26.04 archive | replace `wslview` with a wrapper |
| HashiCorp, pkgs.k8s.io, NVIDIA toolkit, Helm (buildkite), krew, kubelogin, telepresence, rustup, gh | published or distro-agnostic | none |
| Platform | sudo-rs and Rust coreutils are the 26.04 defaults; python 3.14; snapd and lsb-release are in the WSL image | plain `sudo cp/tee/sh -c` usage is compatible; verify in the real run |

Pre-existing defects fixed as part of this work:

- kubectl pin `1.24.*` and helm pin `3.10.*` match nothing in the repos they
  point to; helm 3.10 is no longer downloadable at all (repo floor is 3.13.3,
  ceiling 4.3.0).
- Java keystore import fails on every rerun (`keytool` refuses an existing
  alias) and `set -e` aborts the run.
- `apt-get install snap` installs a 2013 gene-finder package, not snapd.
- `n 16` installs an end-of-life Node.
- Apt list files are appended on rerun (`kubernetes.list` ends up with two
  lines).
- bootstrap.ps1 still imports wsl-vpnkit although it is no longer needed.
- Prompts are scattered across the run, so every rerun re-asks them.

## Decisions taken with the user

- Hard switch to 26.04; no dual-release support.
- Distro name is `ubuntu-wpaas-<codename>`, i.e. `ubuntu-wpaas-resolute`.
  Existing WSL distributions are never touched.
- Proxy configuration is removed everywhere. The Zscaler client connector
  handles the proxy transparently. CA certificates must still be installed
  (system bundle, Java keystore, Node bundle, Python requests bundle).
- Helm 4. kubectl minor tracked by one variable (default 1.34).
- Java: temurin 11, 17, 21, 25 with the highest LTS present as default.
- Node: latest LTS via `n lts`.
- dotnet: the newest `dotnet-sdk-*` apt can see (archive plus backports PPA),
  currently 10.0.
- New steps for Claude Code CLI and OpenAI Codex CLI.
- wslu replaced by a repo-owned `wslview` wrapper.
- bootstrap.ps1 installs CaskaydiaCove Nerd Font per-user when missing and
  configures the Windows Terminal profile with "CaskaydiaCove Nerd Font Mono".
- wsl-vpnkit removed completely (import, service file, post step).
- Stability approach: step runner with per-step isolation, state and logs
  (Option A), not a minimal continue-on-error patch.

## Architecture

```
bootstrap.ps1                 Windows side: image, distro, user, font, terminal profile
install.sh                    orchestrator (single entry point, replaces post_install.sh)
lib/runner.sh                 step execution, state, logs, retries, summary
lib.sh                        existing file helpers (kept)
vars.sh                       version knobs (KUBECTL_MINOR, HELM_MAJOR, ...)
steps/NN-<name>.sh            one step per file, numbered for order
answers: ~/.wpaas-installer/answers.env
state:   ~/.wpaas-installer/state/<step>.done
logs:    ~/.wpaas-installer/logs/<step>.log
```

### bootstrap.ps1 (Windows side)

- Top-of-file variables: `$release = "26.04.1"`, `$codename = "resolute"`,
  `$dist = "ubuntu-wpaas-$codename"`, image URL
  `https://releases.ubuntu.com/26.04/ubuntu-$release-wsl-amd64.wsl`.
  A `-Name` parameter overrides `$dist` for throwaway test installs.
- Abort if `wsl -l -q` already lists `$dist`. No other distro is read or
  modified.
- Download the `.wsl` file with BITS if not already present.
- `wsl --install --from-file <file> --name $dist --no-launch`, then
  `wsl -d $dist` once interactively so the image's OOBE creates the user with
  uid 1000. Afterwards read the username with `wsl -d $dist -- id -un 1000`.
  No `useradd`, no registry `DefaultUid` edit.
- Font: check `HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts` for
  an entry containing "CaskaydiaCove Nerd Font Mono". If absent, download the
  `CascadiaCode.zip` asset of the latest nerd-fonts GitHub release, extract the
  `CaskaydiaCoveNerdFontMono-*.ttf` files, copy them to
  `%LOCALAPPDATA%\Microsoft\Windows\Fonts` and register each in that registry
  key. No admin rights needed.
- Terminal profile: locate the Windows Terminal `settings.json` (packaged
  path under `Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState`,
  falling back to the unpackaged path). Write a timestamped backup. In
  `profiles.list`, find the entry with `name == $dist`; set
  `font.face = "CaskaydiaCove Nerd Font Mono"`. If no entry exists, append
  `{ "name": $dist, "source": "Microsoft.WSL", "font": { "face": ... } }`.
- Installer run: download the repo tarball into `~/installer` inside the
  distro (first curl keeps `--insecure` because CA certs are not installed
  yet), run `bash install.sh`, `wsl --terminate $dist`, run `bash install.sh`
  again. The second run executes only the steps deferred for systemd.
- Remove all wsl-vpnkit handling.

### install.sh and lib/runner.sh (WSL side)

- `install.sh` parses flags, sources `vars.sh`, `lib.sh`, `lib/runner.sh`,
  collects answers, then iterates the ordered step list.
- Flags: `--list`, `--only <step>` (repeatable), `--skip <step>`
  (repeatable), `--force` (ignore `.done` markers for the selected steps),
  `--reset` (delete all state and answers), `--non-interactive` (fail instead
  of prompting for a missing answer).
- Step discovery: every `steps/NN-<name>.sh`, sorted by filename. The step id
  is `<name>` without the number. Each step file starts with a header of
  shell assignments read by the runner before execution:

  ```
  # step: certificates
  # required: 1          # abort the run on failure (default 0)
  # needs_systemd: 1     # defer when PID 1 is not systemd (default 0)
  # needs_answers: git_name git_email
  ```

- Execution: `bash -euo pipefail steps/NN-name.sh` in a child process with
  `cwd` set to the repo root and the answers exported as `WPAAS_<KEY>`
  environment variables. stdout and stderr are teed to the step log.
  Exit 0 writes the `.done` marker. Non-zero records FAILED; if `required`,
  the runner prints the summary and exits immediately.
- Answers: keys `git_name`, `git_email`, `azure_email`, `install_kubecontexts`
  (y/n), `install_jetbrains` (y/n). Asked once before any step runs, only for
  keys that are missing from `answers.env` and not provided as
  `WPAAS_<KEY>` env vars. Saved to `answers.env` with mode 600.
- Retries: `retry <n> <cmd...>` helper with a short backoff, used by steps for
  curl/wget downloads and `apt-get update`. All `apt-get` calls pass
  `-o Acquire::Retries=3` via an `APT_OPTS` variable from `vars.sh`.
- Summary: one line per step, status in {OK, FAILED, SKIPPED (done),
  SKIPPED (flag), DEFERRED (systemd)}, log path on FAILED. Exit code 1 if any
  step FAILED, 0 otherwise.

### Steps

Order and content (numbers indicative):

| Step | required | systemd | Notes |
|---|---|---|---|
| 10-home | | | copy `home/` files; gradle.properties loses proxy properties |
| 15-certificates | 1 | | system bundle, `update-ca-certificates`, `/etc/nodecerts.pem` |
| 20-profile | | | copy `profile.d/*.sh`; `http_proxy_env.sh` removed |
| 25-apt-base | 1 | | `apt-get update`, `ca-certificates curl gnupg unzip wget apt-transport-https software-properties-common`, `snapd` |
| 30-essentials | | | git, build-essential, git-flow, git identity from answers, no http.proxy |
| 35-kubectl | | | repo URL and pin file generated from `KUBECTL_MINOR`; kubelogin from GitHub |
| 40-helm | | | buildkite repo, pin `4.*` |
| 45-nodejs | | | `nodejs npm` from archive, `npm i -g n`, `n lts`; no proxy, no strict-ssl change |
| 50-dotnet | | | add `ppa:dotnet/backports`, install highest `dotnet-sdk-X.Y` found via `apt-cache search` |
| 55-jdk | | | temurin 11/17/21/25; default = highest LTS present (list from `update-alternatives --list java`, pick max of 11/17/21/25) |
| 60-java-certs | | | import `certificates/*.crt`; skip aliases already in the keystore |
| 65-docker | | | unchanged logic minus `http-proxy.conf`; list file overwritten |
| 70-wslconf | | | unchanged |
| 75-bin | | | copies `bin/*`, now including `wslview` |
| 80-mesa | | | `vainfo` only; no PPA, no `apt-get upgrade` |
| 85-nvidia-toolkit | | | unchanged repo logic |
| 90-kubecontexts | | | only if `install_kubecontexts=y`, uses `azure_email` |
| 95-tools | | | gh, gh-act, jq, ffmpeg, mediainfo, python3 set, hushlogin, vscode settings |
| 100-powerline | | | always installed |
| 105-krew, 110-kubectx | | | existence checks before clone/install |
| 115-vault, 120-telepresence, 125-rust | | | unchanged logic with retries |
| 130-claude | | | `curl --cacert /etc/ssl/certs/ca-certificates.crt -fsSL https://claude.ai/install.sh \| bash`; verify `~/.local/bin/claude --version` |
| 135-codex | | | `curl --cacert ... -fsSL https://chatgpt.com/codex/install.sh \| sh`; verify `codex --version` |
| 200-nvidia-runtime | | 1 | `nvidia-ctk runtime configure`, restart docker |
| 205-jetbrains | | 1 | rider and intellij snaps if `install_jetbrains=y` |
| 210-yq | | 1 | yq snap |
| 215-binfmt | | 1 | unchanged |

`wslview` wrapper (`bin/wslview`): a short bash script that takes one URL or
path argument and opens it with
`/mnt/c/Windows/System32/rundll32.exe url.dll,FileProtocolHandler <arg>`,
converting local paths with `wslpath -w` first. `BROWSER=wslview` stays in
`profile.d/wslu_browser.sh`.

### Removed files

`install_*.sh`, `post_install*.sh` (replaced by `steps/`), `vars.sh` proxy
values, `profile.d/http_proxy_env.sh`, `apt/apt.conf.d/98zscaler`,
`apt/apt.conf.d/99fixbadproxy`, `apt/preferences.d/{aspnet,dotnet,helm,kubectl}`
(helm and kubectl pins are now generated), `systemd/http-proxy.conf`,
`systemd/wsl-vpnkit.service`, `install_docker_proxy.sh`, `install_wslu.sh`,
`install_whisper.sh`.

### README

Rewritten for the new flow: prerequisites (WSL 2.4.4 or newer, Windows
Terminal), bootstrap usage, what gets installed, rerun and flag usage, where
logs and state live, how to reset.

## Error handling

- A step failure is isolated to that step. Required steps (certificates,
  apt-base) abort the run because everything after them depends on working
  TLS and apt.
- Network operations retry three times before the step fails.
- The runner never deletes user data. `--reset` only removes
  `~/.wpaas-installer`.
- bootstrap.ps1 stops on any error before the installer runs; after the
  installer runs it reports the installer's exit code and the log directory.

## Testing

- `test/lint.sh`: `shellcheck` over all shell files; fails on warnings.
- `test/runner-test.sh`: runs `lib/runner.sh` against a temporary step
  directory with dummy steps (one ok, one failing, one required-failing, one
  needs_systemd) and asserts state files, summary lines and exit codes.
- `test/docker-smoke.sh`: runs `install.sh --non-interactive` in an
  `ubuntu:26.04` container with `WPAAS_*` answers pre-seeded. Validates every
  apt and download step against real resolute repos; systemd-only steps show
  DEFERRED.
- Acceptance on a real machine: `bootstrap.ps1 -Name ubuntu-wpaas-test`, then
  check the summary is all OK, powerline renders in the new terminal profile,
  and `claude --version`, `codex --version`, `kubectl version --client`,
  `helm version`, `java -version`, `dotnet --list-sdks`, `node --version`
  report the expected versions. Rerun `install.sh` and confirm every step is
  SKIPPED with no prompt. Delete the test distro afterwards.

## Follow-ups (not part of this work)

- The mongodb and pgdg repos present on some machines are not managed by the
  installer.
