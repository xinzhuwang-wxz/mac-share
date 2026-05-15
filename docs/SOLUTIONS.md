# 多用户远程终端共享 — 完整方案调研

## 需求场景

- **硬件**：一台 Mac mini 当工作站
- **用户 A**：MacBook，macOS
- **用户 B**：Windows 笔记本
- **需求**：两人都能远程用 Mac mini 的终端
- **降级标准**：可以只要终端，不奢求完整桌面远程

---

## 方案一：ttyd + tmux 🏆 最推荐

### 原理

```
浏览器 ──→ ttyd (WebSocket) ──→ tmux session
SSH    ──→ tmux attach ────────→ 同一个 session
```

[ttyd](https://github.com/tsl0922/ttyd)（~5k stars）是一个轻量 C 程序，把任意终端命令暴露为网页。配合 tmux，浏览器端和 SSH 端看到的是同一块屏幕。

### 优点

- Windows 完全不需要装任何东西——浏览器就是客户端
- MacBook 可以用原生 SSH + tmux，体验丝滑
- 两人可以同时看同一个终端，适合协作调试
- 部署极简：`brew install tmux ttyd` + 两行命令
- 支持 basic auth，防止裸奔公网

### 缺点

- 默认没有 TLS，密码明文传输（局域网内无所谓；公网建议 nginx 反代加 SSL）
- 浏览器端中文输入偶尔需要调
- 不适合跑 GUI 程序

### 适合你吗

**非常适合。** 你已经说了"标准可以降到只用终端"，这正是 ttyd + tmux 的甜蜜点。

---

## 方案二：原生 SSH + tmux

### 原理

纯 SSH 连接 + tmux 多路复用。两人各自 `ssh` 进入 Mac mini，然后 attach 到同一个 tmux session。

### 优点

- 零额外依赖——macOS 自带 sshd，`brew install tmux` 就齐了
- 最安全——SSH 加密，公钥认证
- 延迟最低

### 缺点

- Windows 同学需要装 SSH 客户端（Win10 1809+ 自带，或装 Windows Terminal）
- 两人看到的终端尺寸不一致时 tmux 会以最小尺寸为准

### 适合你吗

**适合作为备用/主力方案。** MacBook 端用这个最舒服。

---

## 方案三：Tailscale SSH

### 原理

[Tailscale](https://tailscale.com/)（~20k stars）是 WireGuard 之上的 mesh VPN。它的 SSH 功能让你无需打开 22 端口就能从任何装了 Tailscale 的设备 SSH 到 Mac mini。

### 优点

- 天然解决跨网络问题（你在咖啡厅，同学在宿舍，Mac mini 在家）
- 不需要公网 IP，不需要端口转发
- ACL 控制粒度细

### 缺点

- 依赖 Tailscale 服务（免费额度通常够用）
- 不影响终端本身——还是 SSH + tmux 那套
- Windows 同学需要装 Tailscale 客户端

### 适合你吗

**如果你和同学不在同一局域网，这是必选插件。** 可以和方案一/二组合。

---

## 方案四：tmate — 即时代码协作

### 原理

[tmate](https://tmate.io/)（~5k stars）是 tmux 的 fork。运行 `tmate` 后会生成一个 `ssh` 链接，任何人拿到链接就能加入你的 tmux session。数据通过 tmate.io 服务器中继。

### 优点

- 最简单——`tmate` 一条命令出链接，发过去就行
- 穿透 NAT 毫无压力
- 支持只读/读写模式

### 缺点

- 流量经过 tmate.io 第三方服务器
- 不适合长期运行（设计目标是临时结对编程）
- 不够私有

### 适合你吗

**不太适合。** 你们要长期共享工作站，不是临时结对。

---

## 方案五：code-server

### 原理

[code-server](https://github.com/coder/code-server)（~70k stars）是 VS Code 的 Web 版，跑在 Mac mini 上，浏览器打开就是完整 IDE。

### 优点

- 开发体验最好——VS Code 所有功能都在浏览器里
- 自带终端（在 IDE 里打开）

### 缺点

- 太重了——你不是要 IDE，你只是要终端
- 占内存，Mac mini 可能扛不住两人同时开
- 不适合跑 tmux/screen 这类终端复用工具的长 session

### 适合你吗

**不适合。** 大炮打蚊子。

---

## 方案六：VNC / Apple Remote Desktop

### 原理

图形桌面远程。Mac 用内置 Screen Sharing（VNC），Windows 用 RDP 客户端。

### 优点

- 能看到完整桌面

### 缺点

- 同一时间只能一个人操作（macOS 不允许多用户同时登录 GUI）
- 带宽消耗大
- Windows→Mac VNC 客户端体验一般

### 适合你吗

**不适合。** 你说了终端就行，且 macOS 桌面不支持多用户并发。

---

## 方案七：sshwifty — 另一个 Web SSH

### 原理

[sshwifty](https://github.com/nirui/sshwifty)（~2k stars）是 Go 写的 Web SSH 网关。浏览器打开后连接到目标机器。

### 优点

- Go 单二进制部署

### 缺点

- 功能不如 ttyd 成熟
- 社区小

---

## 总结矩阵

| 维度 | ttyd+tmux | SSH+tmux | Tailscale | tmate | code-server | VNC |
|------|:---------:|:--------:|:---------:|:-----:|:-----------:|:---:|
| Windows 友好 | 🟢 浏览器 | 🟡 需SSH客户端 | 🟡 需装App | 🟢 终端 | 🟢 浏览器 | 🔴 |
| 多用户同屏 | 🟢 | 🟢 | 🟡 各自session | 🟢 | 🔴 | 🔴 |
| 跨网络 | 🔴 需Tailscale | 🔴 需Tailscale | 🟢 | 🟢 | 🟡 | 🔴 |
| 部署难度 | 🟢 一条brew | 🟢 零部署 | 🟡 注册安装 | 🟢 | 🔴 重 | 🟡 |
| 安全性 | 🟡 basic auth | 🟢 SSH加密 | 🟢 | 🔴 第三方中继 | 🟡 | 🟡 |
| 长期运行 | 🟢 | 🟢 | 🟢 | 🔴 | 🟡 | 🟡 |

**推荐组合：ttyd + tmux（本工具默认）+ Tailscale（需要跨网时加上）**
