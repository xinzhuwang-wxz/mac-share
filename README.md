# mac-share

Mac mini 一键变多人共享终端 — 浏览器或 SSH 都能同时连，同一屏幕一起敲。

## 安装（Mac mini 上跑一次）

```bash
curl -fsSL https://raw.githubusercontent.com/xinzhuwang-wxz/mac-share/main/setup.sh | bash
```

装完自带 `mac-share` 命令：

```bash
mac-share start      # 启动
mac-share connect    # 看连接方式
mac-share status     # 看状态
mac-share stop       # 停止
```

## 连接

**TL;DR: 局域网能通用局域网 IP，不通用 Tailscale IP。**

```
┌──────────┐                    ┌──────────────────────┐
│ Windows  │──── 浏览器 ───────→│                      │
└──────────┘                    │   Mac mini            │
                      SSH       │   tmux ← ttyd :7681   │
┌──────────┐                    │                      │
│ MacBook  │──── SSH/浏览器 ───→│                      │
└──────────┘                    └──────────────────────┘
```

### 局域网内

```bash
# MacBook
ssh <用户名>@<局域网IP>
tmux attach -t mac-share

# Windows — 浏览器打开
http://<局域网IP>:7681
```

### 跨子网 / 同一 WiFi 不通

> ⚠️ 校园网/公司网常见：WiFi 名一样，但设备被隔离在不同 VLAN，IP 互相 Ping 不通。下面方案直接打隧道绕过。

**Mac mini 上（装好了只需登录一次）：**

```bash
tailscale up          # 浏览器弹窗，GitHub/Google 登录
mac-share tailscale   # 显示 Tailscale IP
```

**MacBook 上：**

```bash
brew install tailscale && tailscale up   # 同一账号登录
ssh <用户名>@<Tailscale-IP>
tmux attach -t mac-share
```

**Windows 上：**

去 [tailscale.com/download](https://tailscale.com/download) 装客户端，同一账号登录。浏览器打开 `http://<Tailscale-IP>:7681`。

Tailscale IP 是固定的，以后不管在哪都能用同一个 IP 连。

## 多设备连接图

```
                  Tailscale VPN ───────────────────────┐
                  │                                    │
  ┌──────────┐   │   ┌──────────┐   ┌──────────┐     │
  │ MacBook  │───┼───│ Mac mini │───│ Windows  │     │
  │10.x.y.z  │   │   │100.a.b.c │   │100.d.e.f │     │
  └──────────┘   │   └──────────┘   └──────────┘     │
                  │    ttyd :7681                      │
                  └────────────────────────────────────┘
```

## 防火墙

Mac mini 防火墙可能拦截 7681 端口。连不上时：

```bash
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /opt/homebrew/bin/ttyd
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /opt/homebrew/bin/ttyd
```

或者直接关掉防火墙（局域网内安全）。

## 密码（可选）

默认无需密码。如需保护：

```bash
TTYD_USER=admin TTYD_PASS=xxxx mac-share start
```

## 常见问题

**同一 WiFi 但连不上？** VLAN 隔离。用 Tailscale，见上方跨子网部分。

**SSH 连不上？** 检查 Mac mini「系统设置 → 通用 → 共享 → 远程登录」。

**浏览器打不开？** 先 Ping IP。通则查防火墙。不通则用 Tailscale。

**Windows SSH 后报 `tmux: command not found`？** tmux 在 Mac mini 上，登录后敲 `tmux attach` 即可。

## 许可

MIT
