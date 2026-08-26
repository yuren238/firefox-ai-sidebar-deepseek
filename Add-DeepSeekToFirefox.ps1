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
        header: "X-DeepSeek-Prompt",
        iconUrl: "chrome://browser/content/genai/assets/brands/deepseek.svg",
        id: "deepseek",
        maxLength: 12000,
        name: "DeepSeek",
        supportAutoSubmit: true,
      },
    ],
'@

$oldEntryBody = @'
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

# Normalize multi-line anchors to LF (editor/git may introduce CRLF)
$entryBody    = $entryBody.Replace("`r`n", "`n")
$oldEntryBody = $oldEntryBody.Replace("`r`n", "`n")

$zip = [System.IO.Compression.ZipFile]::Open($omni, 'Update')
try {
    $e = $zip.GetEntry('modules/GenAI.sys.mjs')
    if (-not $e) { throw 'modules/GenAI.sys.mjs not found inside omni.ja' }
    $reader = New-Object IO.StreamReader($e.Open())
    $src = $reader.ReadToEnd()
    $reader.Close()

    $moduleChanged = $false
    if ($src.Contains('X-DeepSeek-Prompt')) {
        Write-Host 'GenAI.sys.mjs already contains the current DeepSeek entry - skipped.'
    } elseif ($src.Contains($oldEntryBody) -or $src.Contains($oldEntryBody.Replace("`n", "`r`n"))) {
        # Upgrade: v1 entry (no header / no auto-submit) -> current entry.
        # Fixes "414 Request-URI Too Large" when summarizing long pages.
        $src = $src.Replace($oldEntryBody, $entryBody).Replace($oldEntryBody.Replace("`n", "`r`n"), $entryBody)
        $moduleChanged = $true
        Write-Host 'GenAI.sys.mjs upgraded: DeepSeek now uses header delivery + auto-submit.'
    } elseif ($src.Contains('chat.deepseek.com')) {
        Write-Warning 'GenAI.sys.mjs contains an unrecognized DeepSeek entry - left untouched.'
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

    # ---------- 2b. patch GenAIChild.sys.mjs: teach auto-submit about DeepSeek ----------
    $ce = $zip.GetEntry('actors/GenAIChild.sys.mjs')
    if (-not $ce) { throw 'actors/GenAIChild.sys.mjs not found inside omni.ja' }
    $cr = New-Object IO.StreamReader($ce.Open())
    $csrc = $cr.ReadToEnd()
    $cr.Close()
    $csrc = $csrc.Replace("`r`n", "`n")   # normalize line endings (archive entries may be CRLF)

    $childChanged = $false
    # 0) give slow SPAs (DeepSeek) time to mount their input: 1s -> 10s
    # (anchor includes the ")" so it cannot re-match inside "10000")
    if ($csrc.Contains('tms = 1000)')) {
        $csrc = $csrc.Replace('tms = 1000)', 'tms = 10000)')
        $childChanged = $true
        Write-Host 'GenAIChild.sys.mjs: input wait timeout 1s -> 10s.'
    }
    if ($csrc.Contains('textarea#chat-input')) {
        if (-not $childChanged) { Write-Host 'GenAIChild.sys.mjs already patched for DeepSeek - skipped.' }
    } else {
        # 1) recognize the DeepSeek input (<textarea id="chat-input">)
        $oldSel = (@'
'#prompt-textarea, [contenteditable], [role="textbox"]'
'@).TrimEnd()
        $newSel = @'
'#prompt-textarea, [contenteditable], [role="textbox"], textarea#chat-input, textarea[placeholder*="deepseek" i]'
'@.TrimEnd()
        $oldSel  = $oldSel.Replace("`r`n", "`n");  $newSel  = $newSel.Replace("`r`n", "`n")
        if (-not $csrc.Contains($oldSel)) { throw 'GenAIChild selector anchor not found - Firefox version may be too new' }
        $csrc = $csrc.Replace($oldSel, $newSel)

        # 2) fill textareas through the native value setter (textContent does not work on them)
        $oldFill = @'
    if (!editable.textContent) {
      editable.textContent = promptText;
      editable.dispatchEvent(new win.InputEvent("input", { bubbles: true }));
    }
'@
        $newFill = @'
    if (!editable.textContent) {
      if (editable.tagName == "TEXTAREA") {
        const setter = Object.getOwnPropertyDescriptor(
          win.HTMLTextAreaElement.prototype,
          "value"
        ).set;
        setter.call(editable, promptText);
      } else {
        editable.textContent = promptText;
      }
      editable.dispatchEvent(new win.InputEvent("input", { bubbles: true }));
    }
'@
        $oldFill = $oldFill.Replace("`r`n", "`n"); $newFill = $newFill.Replace("`r`n", "`n")
        if (-not $csrc.Contains($oldFill)) { throw 'GenAIChild fill anchor not found' }
        $csrc = $csrc.Replace($oldFill, $newFill)

        # 3) fall back to simulating Enter when no known send button exists
        $oldSend = @'
    if (submitBtn) {
      submitBtn.click();
      win._autosent = true;
    }
'@
        $newSend = @'
    if (submitBtn) {
      submitBtn.click();
      win._autosent = true;
    } else {
      const opts = { key: "Enter", code: "Enter", keyCode: 13, which: 13, bubbles: true };
      editable.dispatchEvent(new win.KeyboardEvent("keydown", opts));
      editable.dispatchEvent(new win.KeyboardEvent("keypress", opts));
      editable.dispatchEvent(new win.KeyboardEvent("keyup", opts));
      win._autosent = true;
    }
'@
        $oldSend = $oldSend.Replace("`r`n", "`n"); $newSend = $newSend.Replace("`r`n", "`n")
        if (-not $csrc.Contains($oldSend)) { throw 'GenAIChild submit anchor not found' }
        $csrc = $csrc.Replace($oldSend, $newSend)

        $childChanged = $true
        Write-Host 'GenAIChild.sys.mjs patched: DeepSeek textarea + Enter fallback.'
    }

    # ---------- 2b-up. widen the DeepSeek input selector (current DOM ships the textarea WITHOUT id) ----------
    $oldSelLine = @'
        '#prompt-textarea, [contenteditable], [role="textbox"], textarea#chat-input'
'@.Replace("`r`n", "`n")
    $newSelLine = @'
        '#prompt-textarea, [contenteditable], [role="textbox"], textarea#chat-input, textarea[placeholder*="deepseek" i]'
'@.Replace("`r`n", "`n")
    if ($csrc.Contains($oldSelLine) -and -not $csrc.Contains('placeholder*=')) {
        $csrc = $csrc.Replace($oldSelLine, $newSelLine)
        $childChanged = $true
        Write-Host 'GenAIChild.sys.mjs: DeepSeek selector widened (placeholder match).'
    }

    # ---------- 2b-up2. mark window right after a successful fill (prevents double-fill on retries) ----------
    $oldMark = @'
      editable.dispatchEvent(new win.InputEvent("input", { bubbles: true }));
    }

    // Explicitly wait for the button is ready
'@.Replace("`r`n", "`n")
    $newMark = @'
      editable.dispatchEvent(new win.InputEvent("input", { bubbles: true }));
      win._autosent = true;
    }

    // Explicitly wait for the button is ready
'@.Replace("`r`n", "`n")
    if ($csrc.Contains($oldMark) -and -not $csrc.Contains($newMark)) {
        $csrc = $csrc.Replace($oldMark, $newMark)
        $childChanged = $true
        Write-Host 'GenAIChild.sys.mjs: _autosent set after fill.'
    }

    # ---------- 2c. diagnostics: report each auto-submit step to the Browser Console ----------
    # (applies to fresh and already-patched archives alike)
    $oldDbg1 = @'
    const win = this.contentWindow;
    if (!win || win._autosent) {
      return;
    }
'@.Replace("`r`n", "`n")
    $newDbg1 = @'
    const win = this.contentWindow;
    console.error("[DS] AutoSubmit message received");
    if (!win || win._autosent) {
      console.error("[DS] blocked: no window or already sent");
      return;
    }
'@.Replace("`r`n", "`n")
    if ($csrc.Contains($oldDbg1)) { $csrc = $csrc.Replace($oldDbg1, $newDbg1); $childChanged = $true }

    $oldDbg2 = @'
    if (!editable) {
      return;
    }
'@.Replace("`r`n", "`n")
    $newDbg2 = @'
    if (!editable) {
      console.error("[DS] input NOT found within wait timeout");
      return;
    }
    console.error("[DS] input found:", editable.id || editable.tagName);
'@.Replace("`r`n", "`n")
    if ($csrc.Contains($oldDbg2)) { $csrc = $csrc.Replace($oldDbg2, $newDbg2); $childChanged = $true }

    $oldDbg3 = @'
      const opts = { key: "Enter", code: "Enter", keyCode: 13, which: 13, bubbles: true };
'@.Replace("`r`n", "`n")
    $newDbg3 = @'
      console.error("[DS] no known send button - using Enter fallback");
      const opts = { key: "Enter", code: "Enter", keyCode: 13, which: 13, bubbles: true };
'@.Replace("`r`n", "`n")
    if ($csrc.Contains($oldDbg3)) { $csrc = $csrc.Replace($oldDbg3, $newDbg3); $childChanged = $true }

    if ($childChanged) {
        $ce.Delete()
        $cn = $zip.CreateEntry('actors/GenAIChild.sys.mjs')
        $cs = $cn.Open()
        $cb = (New-Object Text.UTF8Encoding($false)).GetBytes($csrc)
        $cs.Write($cb, 0, $cb.Length)
        $cs.Close()
    }

    # ---------- 2d. parent-side markers in GenAI.sys.mjs (visible in parent-only console mode) ----------
    $me = $zip.GetEntry('modules/GenAI.sys.mjs')
    if (-not $me) { throw 'modules/GenAI.sys.mjs not found inside omni.ja' }
    $mr = New-Object IO.StreamReader($me.Open())
    $msrc = $mr.ReadToEnd()
    $mr.Close()
    $msrc = $msrc.Replace("`r`n", "`n")

    $mChanged = $false
    if ($msrc.Contains('[DS-P]')) {
        Write-Host 'GenAI.sys.mjs already has [DS-P] markers - skipped.'
    } else {
        $p1o = @'
  async handleAskChat(promptObj, context) {
'@.Replace("`r`n", "`n")
        $p1n = @'
  async handleAskChat(promptObj, context) {
    console.error("[DS-P] summarize clicked, provider =", lazy.chatProvider);
'@.Replace("`r`n", "`n")
        if ($msrc.Contains($p1o)) { $msrc = $msrc.Replace($p1o, $p1n); $mChanged = $true }

        $p2o = @'
    const { header, queryParam = "q", supportAutoSubmit } = this.chatProviders.get(lazy.chatProvider) ?? {};
'@.Replace("`r`n", "`n")
        $p2n = @'
    const { header, queryParam = "q", supportAutoSubmit } = this.chatProviders.get(lazy.chatProvider) ?? {};
    console.error("[DS-P] provider config:", JSON.stringify({ header: header || null, queryParam: queryParam, supportAutoSubmit: !!supportAutoSubmit }));
'@.Replace("`r`n", "`n")
        if ($msrc.Contains($p2o)) { $msrc = $msrc.Replace($p2o, $p2n); $mChanged = $true }

        $p3o = @'
      const actor = wgp?.getActor("GenAI");
      if (!actor) {
        return;
      }
'@.Replace("`r`n", "`n")
        $p3n = @'
      const actor = wgp?.getActor("GenAI");
      console.error("[DS-P] AutoSubmit actor present:", !!actor);
      if (!actor) {
        return;
      }
'@.Replace("`r`n", "`n")
        if ($msrc.Contains($p3o)) { $msrc = $msrc.Replace($p3o, $p3n); $mChanged = $true }

        $p4o = @'
      browser.webProgress?.addProgressListener(
        injector,
        Ci.nsIWebProgress.NOTIFY_STATE_DOCUMENT
      );
'@.Replace("`r`n", "`n")
        $p4n = @'
      console.error("[DS-P] arming sidebar STATE_STOP listener");
      browser.webProgress?.addProgressListener(
        injector,
        Ci.nsIWebProgress.NOTIFY_STATE_DOCUMENT
      );
'@.Replace("`r`n", "`n")
        if ($msrc.Contains($p4o)) { $msrc = $msrc.Replace($p4o, $p4n); $mChanged = $true }

        if ($mChanged) {
            $me.Delete()
            $mn = $zip.CreateEntry('modules/GenAI.sys.mjs')
            $ms = $mn.Open()
            $mb = (New-Object Text.UTF8Encoding($false)).GetBytes($msrc)
            $ms.Write($mb, 0, $mb.Length)
            $ms.Close()
            Write-Host 'GenAI.sys.mjs: [DS-P] parent markers added.'
        }
    }

    # ---------- 2e. sendAutoSubmit retry: the first STATE_STOP can fire against the
    # pre-navigation document (DeepSeek SPA), losing the AutoSubmit. Retry until the
    # actor of the MOUNTED chat UI is available. ----------
    $oldSendAuto = @'
    const sendAutoSubmit = (br, promptText) => {
      const wgp = br.browsingContext?.currentWindowGlobal;
      const actor = wgp?.getActor("GenAI");
      console.error("[DS-P] AutoSubmit actor present:", !!actor);
      if (!actor) {
        return;
      }

      try {
        actor.sendAsyncMessage("AutoSubmit", {
          promptText,
        });
      } catch (e) {
        console.error("error message: ", e);
      }
    };
'@.Replace("`r`n", "`n")
    $newSendAuto = @'
    const sendAutoSubmit = (br, promptText) => {
      let attempts = 0;
      const trySend = () => {
        attempts++;
        let actor = null;
        try {
          const wgp = br.browsingContext?.currentWindowGlobal;
          actor = wgp?.getActor("GenAI");
        } catch (e) {}
        console.error("[DS-P] AutoSubmit attempt", attempts, "actor:", !!actor);
        if (!actor) {
          if (attempts < 8) {
            setTimeout(trySend, 2500);
          }
          return;
        }
        try {
          actor.sendAsyncMessage("AutoSubmit", {
            promptText,
          });
        } catch (e) {
          console.error("error message: ", e);
        }
      };
      setTimeout(trySend, 1200);
    };
'@.Replace("`r`n", "`n")
    if ($msrc.Contains($oldSendAuto)) {
        $msrc = $msrc.Replace($oldSendAuto, $newSendAuto)
        $mChanged = $true
        Write-Host 'GenAI.sys.mjs: sendAutoSubmit retry loop added.'
    }

    if ($mChanged) {
        $me.Delete()
        $mn = $zip.CreateEntry('modules/GenAI.sys.mjs')
        $ms = $mn.Open()
        $mb = (New-Object Text.UTF8Encoding($false)).GetBytes($msrc)
        $ms.Write($mb, 0, $mb.Length)
        $ms.Close()
        Write-Host 'GenAI.sys.mjs updated.'
    }
} finally {
    $zip.Dispose()
}

# ---------- 3. pick which profile(s) to update ----------
# Enumerate every profile that has a prefs.js, sorted by most recent use
# (Firefox flushes prefs.js on exit, so newest mtime = last used).
$profilesRoot = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles'
$targets = @()
if (Test-Path $profilesRoot) {
    $targets = Get-ChildItem $profilesRoot -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName 'prefs.js') } |
        Sort-Object { (Get-Item (Join-Path $_.FullName 'prefs.js')).LastWriteTime } -Descending
}
if (-not $targets) {
    Write-Warning 'No Firefox profiles with prefs.js found - set browser.ml.chat.providers manually in about:config.'
    return
}

