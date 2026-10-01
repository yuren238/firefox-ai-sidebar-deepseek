# <img src="deepseek.svg" width="64" height="64" /> DeepSeek for Firefox AI Sidebar

![Firefox](https://img.shields.io/badge/Firefox-ESR_153+-0095DD?logo=firefox-browsers&logoColor=white)
![Type](https://img.shields.io/badge/type-omni.ja_patch-orange)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)

[简体中文](README.zh-CN.md)

This is **not** a browser extension. It is a patch that registers **DeepSeek** as a first-class provider in Firefox's **built-in AI chatbot sidebar** — the native dropdown that ships with Anthropic Claude, ChatGPT, Google Gemini and Le Chat Mistral.

Unlike sidebar extensions, DeepSeek shows up in the **native provider dropdown**, can be switched at any time and never disappears. No extra sidebar panel, no extra toolbar button — it behaves exactly like a built-in provider.

## How it works

Firefox's UI code is packaged in `browser\omni.ja` (a ZIP archive). The patch does three things:

- **Patch the archive**: inserts a `https://chat.deepseek.com/` entry into the hardcoded `chatProviders` map in `modules/GenAI.sys.mjs` (id `deepseek`, name `DeepSeek`, whale icon) and appends it to the default provider list; also adds the whale icon as `brands/deepseek.svg`. The original is backed up as `browser\omni.ja.bak`.
- **Set the preference**: writes a user-level `browser.ml.chat.providers` pref to the profile's `prefs.js` so Mozilla Nimbus experiments cannot hide the entry.
- **Clear the startup cache**: empties the profile's `startupCache` so the patched module takes effect immediately.

If this session cannot write to `omni.ja`, the script **re-executes itself as SYSTEM through a scheduled task**, reads the resulting log back and removes the task again — fully automatic. The usual cause is a filesystem sandbox (union/overlay filesystems, containers) or a security suite's "file protection": the tell-tale sign is that you **can create new files but cannot modify existing ones**, and elevation does not help because the block sits in a filter driver. See `Run-AsSystem.ps1`.

On machines with multiple profiles or several Firefox installs, the script identifies the default profile of the current install **the same way Firefox itself does** — the `TaskBarIDs` registry key (`HKCU\Software\Mozilla\Firefox\TaskBarIDs`) maps each install directory to its hash, which selects the `[Install<hash>]` section in `profiles.ini`. That profile is marked as recommended; you can still pick any other profile or all of them from the menu.

## Requirements

- Windows; Firefox ESR 153.1.x / 154.0.1+ (any version that still contains the `chatProviders` map)
- Administrator rights (needs to write to `Program Files`)
- Firefox fully closed

## Install

**Option A — one click (recommended)**

Double-click `install-deepseek.bat` in Explorer, click **Yes** on the UAC prompt, then press Enter at the profile menu. The bat file requests elevation, checks that Firefox is closed, runs the patcher and shows the result.

**Option B — command line**

```powershell
# Admin PowerShell, Firefox closed:
powershell -ExecutionPolicy Bypass -File .\Add-DeepSeekToFirefox.ps1

# Non-interactive (no profile menu; patches the recommended profile):
powershell -ExecutionPolicy Bypass -File .\Add-DeepSeekToFirefox.ps1 -Auto

# On machines known to block the write: skip the direct attempt, go straight to SYSTEM:
powershell -ExecutionPolicy Bypass -File .\Add-DeepSeekToFirefox.ps1 -Auto -ForceSystemFallback

# The opposite: never re-execute as SYSTEM, fail loudly instead:
powershell -ExecutionPolicy Bypass -File .\Add-DeepSeekToFirefox.ps1 -NoSystemFallback
```

The script opens the installed `browser\omni.ja` in place and patches it — no binaries are shipped. Idempotent: just re-run after every Firefox update.

> **Troubleshooting — patched but DeepSeek not in the dropdown**: Firefox keeps compiled copies of its modules in the profile's **startup cache**, which lives under `%LOCALAPPDATA%\Mozilla\Firefox\Profiles\<profile>\startupCache` (not Roaming). The script clears it, but if the run was interrupted before that step, delete the folder manually and restart Firefox.

## Usage

1. Start Firefox and log in to `chat.deepseek.com` once in a normal tab (the sidebar shares the login state).
2. Open the AI chatbot sidebar: press _`Ctrl+Alt+X`_, or click the sidebar button and choose _AI Chatbot_.
3. Open the provider dropdown at the top — **DeepSeek** now sits next to Claude, ChatGPT, Gemini and Le Chat Mistral. Switch freely; it won't disappear.

> **Note**: the right-click "summarize page" action only auto-fills for Claude and ChatGPT (hardcoded by Mozilla). The DeepSeek web app does not understand the `?q=` prompt parameter, so paste manually.

## Rollback

```powershell
# Admin PowerShell, Firefox closed:
powershell -ExecutionPolicy Bypass -File .\rollback.ps1
```

Restores `browser\omni.ja` from the `.bak` backup (it has the same automatic SYSTEM fallback). Backups are **version-keyed**: the script records the backed-up Firefox version in `browser\omni.ja.bak.version` and refreshes the backup from the clean new archive whenever Firefox is upgraded, so a rollback always matches the installed version.

## After a Firefox update

Firefox updates overwrite `omni.ja` and remove the patch. Re-run `install-deepseek.bat` after updating (the backup refreshes itself for the new version). If a future version changes `GenAI.sys.mjs` beyond recognition, the script will tell you the anchor was not found.

> **Troubleshooting — "access to the path omni.ja is denied"**: something is intercepting the write. This happens with filesystem sandboxes (union/overlay filesystems, containers) or security-suite "file protection", and the tell-tale sign is that you **can create new files but cannot modify or delete existing ones** — elevation does not help, because the block sits in a filter driver, not in the ACL.
>
> **The script now handles this automatically.** When it detects that it cannot write, it registers a SYSTEM scheduled task that re-executes itself, bypassing that layer, then prints the resulting log and cleans the task up. You will see a transitional message starting with `Writes to the Firefox install directory were refused in this session.` followed by the full log between `--- begin output of the SYSTEM session ---` and its end marker.
>
> Two things to know:
> - A SYSTEM session has no console input, so the **profile menu is unavailable** and the recommended (install-default) profile is used. If you need a different profile, run the script in an environment where the write is not blocked.
> - The script re-points `APPDATA` / `LOCALAPPDATA` / `USERPROFILE` / `TEMP` at the calling user before doing its work, so profiles and the startup cache are still resolved correctly.
>
> If even the SYSTEM run cannot write (a deeper security product, typically), `-NoSystemFallback` makes the script fail immediately instead of going through the motion — at that point you have to temporarily disable the offending file protection.

## ⚠ Disclaimer

This is an independent project, not affiliated with DeepSeek or Mozilla. The patch modifies Firefox's own resource archive. For personal use only, at your own risk. It <i>merely</i> loads DeepSeek's web app inside the existing sidebar.

## © License

Scripts and documentation in this repo are [MIT licensed](LICENSE). The patched `GenAI.sys.mjs` originates from the Mozilla Firefox source code, licensed under [MPL-2.0](https://www.mozilla.org/en-US/MPL/2.0/).
