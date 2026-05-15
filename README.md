# mac-share — 把 Mac mini 变成多人共享工作站

## 一句话

在 Mac mini 上跑一个脚本，**你（MacBook）和同学（Windows）就能同时用它的终端**——浏览器或 SSH 都行。

## 怎么做到的

```
┌─────────────┐    浏览器      ┌─────────────────────────────┐
│ Windows 同学 │──────────────→│                             │
└─────────────┘               │   Mac mini                   │
                    SSH       │   ┌─────┐  ┌──────────────┐  │
┌─────────────┐               │   │tmux │←─│    ttyd      │  │
│ 你的 MacBook │──────────────→│   │共享  │  │  (Web终端)   │  │
└─────────────┘    SSH/浏览器  │   │session│  │  端口 7681  │  │
                              │   └─────┘  └──────────────┘  │
                              └─────────────────────────────┘
```

- **tmux**：终端"房间"，两人进去看到同一个屏幕，都能敲键盘
- **ttyd**：把 tmux 变成网页，浏览器打开就能用（主要给 Windows 同学省事）
- **SSH**：你 MacBook 原生的连接方式，更快更稳

## 安装（在 Mac mini 上）

```bash
curl -fsSL https://raw.githubusercontent.com/xinzhuwang-wxz/mac-share/main/setup.sh | bash
```

或者克隆后手动运行：

```bash
git clone https://github.com/xinzhuwang-wxz/mac-share.git
cd mac-share
bash setup.sh
```

脚本会：
- 安装 tmux 和 ttyd
- 开启 SSH 远程登录
- 安装 `mac-share` 命令行工具

## 使用

```bash
mac-share start      # 启动共享终端
mac-share connect    # 查看连接方式（发给同学）
mac-share status     # 看谁在线
mac-share stop       # 停止
mac-share attach     # 本地直接进入 tmux
```

### 你的 MacBook

```bash
ssh <用户名>@<Mac-mini-IP>
tmux attach -t mac-share
```

### 同学的 Windows

**推荐（浏览器最省事）：**
打开 `http://<Mac-mini-IP>:7681`，直接就能用（默认无需密码）

**也可 SSH（Win10+ 自带终端）：**
```powershell
ssh <用户名>@<Mac-mini-IP>
```
登录后在 Mac mini 上执行 `tmux attach -t mac-share`

## 方案对比

| 方案 | 跨平台 | 多用户同屏 | 零客户端 | 安全性 | 推荐场景 |
|------|:------:|:----------:|:--------:|:------:|----------|
| **ttyd + tmux** (本工具) | ✅ | ✅ | ✅ 浏览器 | ⭐⭐ | 🏆 最推荐 |
| SSH + tmux | ✅ | ✅ | ⚠️ Win需SSH | ⭐⭐⭐ | 局域网首选 |
| Tailscale SSH | ✅ | ⚠️ 各自session | ❌ 需App | ⭐⭐⭐ | 跨网络 |
| tmate | ✅ | ✅ | ✅ | ⭐ 中继 | 临时分享 |
| code-server | ✅ | ❌ 各自workspace | ✅ | ⭐⭐ | 写代码为主 |
| VNC/RDP | ⚠️ | ❌ 单人 | ❌ | ⭐⭐ | 要GUI时 |

详细对比见 → [docs/SOLUTIONS.md](docs/SOLUTIONS.md)

## 设置密码（可选）

默认**无需密码**——局域网内直接打开就能用。如果担心安全，可以加 basic auth：

```bash
# 临时指定
TTYD_USER=admin TTYD_PASS=mypass mac-share start

# 永久写进 ~/.zshrc
export TTYD_USER=admin
export TTYD_PASS=mypass
```

## ⚠️ 部署前必查

**防火墙：** Mac mini 的防火墙默认可能拦截 7681 端口，导致同学的浏览器连不上。部署后在 Mac mini 上：

```bash
# 检查防火墙状态
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# 如果开启了防火墙，放行 ttyd
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /opt/homebrew/bin/ttyd
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /opt/homebrew/bin/ttyd
```

或者直接去「系统设置 → 网络 → 防火墙 → 选项」关掉，局域网内一般不需要。

**SSH：** `setup.sh` 会自动开启。如果失败，手动去「系统设置 → 通用 → 共享 → 远程登录」打开。

## 常见问题

**Q: 同学的浏览器连不上？**
A: ① 确认两台电脑连的同一个 WiFi/路由器 ② 检查 Mac mini 防火墙（见上方）③ Ping 一下 IP 看通不通。

**Q: SSH 连不上？**
A: 检查「系统设置 → 通用 → 共享 → 远程登录」是否开启。

**Q: Windows 同学用 SSH 后 `tmux: command not found`？**
A: `tmux` 跑在 Mac mini 上，不是 Windows 上。SSH 登录 Mac mini 后执行 `tmux attach -t mac-share` 即可。如果提示找不到 tmux，说明 Mac mini 没装——重跑 `setup.sh`。

**Q: 想让两人各自独立终端（不同时看一个屏幕）？**
A: 各自 `tmux new-session -s mysession` 就行，不加 `-t mac-share`。

**Q: 不在同一局域网？**
A: 在 Mac mini 和两台电脑上都装 [Tailscale](https://tailscale.com)，免费。然后 IP 换成 Tailscale IP。

## 许可

MIT
