# Roll back Firefox omni.ja to the original backup.
# Run from an ELEVATED PowerShell with Firefox fully closed.
# Auto-detects the default Firefox profile - no hardcoded paths.
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
try {
    if (Get-Process firefox -ErrorAction SilentlyContinue) { throw 'Firefox is still running' }

    $omni = 'C:\Program Files\Mozilla Firefox\browser\omni.ja'
    $bak  = 'C:\Program Files\Mozilla Firefox\browser\omni.ja.bak'
    if (-not (Test-Path $bak)) { throw "Backup not found: $bak" }
    Copy-Item $bak $omni -Force

    $profilesRoot = Join-Path $env:LOCALAPPDATA 'Mozilla\Firefox\Profiles'
    $profileDir = Get-ChildItem $profilesRoot -Directory -Filter '*.default-esr*' | Select-Object -First 1
    if (-not $profileDir) { $profileDir = Get-ChildItem $profilesRoot -Directory -Filter '*.default*' | Select-Object -First 1 }
    if ($profileDir) {
        $sc = Join-Path $profileDir.FullName 'startupCache'
        if (Test-Path $sc) { Remove-Item "$sc\*" -Recurse -Force -ErrorAction SilentlyContinue }
    }

    "OK restored omni.ja from backup" | Tee-Object (Join-Path $root 'rollback-log.txt')
} catch {
    "FAIL $($_.Exception.Message)" | Tee-Object (Join-Path $root 'rollback-log.txt')
    exit 1
}
