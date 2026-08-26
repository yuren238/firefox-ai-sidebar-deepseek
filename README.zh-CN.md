# <img src="deepseek.svg" width="64" height="64" /> DeepSeek for Firefox AI Sidebar

![Firefox](https://img.shields.io/badge/Firefox-ESR_153+-0095DD?logo=firefox-browsers&logoColor=white)
![Type](https://img.shields.io/badge/type-omni.ja_patch-orange)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)

[English](README.md)

这**不是**一个浏览器扩展，而是一个补丁：把 **DeepSeek** 注册成 Firefox **内置 AI 聊天机器人侧边栏**的一等服务商——就是自带 Anthropic Claude、ChatGPT、Google Gemini、Le Chat Mistral 的那个原生下拉框。

与侧边栏扩展不同，DeepSeek 出现在**原生服务商下拉框**里，可以随时与其他服务商互切、永不消失。没有额外的侧栏面板、没有额外的工具栏按钮——表现和一个内置服务商完全一样。

## 工作原理

Firefox 的界面代码打包在 `browser\omni.ja`（ZIP 归档）中。补丁做三件事：

- **补丁归档**：在 `modules/GenAI.sys.mjs` 硬编码的 `chatProviders` 映射中插入 `https://chat.deepseek.com/` 条目（id `deepseek`、名称 `DeepSeek`、鲸鱼图标），并追加进默认服务商列表；同时写入鲸鱼图标 `brands/deepseek.svg`。原版自动备份为 `browser\omni.ja.bak`。
- **写入偏好**：向 profile 的 `prefs.js` 写入用户级 `browser.ml.chat.providers`，防止 Mozilla Nimbus 实验把条目隐藏。
- **清启动缓存**：清空 profile 的 `startupCache`，确保补丁后的模块立即生效。

多 profile / 多安装的机器上，脚本会**按 Firefox 自己的解析方式**识别当前安装的默认 profile——注册表 `TaskBarIDs`（`HKCU\Software\Mozilla\Firefox\TaskBarIDs`）记录了每个安装目录对应的哈希，用它选中 `profiles.ini` 里的 `[Install<哈希>]` 段。该 profile 会被标为推荐项；你也可以在菜单里手动指定其他 profile 或选择全部。

## 环境要求

- Windows，Firefox ESR 153.1.x / 154.0.1+（凡保留 `chatProviders` 映射的版本均可）
- 管理员权限（需要写入 `Program Files`）
- Firefox 完全退出

## 安装

**方式 A —— 一键安装（推荐）**

在资源管理器里双击 `install-deepseek.bat`，UAC 弹窗点「是」，在 profile 菜单直接回车即可。bat 会自动请求管理员权限、检查 Firefox 是否关闭、调用补丁器并显示结果。

**方式 B —— 命令行**

```powershell
# 管理员 PowerShell，Firefox 已关闭：
powershell -ExecutionPolicy Bypass -File .\Add-DeepSeekToFirefox.ps1
```

脚本直接就地打开已安装的 `browser\omni.ja` 打补丁，不携带任何二进制。幂等设计——每次 Firefox 更新后重跑即可。

## 使用

1. 启动 Firefox，先在普通标签页登录一次 `chat.deepseek.com`（侧边栏共享登录状态）。
2. 打开 AI 聊天机器人侧边栏：按 _`Ctrl+Alt+X`_，或点击侧边栏按钮选择 _AI 聊天机器人_。
3. 点开顶部服务商下拉框——**DeepSeek** 已与 Claude、ChatGPT、Gemini、Le Chat Mistral 并列。随意切换，它不会消失。

> **注意**：右键"生成页面摘要"只对 Claude 和 ChatGPT 支持自动填入与自动提交（Mozilla 硬编码）。DeepSeek 网页不识别 `?q=` 提示词参数，需要手动粘贴。

## 回滚

```powershell
# 管理员 PowerShell，Firefox 已关闭：
powershell -ExecutionPolicy Bypass -File .\rollback.ps1
```

脚本会用 `.bak` 备份还原 `browser\omni.ja`。

## Firefox 更新后

Firefox 更新会覆盖 `omni.ja`、移除补丁。更新后重跑 `install-deepseek.bat` 即可。若未来版本把 `GenAI.sys.mjs` 改得面目全非，脚本会提示找不到锚点。

## ⚠ 免责声明

本项目为独立项目，与 DeepSeek 或 Mozilla 无任何关联。补丁会修改 Firefox 自身的资源归档，仅供个人使用，风险自负。它<i>只是</i>在现有侧边栏中加载 DeepSeek 的网页应用。

## © 许可证

本仓库中的脚本与文档采用 [MIT License](LICENSE)。被打补丁的 `GenAI.sys.mjs` 源自 Mozilla Firefox 源码，遵循 [MPL-2.0](https://www.mozilla.org/en-US/MPL/2.0/) 许可证。
