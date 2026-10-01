# Roll back Firefox omni.ja to the original backup.
# Run from an ELEVATED PowerShell with Firefox fully closed.
# Clears the startup cache of EVERY profile - after a rollback this is
# required, otherwise cached bytecode of the patched module may survive
# and the rollback appears to have no effect.
#
# Like Add-DeepSeekToFirefox.ps1, this script first checks whether it can
# actually write to the install directory. If a filter driver, overlay file
# system or security product blocks it, the work is re-executed as SYSTEM
# through a scheduled task. See Run-AsSystem.ps1.
#Requires -RunAsAdministrator
param(
    [string]$FirefoxDir = 'C:\Program Files\Mozilla Firefox',

    # --- set by the SYSTEM re-execution path; not meant to be passed by hand ---
    [switch]$AsSystem,
    [string]$UserProfile = '',
    [string]$LogFile = '',

    # Skip the direct attempt and go straight to a SYSTEM scheduled task.
    [switch]$ForceSystemFallback,
    # Never re-execute as SYSTEM; fail with an explanation instead.
    [switch]$NoSystemFallback
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

$helper = Join-Path $root 'Run-AsSystem.ps1'
if (-not (Test-Path $helper)) { throw "Run-AsSystem.ps1 not found next to this script: $helper" }
. $helper

Initialize-SystemSession -AsSystem:$AsSystem -UserProfile $UserProfile -LogFile $LogFile

try {
    if (Get-Process firefox -ErrorAction SilentlyContinue) { throw 'Firefox is still running' }

    $omni = Join-Path $FirefoxDir 'browser\omni.ja'
    $bak  = Join-Path $FirefoxDir 'browser\omni.ja.bak'
    if (-not (Test-Path $bak)) { throw "Backup not found: $bak" }

    # Restoring means overwriting an existing file under Program Files - the one
    # operation some sandboxes refuse even to an elevated process.
    $fallback = @{
        ScriptPath = $PSCommandPath
        TargetFile = $omni
        ScriptArgs = @('-FirefoxDir', $FirefoxDir)
        TaskName   = 'FirefoxDeepSeekRollbackAsSystem'
        AsSystem   = $AsSystem
        Force      = $ForceSystemFallback
        Disabled   = $NoSystemFallback
    }
    if (Resolve-SystemFallback @fallback) { return }

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
    Complete-SystemSession -AsSystem:$AsSystem -LogFile $LogFile
    exit 1
}

Complete-SystemSession -AsSystem:$AsSystem -LogFile $LogFile
