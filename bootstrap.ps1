$dist = "ubuntu-wpaas"
$rootfs = "$dist-rootfs.tar.gz"

try {
    if (-not(Test-Path $rootfs)) {
        
        $url = (("https://mirror.scaleuptech.com/ubuntu-cloud-images",
        "wsl/jammy/current",
        "ubuntu-jammy-wsl-amd64-wsl.rootfs.tar.gz") -join "/")

        Write-Output "Downloading ubuntu cloud image from $url ...please be patient"

        Start-BitsTransfer -Source $url -Destination $rootfs
    }
    
    wsl --set-default-version 2
    wsl --import --import ubuntu-wpaas (($HOME, $dist) -join "\") .\$rootfs
    
    $user = Read-Host -Prompt "Enter your linux username"
    
    wsl -d ubuntu-wpaas -- useradd -u 1000 -m -G sudo -s /bin/bash $user
    wsl -d ubuntu-wpaas -- passwd $user
    
    $key = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss"
    
    Get-ChildItem -Path $key | ForEach-Object {
        $distributionName = (Get-ItemProperty -Path $_.PsPath).DistributionName
        if ($distributionName -eq $dist) {
            Set-ItemProperty -Path $_.PsPath -Name DefaultUid -Value 1000 -Type DWORD
            Write-Output "DefaultUid value set to 1000 for $($_.Name)"
        }
    }
    
    wsl -d ubuntu-wpaas -u $user --cd ~ -- curl --insecure -L https://github.com/swisstxt/wpaas-wsl-ubuntu/archive/refs/heads/master.tar.gz -o install.tar.gz
    wsl -d ubuntu-wpaas -u $user --cd ~ -- tar xvzf install.tar.gz
    wsl -d ubuntu-wpaas -u $user --cd ~/wpaas-wsl-ubuntu-master -- bash install.sh
    wsl --shutdown

} catch {
    Write-Output "$($_.ScriptStackTrace)"
    Write-Output "failed to setup WSL: $($_.Exception.Message)"
    exit 1
}

