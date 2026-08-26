# Roll back Firefox omni.ja to the original backup.
# Run from an ELEVATED PowerShell with Firefox fully closed.
# Clears the startup cache of EVERY profile - after a rollback this is
# required, otherwise cached bytecode of the patched module may survive
# and the rollback appears to have no effect.
param(
    [string]$FirefoxDir = 'C:\Program Files\Mozilla Firefox'
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
try {
    if (Get-Process firefox -ErrorAction SilentlyContinue) { throw 'Firefox is still running' }

    $omni = Join-Path $FirefoxDir 'browser\omni.ja'
    $bak  = Join-Path $FirefoxDir 'browser\omni.ja.bak'
    if (-not (Test-Path $bak)) { throw "Backup not found: $bak" }
    Copy-Item $bak $omni -Force
    Write-Host "Restored $omni from backup."

    # Clear startup cache for EVERY profile (no profile detection = no wrong-profile bugs)
    $lcRoot = Join-Path $env:LOCALAPPDATA 'Mozilla\Firefox\Profiles'
    if (Test-Path $lcRoot) {
        $cleared = 0
        Get-ChildItem $lcRoot -Directory | ForEach-Object {
            $sc = Join-Path $_.FullName 'startupCache'
            if (Test-Path $sc) {
                Remove-Item "$sc\*" -Recurse -Force -ErrorAction SilentlyContinue
                $cleared++
            }
        }
        Write-Host "Startup caches cleared ($cleared profile(s))."
    }

    "OK restored omni.ja from backup" | Tee-Object (Join-Path $root 'rollback-log.txt')
} catch {
    "FAIL $($_.Exception.Message)" | Tee-Object (Join-Path $root 'rollback-log.txt')
    exit 1
}
