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

**其他设备**需要先安装 Tailscale 并登录同一账号：

```bash
# Mac / Linux
brew install tailscale && tailscale up

# Windows
# https://tailscale.com/download
```

Tailscale 登录后，用 `mac-share connect` 显示的地址连接：

```bash
ssh yourname@100.x.x.x    # 终端连接
http://100.x.x.x:7681     # 浏览器终端
```

## 原理

| 组件 | 作用 |
|------|------|
| `tmux` | 所有用户共享同一个终端会话 |
| `ttyd` | Web 终端（任何设备浏览器可访问） |
| `Tailscale` | 跨子网打通，解决校园网/公司网 VLAN 隔离 |

Tailscale 以系统 LaunchDaemon 运行，不依赖用户 GUI 会话，headless Mac mini 也能稳定工作。
