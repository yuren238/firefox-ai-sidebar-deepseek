#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Registers DeepSeek as a permanent provider in Firefox's built-in AI
    chatbot sidebar by patching browser\omni.ja in place.

.DESCRIPTION
    Patches modules/GenAI.sys.mjs inside your installed omni.ja:
      1. Inserts a DeepSeek entry into the chatProviders map
      2. Appends "deepseek" to the default provider list
      3. Adds the official whale icon (deepseek.svg)
    Then sets the user-level provider-list preference and clears the JS
    startup cache.

    Version-agnostic: works on Firefox ESR 153.1.x, 154.0.1+ and any future
    version that still contains the chatProviders map. Idempotent - safe to
    re-run (e.g. after every Firefox update).

.PARAMETER FirefoxDir
    Firefox installation folder. Defaults to C:\Program Files\Mozilla Firefox.

.EXAMPLE
    PS> .\Add-DeepSeekToFirefox.ps1
#>
param(
    [string]$FirefoxDir = 'C:\Program Files\Mozilla Firefox'
)
$ErrorActionPreference = 'Stop'

$omni = Join-Path $FirefoxDir 'browser\omni.ja'
if (-not (Test-Path $omni)) { throw "omni.ja not found: $omni" }
if (Get-Process firefox -ErrorAction SilentlyContinue) { throw 'Firefox is running - close it first' }

# ---------- 1. backup (once) ----------
$bak = Join-Path $FirefoxDir 'browser\omni.ja.bak'
if (-not (Test-Path $bak)) { Copy-Item $omni $bak -Force; Write-Host "Backup created: $bak" }
else { Write-Host "Backup already exists: $bak" }

# ---------- 2. patch the archive in place ----------
Add-Type -AssemblyName System.IO.Compression.FileSystem

$svg = @'
<!-- may be protected as a trademark in some jurisdictions -->
<svg xmlns="http://www.w3.org/2000/svg" width="38" height="38" viewBox="0 0 24 24" role="img"><title>DeepSeek</title><path fill="#4D6BFE" d="M23.748 4.651c-.254-.124-.364.113-.512.233-.051.04-.094.09-.137.137-.372.397-.806.657-1.373.626-.829-.046-1.537.214-2.163.848-.133-.782-.575-1.248-1.247-1.548-.352-.155-.708-.311-.955-.65-.172-.24-.219-.509-.305-.774-.055-.16-.11-.323-.293-.35-.2-.031-.278.136-.356.276-.313.572-.434 1.202-.422 1.84.027 1.436.633 2.58 1.838 3.393.137.094.172.187.129.323-.082.28-.18.553-.266.833-.055.179-.137.218-.328.14a5.5 5.5 0 0 1-1.737-1.179c-.857-.828-1.631-1.743-2.597-2.46a12 12 0 0 0-.689-.47c-.985-.957.13-1.743.387-1.836.27-.098.094-.433-.778-.428-.872.003-1.67.295-2.687.685a3 3 0 0 1-.465.136 9.6 9.6 0 0 0-2.883-.101c-1.885.21-3.39 1.1-4.497 2.622C.082 8.776-.231 10.854.152 13.02c.403 2.284 1.568 4.175 3.36 5.653 1.857 1.533 3.997 2.284 6.438 2.14 1.482-.085 3.132-.284 4.994-1.86.47.234.962.328 1.78.398.629.058 1.235-.031 1.705-.129.735-.155.684-.836.418-.961-2.155-1.004-1.682-.595-2.112-.926 1.095-1.295 2.768-3.598 3.284-6.733.05-.346.115-.834.108-1.114-.004-.171.035-.238.23-.257a4.2 4.2 0 0 0 1.545-.475c1.397-.763 1.96-2.016 2.093-3.517.02-.23-.004-.467-.247-.588M11.58 18.168c-2.088-1.642-3.101-2.183-3.52-2.16-.39.024-.32.472-.234.763.09.288.207.487.371.74.114.167.192.416-.113.603-.673.416-1.842-.14-1.897-.168-1.361-.801-2.5-1.86-3.301-3.306-.775-1.393-1.225-2.888-1.299-4.482-.02-.385.094-.522.477-.592a4.7 4.7 0 0 1 1.53-.038c2.131.311 3.946 1.264 5.467 2.774.868.86 1.525 1.887 2.202 2.89.72 1.066 1.494 2.082 2.48 2.915.348.291.626.513.892.677-.802.09-2.14.109-3.055-.615zm1.001-6.44a.306.306 0 0 1 .415-.287.3.3 0 0 1 .113.074.3.3 0 0 1 .086.214c0 .17-.136.307-.308.307a.303.303 0 0 1-.306-.307m3.11 1.596c-.2.081-.4.151-.591.16a1.25 1.25 0 0 1-.798-.254c-.274-.23-.47-.358-.551-.758a1.7 1.7 0 0 1 .015-.588c.07-.327-.007-.537-.238-.727-.188-.156-.426-.199-.689-.199a.6.6 0 0 1-.254-.078.253.253 0 0 1-.114-.358 1 1 0 0 1 .192-.21c.356-.202.767-.136 1.146.016.352.144.618.408 1.001.782.392.451.462.576.685.915.176.264.336.536.446.848.066.194-.02.353-.25.45"/></svg>
'@

$entryBody = @'
    [
      "https://chat.deepseek.com/",
      {
        iconUrl: "chrome://browser/content/genai/assets/brands/deepseek.svg",
        id: "deepseek",
        maxLength: 12000,
        name: "DeepSeek",
      },
    ],
'@