# Resolve the DEFAULT profile for this install exactly the way Firefox does:
# install dir -> hash (read from HKCU\...\TaskBarIDs, written by Firefox itself)
# -> [Install<hash>] section in profiles.ini -> Default=Profiles/xxx.
$recommendedIdx = 0
$installHash = $null
$tbid = Get-ItemProperty 'HKCU:\Software\Mozilla\Firefox\TaskBarIDs' -ErrorAction SilentlyContinue
if ($tbid) {
    $installHash = $tbid.PSObject.Properties |
        Where-Object { $_.Name -ieq $FirefoxDir } |
        Select-Object -First 1 -ExpandProperty Value
}
if ($installHash) {
    $cur = ''
    foreach ($l in Get-Content (Join-Path $env:APPDATA 'Mozilla\Firefox\profiles.ini')) {
        if ($l -match '^\[(.+)\]$') { $cur = $Matches[1]; continue }
        if ($cur -eq "Install$installHash" -and $l -match '^Default=Profiles/(.+)$') {
            for ($i = 0; $i -lt $targets.Count; $i++) {
                if ($targets[$i].Name -eq $Matches[1]) { $recommendedIdx = $i; break }
            }
            break
        }
    }
}

Write-Host ''
Write-Host 'Detected Firefox profiles (sorted by last use):'
for ($i = 0; $i -lt $targets.Count; $i++) {
    $tag = if ($i -eq $recommendedIdx) { '   <-- default profile of this install (recommended, just press Enter)' } else { '' }
    Write-Host ("  [{0}] {1}{2}" -f ($i + 1), $targets[$i].Name, $tag)
}
Write-Host '  [A] ALL of the above (harmless + idempotent)'
Write-Host ''

