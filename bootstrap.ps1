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
        Add-Type -Namespace Win32 -Name Font -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern int AddFontResource(string lpFileName);
[DllImport("user32.dll")] public static extern int SendNotifyMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
'@
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

function Set-TerminalProfileFont {
    param([string]$DistName, [string]$Face, [string]$SettingsPath = "")
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
        $json = Get-Content $SettingsPath -Raw | ConvertFrom-Json
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
        $list += [pscustomobject]@{ name = $DistName; source = "Microsoft.WSL"; font = [pscustomobject]@{ face = $Face } }
    }
    $json.profiles | Add-Member -NotePropertyName list -NotePropertyValue $list -Force
    $json | ConvertTo-Json -Depth 64 | Set-Content $SettingsPath -Encoding UTF8
    Write-Output "Windows Terminal profile '$DistName' uses font '$Face'"
}

function Invoke-Installer([string]$DistName, [string]$User) {
    & $wsl -d $DistName -u $User --cd "~" -- bash -c "curl --insecure -fsSL '$repoTarball' -o install.tar.gz && rm -rf installer && mkdir installer && tar xzf install.tar.gz -C installer --strip-components=1"
    if ($LASTEXITCODE -ne 0) { throw "Downloading the installer into $DistName failed ($LASTEXITCODE)" }
    & $wsl -d $DistName -u $User --cd "~/installer" -- bash install.sh
    $first = $LASTEXITCODE
    Write-Output "Restarting $DistName so systemd and wsl.conf take effect"
    & $wsl --terminate $DistName
    & $wsl -d $DistName -u $User --cd "~/installer" -- bash install.sh
    $second = $LASTEXITCODE
    if ($first -ne 0 -or $second -ne 0) {
        Write-Warning "Some installer steps failed. Logs: \\wsl.localhost\$DistName\home\$User\.wpaas-installer\logs. Rerun with: wsl -d $DistName -u $User --cd ~/installer -- bash install.sh"
    }
}

if ($LoadOnly) { return }

try {
    if (-not $SkipInstall) {
        Assert-WslVersion
        if (Test-DistroExists $dist) { throw "A WSL distribution named '$dist' already exists. Use -Name to pick another name or unregister it first." }
        if (-not (Test-Path $image)) {
            Write-Output "Downloading $imageUrl ... please be patient"
            Start-BitsTransfer -Source $imageUrl -Destination $image
        }
        & $wsl --install --from-file $image --name $dist --no-launch
        if ($LASTEXITCODE -ne 0) { throw "wsl --install failed ($LASTEXITCODE)" }
        Write-Output ""
        Write-Output "Starting $dist for the first time. Create your Linux user when asked, then type 'exit'."
        & $wsl -d $dist
        $user = (Get-WslText @("-d", $dist, "--", "id", "-un", "1000") | Select-Object -First 1)
        if (-not $user) { throw "No user with uid 1000 exists in $dist. Launch 'wsl -d $dist', finish the user setup, then rerun with the same -Name." }
        $user = $user.Trim()
        Write-Output "Linux user: $user"
    }
    Install-NerdFont
    Set-TerminalProfileFont -DistName $dist -Face $fontFace -SettingsPath $TerminalSettingsPath
    if (-not $SkipInstall) {
        Invoke-Installer -DistName $dist -User $user
        Write-Output "Done. Open '$dist' from Windows Terminal."
    }
} catch {
    Write-Output $_.ScriptStackTrace
    Write-Output "failed to set up WSL: $($_.Exception.Message)"
    exit 1
}
