# <img src="deepseek.svg" width="64" height="64" /> DeepSeek for Firefox AI Sidebar

![Firefox](https://img.shields.io/badge/Firefox-ESR_153-0095DD?logo=firefox-browsers&logoColor=white)
![Type](https://img.shields.io/badge/type-omni.ja_patch-orange)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)

[中文说明](README.zh-CN.md)

This is **not** a browser extension. It is a patch that registers **DeepSeek** as a first-class provider in Firefox's **built-in AI chatbot sidebar** — the same dropdown that ships with Anthropic Claude, ChatGPT, Google Gemini and Le Chat Mistral.

Unlike sidebar extensions, DeepSeek appears in the **native provider dropdown**, so you can switch between providers at any time and it never disappears. No extra sidebar panel, no extra toolbar button — it behaves exactly like a built-in provider.

## How It Works

Firefox packs its UI code into `browser\omni.ja` (a ZIP archive). This patch modifies one module inside it:

- `modules/GenAI.sys.mjs` — adds a `https://chat.deepseek.com/` entry (id `deepseek`, name `DeepSeek`, whale icon, context limit) to the hardcoded `chatProviders` map, and appends `deepseek` to the default provider list.
- `chrome/browser/content/browser/genai/assets/brands/deepseek.svg` — the official DeepSeek whale icon.
- Your profile's `prefs.js` gets `browser.ml.chat.providers` set at user level, so Mozilla Nimbus experiments can't hide it.

## Requirements

- Windows, Firefox ESR 153 installed at `C:\Program Files\Mozilla Firefox`
- Administrator PowerShell (to write into `Program Files`)
- Firefox fully closed

## Install

```powershell
# Elevated PowerShell, Firefox closed:
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The script backs up the original archive to `browser\omni.ja.bak`, replaces it with the patched one, sets the provider-list preference and clears the JS startup cache so the change takes effect immediately.

## Usage

1. Start Firefox and open the AI chatbot sidebar: press _`Ctrl+Alt+X`_, or click the sidebar button and pick _AI Chatbot_.
2. Open the provider dropdown at the top — **DeepSeek** is now listed alongside Claude, ChatGPT, Gemini and Le Chat Mistral. Switch freely; it stays.
3. Log in to DeepSeek once in a normal tab; the sidebar shares the same login state.

> **Note**: the "Summarize page" context-menu action can auto-fill and auto-submit only for Claude and ChatGPT (hardcoded by Mozilla). DeepSeek's web app ignores the `?q=` prompt parameter, so prompts must be pasted manually.

## Rollback

```powershell
# Elevated PowerShell, Firefox closed:
powershell -ExecutionPolicy Bypass -File .\rollback.ps1
```

This restores `browser\omni.ja` from the `.bak` backup.

## Firefox Updates

A Firefox update overwrites `omni.ja` and removes the patch. Simply re-run `install.ps1` afterwards. If a future Firefox changes `GenAI.sys.mjs` internally, re-apply the two edits documented in [`modules_GenAI.sys.mjs`](modules_GenAI.sys.mjs).

## ⚠ Disclaimer

This is an independent project with no relationship to, and not affiliated with, DeepSeek or Mozilla. It modifies Firefox's own resource archive for personal use — do it at your own risk. The add-on <i>only</i> launches DeepSeek's web app inside the existing sidebar.

## © License

Scripts and documentation in this repository are available under the [MIT License](LICENSE). `modules_GenAI.sys.mjs` is derived from Mozilla Firefox source code, which is [MPL-2.0](https://www.mozilla.org/en-US/MPL/2.0/) licensed.
