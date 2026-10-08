# Verifies Set-TerminalProfileFont against a temp copy of a settings.json. Run: powershell -NoProfile -File test/bootstrap-test.ps1
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\bootstrap.ps1" -SkipInstall -LoadOnly

$tmp = Join-Path $env:TEMP ("wpaas-bt-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
$settings = Join-Path $tmp "settings.json"
$fails = 0
function Assert($name, $cond) { if ($cond) { Write-Output "ok   $name" } else { Write-Output "FAIL $name"; $script:fails++ } }

# case 1: profile exists without font
@'
{ "profiles": { "defaults": {}, "list": [ { "name": "ubuntu-wpaas-resolute", "source": "Microsoft.WSL", "guid": "{1}" }, { "name": "other", "guid": "{2}" } ] } }
'@ | Set-Content $settings
Set-TerminalProfileFont -DistName "ubuntu-wpaas-resolute" -Face "CaskaydiaCove Nerd Font Mono" -SettingsPath $settings
$j = Get-Content $settings -Raw | ConvertFrom-Json
Assert "font set on existing profile" (($j.profiles.list | Where-Object name -eq "ubuntu-wpaas-resolute").font.face -eq "CaskaydiaCove Nerd Font Mono")
Assert "other profile untouched" (($j.profiles.list | Where-Object name -eq "other").PSObject.Properties.Name -notcontains "font")
Assert "backup written" ((Get-ChildItem $tmp -Filter "settings.json.bak-*").Count -eq 1)

# case 2: profile missing -> appended
@'
{ "profiles": { "list": [ { "name": "other", "guid": "{2}" } ] } }
'@ | Set-Content $settings
Set-TerminalProfileFont -DistName "ubuntu-wpaas-resolute" -Face "CaskaydiaCove Nerd Font Mono" -SettingsPath $settings -FragmentsPath (Join-Path $tmp "none")
$j = Get-Content $settings -Raw | ConvertFrom-Json
$p = $j.profiles.list | Where-Object name -eq "ubuntu-wpaas-resolute"
Assert "profile appended" ($null -ne $p)
Assert "appended profile has source" ($p.source -eq "Microsoft.WSL")
Assert "appended profile has font" ($p.font.face -eq "CaskaydiaCove Nerd Font Mono")
Assert "list still has other" (@($j.profiles.list).Count -eq 2)

# case 3: existing font object keeps other keys
@'
{ "profiles": { "list": [ { "name": "ubuntu-wpaas-resolute", "font": { "size": 11, "face": "Consolas" } } ] } }
'@ | Set-Content $settings
Set-TerminalProfileFont -DistName "ubuntu-wpaas-resolute" -Face "CaskaydiaCove Nerd Font Mono" -SettingsPath $settings
$j = Get-Content $settings -Raw | ConvertFrom-Json
Assert "font size kept" ($j.profiles.list[0].font.size -eq 11)
Assert "font face replaced" ($j.profiles.list[0].font.face -eq "CaskaydiaCove Nerd Font Mono")

# case 4: profile missing, WSL fragment provides the guid
$frag = Join-Path $tmp "fragments"
New-Item -ItemType Directory -Path $frag | Out-Null
@'
{ "profiles": [ { "name": "ubuntu-wpaas-resolute", "guid": "{11111111-2222-3333-4444-555555555555}" } ] }
'@ | Set-Content (Join-Path $frag "frag.json")
@'
{ "profiles": { "list": [ { "name": "other", "guid": "{2}" } ] } }
'@ | Set-Content $settings
Set-TerminalProfileFont -DistName "ubuntu-wpaas-resolute" -Face "CaskaydiaCove Nerd Font Mono" -SettingsPath $settings -FragmentsPath $frag
$j = Get-Content $settings -Raw | ConvertFrom-Json
$p = $j.profiles.list | Where-Object name -eq "ubuntu-wpaas-resolute"
Assert "appended profile carries fragment guid" ($p.guid -eq "{11111111-2222-3333-4444-555555555555}")
Assert "guid profile keeps font" ($p.font.face -eq "CaskaydiaCove Nerd Font Mono")

# case 5: JSONC as Windows Terminal writes it (comments, trailing commas); strings stay intact
@'
{
    // line comment with "quotes" and a // marker
    "$schema": "https://aka.ms/terminal-profiles-schema",
    /* block
       comment */
    "profiles": {
        "defaults": {},
        "list": [
            { "name": "ubuntu-wpaas-resolute", "source": "Microsoft.WSL", "guid": "{1}", "commandline": "wsl.exe -d x // not a comment", },
            { "name": "other", "guid": "{2}" /* keep */ },
        ],
    },
}
'@ | Set-Content $settings
Set-TerminalProfileFont -DistName "ubuntu-wpaas-resolute" -Face "CaskaydiaCove Nerd Font Mono" -SettingsPath $settings
$j = Get-Content $settings -Raw | ConvertFrom-Json
$p = $j.profiles.list | Where-Object name -eq "ubuntu-wpaas-resolute"
Assert "jsonc: font set" ($p.font.face -eq "CaskaydiaCove Nerd Font Mono")
Assert "jsonc: string containing // kept" ($p.commandline -eq "wsl.exe -d x // not a comment")
Assert "jsonc: other profile kept" (($j.profiles.list | Where-Object name -eq "other").guid -eq "{2}")
Assert "jsonc: schema kept" ($j.'$schema' -eq "https://aka.ms/terminal-profiles-schema")

Remove-Item -Recurse -Force $tmp
if ($fails -eq 0) { Write-Output "ALL OK" } else { Write-Output "$fails FAILED"; exit 1 }