$zip = [System.IO.Compression.ZipFile]::Open($omni, 'Update')
try {
    $e = $zip.GetEntry('modules/GenAI.sys.mjs')
    if (-not $e) { throw 'modules/GenAI.sys.mjs not found inside omni.ja' }
    $reader = New-Object IO.StreamReader($e.Open())
    $src = $reader.ReadToEnd()
    $reader.Close()

    $moduleChanged = $false
    if ($src.Contains('chat.deepseek.com')) {
        Write-Host 'GenAI.sys.mjs already contains DeepSeek - entry insertion skipped.'
    } else {
        # Insert the entry right before the localhost entry (stable across versions).
        $anchors = @("    [`r`n      `"http://localhost:8080`",", "    [`n      `"http://localhost:8080`",")
        $inserted = $false
        foreach ($a in $anchors) {
            $idx = $src.IndexOf($a)
            if ($idx -ge 0) { $src = $src.Insert($idx, $entryBody + "`r`n"); $inserted = $true; break }
        }
        if (-not $inserted) {
            # Fallback: insert before the closing of the providers map ("  ]),")
            $idx = $src.IndexOf("  ]),")
            if ($idx -lt 0) { throw 'Could not find an insertion anchor in GenAI.sys.mjs - Firefox version may be too new' }
            $src = $src.Insert($idx, $entryBody + "`r`n")
        }
        # Extend the default provider list (visibility also covered by the user pref below)
        $oldList = '"claude,chatgpt,copilot,gemini,lechat"'
        if ($src.Contains($oldList)) {
            $src = $src.Replace($oldList, '"claude,chatgpt,copilot,gemini,lechat,deepseek"')
        } else {
            Write-Warning 'Default provider list pattern not found - visibility will rely on the user pref only.'
        }
        $moduleChanged = $true
        Write-Host 'GenAI.sys.mjs patched: DeepSeek entry inserted.'
    }

    if ($moduleChanged) {
        $e.Delete()
        $new = $zip.CreateEntry('modules/GenAI.sys.mjs')
        $s = $new.Open()
        $b = (New-Object Text.UTF8Encoding($false)).GetBytes($src)   # UTF-8 without BOM
        $s.Write($b, 0, $b.Length)
        $s.Close()
    }

    if (-not $zip.GetEntry('chrome/browser/content/browser/genai/assets/brands/deepseek.svg')) {
        $se = $zip.CreateEntry('chrome/browser/content/browser/genai/assets/brands/deepseek.svg')
        $ss = $se.Open()
        $sb = (New-Object Text.UTF8Encoding($false)).GetBytes($svg)
        $ss.Write($sb, 0, $sb.Length)
        $ss.Close()
        Write-Host 'Icon added: brands/deepseek.svg'
    }
} finally {
    $zip.Dispose()
}

# ---------- 3. user pref so Nimbus experiments cannot hide the entry ----------
# Locate the REAL default profile via profiles.ini ([Install] Default= is authoritative).
$profilesRoot = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles'
$profileName = $null
$ini = Join-Path $env:APPDATA 'Mozilla\Firefox\profiles.ini'
if (Test-Path $ini) {
    $sections = @{}
    $cur = $null
    foreach ($l in Get-Content $ini) {
        if ($l -match '^\[(.+)\]$') { $cur = $Matches[1]; $sections[$cur] = @{}; continue }
        if ($cur -and $l -match '^([^=]+)=(.*)$') { $sections[$cur][$Matches[1]] = $Matches[2] }
    }
    foreach ($s in $sections.Values) {
        if ($s.ContainsKey('Default') -and $s['Default'] -like 'Profiles/*') { $profileName = Split-Path $s['Default'] -Leaf; break }
    }
    if (-not $profileName) {
        foreach ($s in $sections.Values) {
            if ($s.ContainsKey('Path') -and $s['Default'] -eq '1') { $profileName = Split-Path $s['Path'] -Leaf; break }
        }
    }
}
if (-not $profileName -and (Test-Path $profilesRoot)) {
    $d = Get-ChildItem $profilesRoot -Directory -Filter '*.default-esr*' | Select-Object -First 1
    if (-not $d) { $d = Get-ChildItem $profilesRoot -Directory -Filter '*.default*' | Select-Object -First 1 }
    if ($d) { $profileName = $d.Name }
}

$profilePath = if ($profileName) { Join-Path $profilesRoot $profileName } else { $null }
if ($profilePath -and (Test-Path (Join-Path $profilePath 'prefs.js'))) {
    $prefs = Join-Path $profilePath 'prefs.js'
    $line  = 'user_pref("browser.ml.chat.providers", "claude,chatgpt,gemini,lechat,deepseek");'
    $content = [IO.File]::ReadAllText($prefs)
    if ($content -match 'user_pref\("browser\.ml\.chat\.providers"') {
        $content = [regex]::Replace($content, 'user_pref\("browser\.ml\.chat\.providers"\s*,[^;]+\);', $line.Replace('$', '$$'))
        [IO.File]::WriteAllText($prefs, $content)
    } else {
        [IO.File]::AppendAllText($prefs, "`r`n$line`r`n")
    }
    Write-Host "Preference set for profile $profileName"
} else {
    Write-Warning 'Default profile/prefs.js not found - set browser.ml.chat.providers manually in about:config.'
}

# ---------- 4. clear JS startup cache ----------
if ($profilePath -and (Test-Path $profilePath)) {
    $sc = Join-Path $env:LOCALAPPDATA "Mozilla\Firefox\Profiles\$profileName\startupCache"
    if (Test-Path $sc) { Remove-Item "$sc\*" -Recurse -Force -ErrorAction SilentlyContinue; Write-Host 'Startup cache cleared' }
}

Write-Host "`nDone. Start Firefox and open the AI chatbot sidebar (Ctrl+Alt+X) - DeepSeek is in the dropdown."