$line = 'user_pref("browser.ml.chat.providers", "claude,chatgpt,gemini,lechat,deepseek");'
function Set-ProviderPref {
    param([string]$ProfileDir)
    $prefs = Join-Path $ProfileDir 'prefs.js'
    $content = [IO.File]::ReadAllText($prefs)
    if ($content -match 'user_pref\("browser\.ml\.chat\.providers"') {
        $content = [regex]::Replace($content, 'user_pref\("browser\.ml\.chat\.providers"\s*,[^;]+\);', $line.Replace('$', '$$'))
        [IO.File]::WriteAllText($prefs, $content)
    } else {
        [IO.File]::AppendAllText($prefs, "`r`n$line`r`n")
    }
    Write-Host "Preference set for profile $(Split-Path $ProfileDir -Leaf)"
}

$chosen = $null
while (-not $chosen) {
    $answer = Read-Host 'Choose profile to update (Enter = recommended, a number, or A for all)'
    if ($answer -eq '') { $chosen = @($targets[$recommendedIdx]) }
    elseif ($answer -match '^[Aa]$') { $chosen = $targets }
    elseif ($answer -match '^\d+$' -and [int]$answer -ge 1 -and [int]$answer -le $targets.Count) {
        $chosen = @($targets[[int]$answer - 1])
    }
}

# ---------- 4. apply pref + clear JS startup cache for the chosen profiles ----------
foreach ($t in $chosen) {
    Set-ProviderPref -ProfileDir $t.FullName
    $sc = Join-Path $env:LOCALAPPDATA "Mozilla\Firefox\Profiles\$($t.Name)\startupCache"
    if (Test-Path $sc) {
        Remove-Item "$sc\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Startup cache cleared: $($t.Name)"
    }
}

Write-Host "`nDone. Start Firefox and open the AI chatbot sidebar (Ctrl+Alt+X) - DeepSeek is in the dropdown."
