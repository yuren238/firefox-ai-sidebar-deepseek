# Install DeepSeek provider patch for Firefox AI sidebar.
# Run from an ELEVATED PowerShell with Firefox fully closed.
# Auto-detects the default Firefox profile - no hardcoded paths.
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
try {
    if (Get-Process firefox -ErrorAction SilentlyContinue) { throw 'Firefox is still running' }

    # --- locate default profile (portable) ---
    $profilesRoot = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles'
    if (-not (Test-Path $profilesRoot)) { throw 'Firefox profiles folder not found' }
    $profileDir = Get-ChildItem $profilesRoot -Directory -Filter '*.default-esr*' | Select-Object -First 1
    if (-not $profileDir) { $profileDir = Get-ChildItem $profilesRoot -Directory -Filter '*.default*' | Select-Object -First 1 }
    if (-not $profileDir) { throw 'No default profile found' }
    $prefs = Join-Path $profileDir.FullName 'prefs.js'

    $ff   = 'C:\Program Files\Mozilla Firefox'
    $omni = Join-Path $ff 'browser\omni.ja'
    $bak  = Join-Path $ff 'browser\omni.ja.bak'

    if (-not (Test-Path $bak)) { Copy-Item $omni $bak -Force }

    $src = Join-Path $root 'omni-patched.ja'
    if (-not (Test-Path $src)) { throw "Patch archive not found: $src" }

    $ok = $false
    for ($i = 0; $i -lt 3 -and -not $ok; $i++) {
        try { Copy-Item $src $omni -Force; $ok = $true } catch { Start-Sleep -Seconds 2 }
    }
    if (-not $ok) { throw 'Failed to copy patched omni.ja' }

    # User pref for provider list (survives Nimbus default-branch overrides)
    $line  = 'user_pref("browser.ml.chat.providers", "claude,chatgpt,gemini,lechat,deepseek");'
    $content = [IO.File]::ReadAllText($prefs)
    if ($content -match 'user_pref\("browser\.ml\.chat\.providers"') {
        $content = [regex]::Replace($content, 'user_pref\("browser\.ml\.chat\.providers"\s*,[^;]+\);', $line.Replace('$', '$$'))
        [IO.File]::WriteAllText($prefs, $content)
    } else {
        [IO.File]::AppendAllText($prefs, "`r`n$line`r`n")
    }

    # Clear JS startup cache so the patched module takes effect immediately
    $sc = Join-Path $env:LOCALAPPDATA "Mozilla\Firefox\Profiles\$($profileDir.Name)\startupCache"
    if (Test-Path $sc) { Remove-Item "$sc\*" -Recurse -Force -ErrorAction SilentlyContinue }

    "OK omni=$((Get-Item $omni).Length) bytes, backup=$bak, profile=$($profileDir.Name)" | Tee-Object (Join-Path $root 'install-log.txt')
} catch {
    "FAIL $($_.Exception.Message)" | Tee-Object (Join-Path $root 'install-log.txt')
    exit 1
}
