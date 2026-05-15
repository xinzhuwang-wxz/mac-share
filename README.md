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
curl -fsSL https://raw.githubusercontent.com/<你的用户名>/mac-share/main/setup.sh | bash
```

或者克隆后手动运行：

```bash
git clone https://github.com/<你的用户名>/mac-share.git
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
tmux -f ~/.tmux.macshare.conf attach -t mac-share
```

### 同学的 Windows

**方式一（浏览器，最省事）：**
打开 `http://<Mac-mini-IP>:7681`，用户名 `admin`，密码 `macshare`

**方式二（终端，Win10+ 自带）：**
```powershell
ssh <用户名>@<Mac-mini-IP>
tmux -f ~/.tmux.macshare.conf attach -t mac-share
```

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

## 修改默认密码

```bash
# 启动时指定
TTYD_USER=myuser TTYD_PASS=mypass mac-share start

# 或者写进 ~/.zshrc
export TTYD_USER=myuser
export TTYD_PASS=mypass
```

## 常见问题

**Q: Windows 同学的浏览器连不上？**
A: 检查 Mac mini 防火墙是否放行端口 7681（系统设置 → 网络 → 防火墙）。

**Q: 不在同一局域网？**
A: 在 Mac mini 和两台电脑上都装 [Tailscale](https://tailscale.com)，免费。然后 IP 换成 Tailscale IP 即可。

**Q: 想让两人各自独立终端（不同时看一个屏幕）？**
A: 各自 `tmux new-session -t mysession` 就行，不加 `-t mac-share`。

## 许可

MIT
