# mac-share

一键将 Mac mini 变成可共享终端 —— 支持局域网和跨子网（Tailscale）。

## 安装

在 Mac mini 上：

```bash
curl -fsSL https://raw.githubusercontent.com/xinzhuwang-wxz/mac-share/main/setup.sh | bash
```

## 使用

```bash
mac-share start        # 启动共享终端
mac-share connect      # 查看连接信息
mac-share tailscale    # 查看 Tailscale IP
mac-share stop         # 停止服务
mac-share status       # 查看状态
```

## 客户端连接

三步走：

### 1. 客户端装 Tailscale（一次性）

```bash
# Mac / Linux
brew install tailscale

# Windows
# https://tailscale.com/download
```

### 2. 登录（同一账号）

```bash
tailscale up    # 弹出浏览器，用跟 Mac mini 同一个账号登录
```

### 3. 连接

在 **Mac mini** 上运行 `mac-share connect`，拿到地址后在**客户端**连接：

```bash
ssh jonah@100.x.x.x       # 终端连接（换成 Mac mini 用户名和 IP）
http://100.x.x.x:7681     # 浏览器终端
```

> **同一 WiFi** 下也能直接用局域网 IP，不走 Tailscale。

## 原理

| 组件 | 作用 |
|------|------|
| `tmux` | 所有用户共享同一个终端会话 |
| `ttyd` | Web 终端（任何设备浏览器可访问） |
| `Tailscale` | 跨子网打通，解决校园网/公司网 VLAN 隔离 |

Tailscale 以系统 LaunchDaemon 运行，不依赖用户 GUI 会话，headless Mac mini 也能稳定工作。
