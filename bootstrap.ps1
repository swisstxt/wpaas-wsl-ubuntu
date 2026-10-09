#Requires -Version 5.1
<#
.SYNOPSIS
  Installs the ubuntu-wpaas-<codename> WSL distribution and runs the installer inside it.
.PARAMETER Name
  Distribution name override (default ubuntu-wpaas-<Codename>), e.g. for test installs.
.PARAMETER LoadOnly
  Dot-source the functions without running anything (used by test/bootstrap-test.ps1).
#>
[CmdletBinding()]
param(
    [string]$Name = "",
    [string]$Release = "26.04.1",
    [string]$Codename = "resolute",
    [string]$Branch = "master",
    [string]$TerminalSettingsPath = "",
    [switch]$SkipInstall,
    [switch]$LoadOnly
)

$ErrorActionPreference = "Stop"
$series = $Release.Substring(0, 5)                       # 26.04
$dist = if ($Name) { $Name } else { "ubuntu-wpaas-$Codename" }
$image = "ubuntu-$Release-wsl-amd64.wsl"
$imageUrl = "https://releases.ubuntu.com/$series/$image"
$fontFace = "CaskaydiaCove Nerd Font Mono"
$fontZipUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip"
$repoTarball = "https://github.com/swisstxt/wpaas-wsl-ubuntu/archive/refs/heads/$Branch.tar.gz"
$wsl = "$env:SystemRoot\System32\wsl.exe"

function Get-WslText {
    # wsl.exe prints UTF-16; strip the NULs PowerShell 5.1 leaves behind.
    param([string[]]$WslArgs)
    (& $wsl @WslArgs | ForEach-Object { $_ -replace "`0", "" }) | Where-Object { $_ -ne $null }
}

function Test-DistroExists([string]$DistName) {
    $list = Get-WslText @("-l", "-q") | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    return $list -contains $DistName
}

function Assert-WslVersion {
    $line = Get-WslText @("--version") | Select-Object -First 1
    if (-not $line -or $line -notmatch "(\d+)\.(\d+)\.(\d+)") {
        throw "Could not read the WSL version. Run 'wsl --update' and try again."
    }
    $v = [version]("{0}.{1}.{2}" -f $Matches[1], $Matches[2], $Matches[3])
    if ($v -lt [version]"2.4.4") { throw "WSL $v is too old, 2.4.4 or newer is required. Run 'wsl --update'." }
    Write-Output "WSL version $v"
}

