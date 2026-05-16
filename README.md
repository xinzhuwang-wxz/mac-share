# mac-share

一键将 Mac mini 变成共享终端 —— 局域网直接用，跨子网走 Tailscale。

---

## 各设备操作

### Mac mini（服务端）

```bash
curl -fsSL https://raw.githubusercontent.com/xinzhuwang-wxz/mac-share/main/setup.sh | bash
```

装完自动完成：
- tmux、ttyd、Tailscale 安装
- Tailscale 以系统 LaunchDaemon 运行（不依赖用户登录）
- SSH 远程登录开启
- `mac-share` 命令安装

然后登录 Tailscale：

```bash
tailscale up    # 弹浏览器，登录一次
```

启动服务：

```bash
mac-share start
```

---

### 客户端

> **你自己**的各设备 — 装 Tailscale 登录**同一个账号**即可。
> **分享给其他人** — 各自用自己账号，在 Mac mini 的 [Tailscale 控制台](https://login.tailscale.com/admin/machines) 把节点 Share 给他们就行，不用共享账号。

```bash
# MacBook / 其他 Mac
brew install tailscale && tailscale up

# Windows
https://tailscale.com/download
```

登录后在客户端连接：

```bash
ssh jonah@<Tailscale IP>       # 终端
http://<Tailscale IP>:7681     # 浏览器
```

> Mac mini 上跑 `mac-share connect` 能看到 IP。同一 WiFi 下用局域网 IP 也行，不走 Tailscale。

---

## mac-share 命令

```bash
mac-share start        # 启动
mac-share stop         # 停止
mac-share status       # 状态
mac-share connect      # 查看连接地址
mac-share tailscale    # Tailscale IP
```

## 原理

| 组件 | 作用 |
|------|------|
| tmux | 多用户共享同一终端会话 |
| ttyd | 浏览器终端 |
| Tailscale | 跨子网打通 |

Tailscale 以系统 LaunchDaemon 运行，headless Mac mini 也能稳定工作，不依赖 GUI 会话。
