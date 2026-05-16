# mac-share

一键将 Mac mini 变成共享终端 —— 局域网直接用，跨子网走 Tailscale。

---

## 各设备操作

### Mac mini（服务端）

```bash
curl -fsSL https://raw.githubusercontent.com/xinzhuwang-wxz/mac-share/main/setup.sh | bash
```

装完自动完成：tmux / ttyd / Tailscale / SSH / `mac-share` 命令。

然后：

```bash
tailscale up        # 弹浏览器登录
mac-share start     # 启动共享终端
```

---

### 客户端

打开 [Tailscale 控制台](https://login.tailscale.com/admin/machines)，下载对应设备的 Tailscale，用 **Mac mini 同一个账号**登录。

登录后就能连了：

```bash
ssh jonah@<IP>          # 终端
http://<IP>:7681        # 浏览器
```

> Mac mini 上跑 `mac-share connect` 能看到 IP。同一 WiFi 下用局域网 IP 也行。

---

### 分享给其他人

各自用自己的 Tailscale 账号。Mac mini 的拥有者在 [控制台](https://login.tailscale.com/admin/machines) 把节点 Share 给他们即可，不用共享账号。

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

Tailscale 以系统 LaunchDaemon 运行，不依赖 GUI 会话。