function Install-NerdFont {
    $fontsKey = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
    if (-not (Test-Path $fontsKey)) { New-Item -Path $fontsKey -Force | Out-Null }
    $installed = (Get-ItemProperty $fontsKey).PSObject.Properties | Where-Object {
        $_.Name -notlike "PS*" -and (
            $_.Name -like "CaskaydiaCove NFM*" -or
            $_.Name -like "CaskaydiaCove Nerd Font Mono*" -or
            $_.Name -like "CaskaydiaCoveNerdFontMono-*" -or
            [System.IO.Path]::GetFileName([string]$_.Value) -like "CaskaydiaCoveNerdFontMono-*")
    }
    if ($installed) {
        Write-Output "Font already installed: $fontFace"
        return
    }
    Write-Output "Installing $fontFace for the current user"
    $zip = Join-Path $env:TEMP "CascadiaCode.zip"
    $dir = Join-Path $env:TEMP "CascadiaCodeNF"
    try {
        Start-BitsTransfer -Source $fontZipUrl -Destination $zip
        if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
        Expand-Archive -Path $zip -DestinationPath $dir
        $fontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
        New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
        if (-not ('Win32.Font' -as [type])) {
            Add-Type -Namespace Win32 -Name Font -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern int AddFontResource(string lpFileName);
[DllImport("user32.dll")] public static extern int SendNotifyMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
'@
        }
        foreach ($f in Get-ChildItem $dir -Filter "CaskaydiaCoveNerdFontMono-*.ttf") {
            $dest = Join-Path $fontDir $f.Name
            # Skip the copy when the file is already there (it may be in use); still register it so a half-registered install heals.
            if (-not (Test-Path $dest)) { Copy-Item $f.FullName $dest -Force }
            # The value name is informational; Windows reads the face name from the file.
            New-ItemProperty -Path $fontsKey -Name "$($f.BaseName) (TrueType)" -Value $dest -PropertyType String -Force | Out-Null
            [Win32.Font]::AddFontResource($dest) | Out-Null
        }
        [Win32.Font]::SendNotifyMessage([IntPtr]0xffff, 0x1D, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null   # WM_FONTCHANGE
    } finally {
        Remove-Item -Recurse -Force $dir, $zip -ErrorAction SilentlyContinue
    }
}

function Remove-JsonComments {
    # Windows Terminal reads and writes JSONC (comments, trailing commas); ConvertFrom-Json in
    # PowerShell 5.1 accepts neither. Strings are matched first so their content is left alone.
    param([string]$Text)
    $pattern = '("(?:[^"\\]|\\.)*")|//[^\r\n]*|/\*[\s\S]*?\*/|,(?=\s*[\]}])'
    return [regex]::Replace($Text, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{
        param($m)
        if ($m.Groups[1].Success) { $m.Value } else { "" }
    })
}

function Set-TerminalProfileFont {
    param(
        [string]$DistName, [string]$Face, [string]$SettingsPath = "",
        [string]$FragmentsPath = (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\Microsoft.WSL")
    )
    if (-not $SettingsPath) {
        $candidates = @(
            (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"),
            (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json"))
        $SettingsPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    if (-not $SettingsPath -or -not (Test-Path $SettingsPath)) {
        Write-Warning "Windows Terminal settings.json not found. Set the font of profile '$DistName' to '$Face' manually."
        return
    }
    try {
        $raw = Get-Content $SettingsPath -Raw
        $clean = Remove-JsonComments $raw
        if ($clean -ne $raw) { Write-Output "Note: comments and trailing commas in $SettingsPath are not kept when it is rewritten (a backup is made)." }
        $json = $clean | ConvertFrom-Json
    } catch {
        Write-Warning "Could not parse $SettingsPath ($($_.Exception.Message)). Set the font of profile '$DistName' to '$Face' manually."
        return
    }
    Copy-Item $SettingsPath ("{0}.bak-{1}" -f $SettingsPath, (Get-Date -Format "yyyyMMddHHmmss"))
    $list = @($json.profiles.list)
    $profile = $list | Where-Object { $_.name -eq $DistName } | Select-Object -First 1
    if ($profile) {
        if ($profile.PSObject.Properties.Name -contains "font" -and $profile.font -is [System.Management.Automation.PSCustomObject]) {
            $profile.font | Add-Member -NotePropertyName face -NotePropertyValue $Face -Force
        } else {
            $profile | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{ face = $Face }) -Force
        }
    } else {
        # WSL registers the profile through a Windows Terminal fragment; reuse its guid so the entry attaches to it.
        $guid = $null
        if (Test-Path $FragmentsPath) {
            foreach ($file in Get-ChildItem $FragmentsPath -Filter "*.json" -ErrorAction SilentlyContinue) {
                try { $frag = Get-Content $file.FullName -Raw | ConvertFrom-Json } catch { continue }
                $match = @($frag.profiles) | Where-Object { $_.name -eq $DistName -and $_.guid } | Select-Object -First 1
                if ($match) { $guid = $match.guid; break }
            }
        }
        $entry = [ordered]@{}
        if ($guid) { $entry.guid = $guid } else { Write-Warning "No Windows Terminal profile registered by WSL found for '$DistName'. The font may need to be set manually in Windows Terminal ('$Face')." }
        $entry.name = $DistName
        $entry.source = "Microsoft.WSL"
        $entry.font = [pscustomobject]@{ face = $Face }
        $list += [pscustomobject]$entry
    }
    $json.profiles | Add-Member -NotePropertyName list -NotePropertyValue $list -Force
    $json | ConvertTo-Json -Depth 64 | Set-Content $SettingsPath -Encoding UTF8
    Write-Output "Windows Terminal profile '$DistName' uses font '$Face'"
}

function Invoke-Installer([string]$DistName, [string]$User) {
    & $wsl -d $DistName -u $User --cd "~" -- bash -c "curl --insecure -fsSL '$repoTarball' -o install.tar.gz && rm -rf installer && mkdir installer && tar xzf install.tar.gz -C installer --strip-components=1"
    if ($LASTEXITCODE -ne 0) { throw "Downloading the installer into $DistName failed ($LASTEXITCODE)" }
    # No pipe here: the Linux side must keep a console on stdout (sudo and read prompts, UTF-8 output).
    & $wsl -d $DistName -u $User --cd "~/installer" -- bash install.sh
    $first = $LASTEXITCODE
    Write-Host "Restarting $DistName so systemd and wsl.conf take effect"
    & $wsl --terminate $DistName
    & $wsl -d $DistName -u $User --cd "~/installer" -- bash install.sh
    $second = $LASTEXITCODE
    $script:installerOk = ($first -eq 0 -and $second -eq 0)
    if (-not $script:installerOk) {
        Write-Warning "Installer passes exited with $first and $second. Logs: \\wsl.localhost\$DistName\home\$User\.wpaas-installer\logs. Rerun with: wsl -d $DistName -u $User --cd ~/installer -- bash install.sh"
    }
}

if ($LoadOnly) { return }

try {
    if (-not $SkipInstall) {
        Assert-WslVersion
        if (Test-DistroExists $dist) { throw "A WSL distribution named '$dist' already exists. Use -Name to pick another name or unregister it first." }
        if (-not (Test-Path $image)) {
            Write-Output "Downloading $imageUrl ... please be patient"
            if (Test-Path "$image.part") { Remove-Item -Force "$image.part" }
            Start-BitsTransfer -Source $imageUrl -Destination "$image.part"
            Move-Item "$image.part" $image
        }
        & $wsl --install --from-file $image --name $dist --no-launch
        if ($LASTEXITCODE -ne 0) { throw "wsl --install failed ($LASTEXITCODE)" }
        Write-Output ""
        Write-Output "Starting $dist for the first time. Create your Linux user when asked."
        # WSL runs the image's out-of-box setup (user creation) only when an interactive shell is
        # opened, which leaves a shell that has to be closed with 'exit'. Running Ubuntu's setup
        # script directly as a command gives the same prompts and returns on its own. The script
        # is idempotent: when WSL runs it again on the first interactive shell it finds the user
        # and exits at once.
        $oobe = "/usr/lib/wsl/wsl-setup"
        $hasOobe = (Get-WslText @("-d", $dist, "-u", "root", "--", "sh", "-c", "test -x $oobe && echo yes") | Select-Object -First 1)
        if ("$hasOobe".Trim() -eq "yes") {
            & $wsl -d $dist -u root -- $oobe
            if ($LASTEXITCODE -ne 0) { throw "The first-run setup of $dist failed ($LASTEXITCODE)" }
        } else {
            # Image without the Ubuntu setup script: let WSL run its own first-run setup.
            Write-Output "Opening a shell: create your Linux user when asked, then type 'exit'."
            & $wsl -d $dist
        }
        $user = (Get-WslText @("-d", $dist, "--", "id", "-un", "1000") | Select-Object -First 1)
        if (-not $user) { throw "No user with uid 1000 exists in $dist. Run 'wsl --unregister $dist' and start bootstrap again, creating the user when the distribution first starts." }
        $user = $user.Trim()
        Write-Output "Linux user: $user"
    }
    Install-NerdFont
    Set-TerminalProfileFont -DistName $dist -Face $fontFace -SettingsPath $TerminalSettingsPath
    if (-not $SkipInstall) {
        Invoke-Installer -DistName $dist -User $user
    }
} catch {
    Write-Output $_.ScriptStackTrace
    Write-Output "failed to set up WSL: $($_.Exception.Message)"
    exit 1
}
if (-not $SkipInstall) {
    if ($script:installerOk) {
        Write-Output "Done. Open '$dist' from Windows Terminal."
    } else {
        Write-Output "Finished with installer failures. See the warning above."
        exit 1
    }
}
