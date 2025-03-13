$dist = "ubuntu-wpaas-noble"
$rootfs = "$dist-rootfs.tar.gz"
$rootfsVpnKit = "wsl-vpnkit.tar.gz"
$distVpnKit = "wsl-vpnkit"



try {
    if (-not(Test-Path $rootfs)) {
        
        $url = (("https://cloud-images.ubuntu.com",
        "wsl/noble/current",
        "ubuntu-noble-wsl-amd64-ubuntu24.04lts.rootfs.tar.gz") -join "/")

        Write-Output "Downloading ubuntu cloud image from $url ...please be patient"

        Start-BitsTransfer -Source $url -Destination $rootfs
    }

    if (-not(Test-Path $rootfsVpnKit)) {
        
        $url = "https://github.com/sakai135/wsl-vpnkit/releases/download/v0.4.1/wsl-vpnkit.tar.gz"

        Start-BitsTransfer -Source $url -Destination $rootfsVpnKit
    }
    
    wsl --set-default-version 2
    wsl --import $distVpnKit (($HOME, $distVpnKit) -join "\") .\$rootfsVpnKit
    wsl --import $dist (($HOME, $dist) -join "\") .\$rootfs
    
    $user = Read-Host -Prompt "Enter your linux username"
    
    wsl -d $dist -- useradd -u 1000 -m -G sudo -s /bin/bash $user
    wsl -d $dist -- passwd $user
    
    $key = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss"
    
    Get-ChildItem -Path $key | ForEach-Object {
        $distributionName = (Get-ItemProperty -Path $_.PsPath).DistributionName
        if ($distributionName -eq $dist) {
            Set-ItemProperty -Path $_.PsPath -Name DefaultUid -Value 1000 -Type DWORD
            Write-Output "DefaultUid value set to 1000 for $($_.Name)"
        }
    }
    
    wsl -d $dist -u $user --cd ~ -- curl --insecure -L https://github.com/swisstxt/wpaas-wsl-ubuntu/archive/refs/heads/master.tar.gz -o install.tar.gz
    wsl -d $dist -u $user --cd ~ -- mkdir ~/installer
    wsl -d $dist -u $user --cd ~ -- tar xvzf install.tar.gz -C installer  --strip-components=1
    wsl -d $dist -u $user --cd ~/installer -- bash install.sh
    wsl --terminate $dist
    wsl -d $dist -u $user --cd ~/installer -- bash post_install.sh

} catch {
    Write-Output "$($_.ScriptStackTrace)"
    Write-Output "failed to setup WSL: $($_.Exception.Message)"
    exit 1
}

