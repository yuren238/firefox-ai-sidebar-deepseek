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
```

The script opens the installed `browser\omni.ja` in place and patches it — no binaries are shipped. Idempotent: just re-run after every Firefox update.

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

Restores `browser\omni.ja` from the `.bak` backup.

## After a Firefox update

Firefox updates overwrite `omni.ja` and remove the patch. Re-run `install-deepseek.bat` after updating. If a future version changes `GenAI.sys.mjs` beyond recognition, the script will tell you the anchor was not found.

## ⚠ Disclaimer

This is an independent project, not affiliated with DeepSeek or Mozilla. The patch modifies Firefox's own resource archive. For personal use only, at your own risk. It <i>merely</i> loads DeepSeek's web app inside the existing sidebar.

## © License

Scripts and documentation in this repo are [MIT licensed](LICENSE). The patched `GenAI.sys.mjs` originates from the Mozilla Firefox source code, licensed under [MPL-2.0](https://www.mozilla.org/en-US/MPL/2.0/).
