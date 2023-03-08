
curl (("https://cloud-images.ubuntu.com",
"releases/jammy/release",
"ubuntu-22.04-server-cloudimg-amd64.tar.gz") -join "/")  -OutFile rootfs-tar.gz

wsl --set-default-version 2
wsl --import --import ubuntu-wpaas (($HOME, "ubuntu-wpaas") -join "\") .\rootfs-tar.gz

$key = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss"
$dist = "ubuntu-wpaas"

$user = Read-Host -Prompt "Enter your linux username"

wsl -d ubuntu-wpaas -- useradd -m -G sudo -s /bin/bash $user
wsl -d ubuntu-wpaas -- passwd $user

Get-ChildItem -Path $key | ForEach-Object {
    $distributionName = (Get-ItemProperty -Path $_.PsPath).DistributionName
    if ($distributionName -eq $dist) {
        Set-ItemProperty -Path $_.PsPath -Name DefaultUid -Value 1000 -Type DWORD
        Write-Output "DefaultUid value set to 1000 for $($_.Name)"
    }
}

wsl -d ubuntu-wpaas -u $user -- curl -L https://github.com/swisstxt/wpaas-wsl-ubuntu/archive/refs/heads/master.zip -o ~/install.tar.gz
wsl -d ubuntu-wpaas -u $user -- tar xvzf ~/install.tar.gz -C ~
wsl -d ubuntu-wpaas -u $user --cd ~ -- tar xvzf ~/install.tar.gz
wsl -d ubuntu-wpaas -u $user --cd ~/wpaas-wsl-ubuntu-master -- bash install.sh