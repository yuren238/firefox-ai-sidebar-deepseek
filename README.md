# Firefox AI 侧边栏 DeepSeek 服务商补丁

给 Firefox ESR 153（`C:\Program Files\Mozilla Firefox`）内置 AI 聊天机器人侧边栏
永久添加 **DeepSeek**（https://chat.deepseek.com/ ）服务商条目。

## 原理

Firefox 的界面代码打包在 `browser\omni.ja`（ZIP 格式）里。本补丁修改其中
`modules/GenAI.sys.mjs` 的两处：

1. `chatProviders` Map 中新增条目（位于 Le Chat Mistral 之后、localhost 之前）：

```js
[
  "https://chat.deepseek.com/",
  {
    iconUrl: "chrome://browser/content/genai/assets/brands/deepseek.svg",
    id: "deepseek",
    maxLength: 12000,
    name: "DeepSeek",
  },
],
```

2. 默认服务商列表 fallback 增加 `deepseek`：

```js
"claude,chatgpt,copilot,gemini,lechat,deepseek",
```

同时在 `chrome/browser/content/browser/genai/assets/brands/deepseek.svg`
放入官方鲸鱼图标（Simple Icons 路径，DeepSeek 蓝 #4D6BFE）。

另外向 Firefox profile 的 `prefs.js` 写入用户级偏好（防止 Nimbus 实验通过默认分支偏好覆盖服务商列表）：

```js
user_pref("browser.ml.chat.providers", "claude,chatgpt,gemini,lechat,deepseek");
```

## 文件清单

| 文件 | 说明 |
|---|---|
| `omni-patched.ja` | 补丁版 omni.ja（54770491 字节，5312 条目） |
| `modules_GenAI.sys.mjs` | 修改后的模块源码（供核对/重打补丁） |
| `deepseek.svg` | DeepSeek 图标 |
| `install.ps1` | 安装脚本：备份原文件 → 替换 → 写偏好（需管理员 + Firefox 已关闭） |
| `rollback.ps1` | 回滚脚本：用 `omni.ja.bak` 还原 |

## 使用

```powershell
# 安装（管理员 PowerShell，Firefox 需完全退出）
powershell -ExecutionPolicy Bypass -File .\install.ps1

# 回滚
powershell -ExecutionPolicy Bypass -File .\rollback.ps1
```

脚本自动探测默认 Firefox profile，无需修改任何路径。

## 注意

- **Firefox 更新会覆盖 `omni.ja`**，更新后重新运行 `install.ps1` 即可；
  若更新后 `GenAI.sys.mjs` 内部结构变化较大，则需参照本仓库源码重新打补丁。
- 已知限制：DeepSeek 网页不识别 `?q=` 参数，右键"生成页面摘要"不会自动
  填入发送，需手动粘贴；自动提交仅对 Claude/ChatGPT 生效（Mozilla 硬编码）。
- 首次安装后如侧边栏无变化，清空
  `%LOCALAPPDATA%\Mozilla\Firefox\Profiles\<profile>\startupCache` 再启动
  （JS 启动缓存可能未随 omni.ja 替换失效）。

## 隐私说明

本仓库不含任何个人数据：`omni-patched.ja` 为 Mozilla 官方原版归档外加两个
干净条目（修改源码与图标均在仓库内可核对）；脚本通过环境变量与 Profiles
目录自动探测 profile 路径，无硬编码用户名或机器信息。
