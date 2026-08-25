# <img src="deepseek.svg" width="64" height="64" /> DeepSeek for Firefox AI Sidebar

![Firefox](https://img.shields.io/badge/Firefox-ESR_153-0095DD?logo=firefox-browsers&logoColor=white)
![Type](https://img.shields.io/badge/type-omni.ja_patch-orange)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)

[English](README.md)

这**不是**一个浏览器扩展，而是一个补丁：把 **DeepSeek** 注册成 Firefox **内置 AI 聊天机器人侧边栏**的一等服务商——就是自带 Anthropic Claude、ChatGPT、Google Gemini、Le Chat Mistral 的那个原生下拉框。

与侧边栏扩展不同，DeepSeek 出现在**原生服务商下拉框**里，可以随时与其他服务商互切、永不消失。没有额外的侧栏面板、没有额外的工具栏按钮——表现和一个内置服务商完全一样。

## 工作原理

Firefox 的界面代码打包在 `browser\omni.ja`（ZIP 归档）中。本补丁修改其中一处模块：

- `modules/GenAI.sys.mjs` —— 在硬编码的 `chatProviders` 映射中新增 `https://chat.deepseek.com/` 条目（id `deepseek`、名称 `DeepSeek`、鲸鱼图标、上下文长度上限），并把 `deepseek` 追加进默认服务商列表。
- `chrome/browser/content/browser/genai/assets/brands/deepseek.svg` —— DeepSeek 官方鲸鱼图标。
- 同时向 profile 的 `prefs.js` 写入用户级 `browser.ml.chat.providers` 偏好，防止 Mozilla Nimbus 实验把它隐藏。

## 环境要求

- Windows，Firefox ESR 153 安装于 `C:\Program Files\Mozilla Firefox`
- 管理员 PowerShell（需要写入 `Program Files`）
- Firefox 完全退出

## 安装

```powershell
# 管理员 PowerShell，Firefox 已关闭：
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

脚本会先把原版归档备份为 `browser\omni.ja.bak`，再替换为补丁版，写入服务商列表偏好，并清空 JS 启动缓存，改动即时生效。

## 使用

1. 启动 Firefox，打开 AI 聊天机器人侧边栏：按 _`Ctrl+Alt+X`_，或点击侧边栏按钮选择 _AI 聊天机器人_。
2. 点开顶部服务商下拉框——**DeepSeek** 已与 Claude、ChatGPT、Gemini、Le Chat Mistral 并列。随意切换，它不会消失。
3. 先在普通标签页登录一次 DeepSeek；侧边栏共享同一登录状态。

> **注意**：右键"生成页面摘要"只对 Claude 和 ChatGPT 支持自动填入与自动提交（Mozilla 硬编码）。DeepSeek 网页不识别 `?q=` 提示词参数，需要手动粘贴。

## 回滚

```powershell
# 管理员 PowerShell，Firefox 已关闭：
powershell -ExecutionPolicy Bypass -File .\rollback.ps1
```

脚本会用 `.bak` 备份还原 `browser\omni.ja`。

## Firefox 更新后

Firefox 更新会覆盖 `omni.ja`、移除补丁。更新后重新运行 `install.ps1` 即可。若未来版本改变了 `GenAI.sys.mjs` 内部结构，请参照 [`modules_GenAI.sys.mjs`](modules_GenAI.sys.mjs) 中的两处修改重新打补丁。

## ⚠ 免责声明

本项目为独立项目，与 DeepSeek 或 Mozilla 无任何关联。补丁会修改 Firefox 自身的资源归档，仅供个人使用，风险自负。它<i>只是</i>在现有侧边栏中加载 DeepSeek 的网页应用。

## © 许可证

本仓库中的脚本与文档采用 [MIT License](LICENSE)。`modules_GenAI.sys.mjs` 源自 Mozilla Firefox 源码，遵循 [MPL-2.0](https://www.mozilla.org/en-US/MPL/2.0/) 许可证。
