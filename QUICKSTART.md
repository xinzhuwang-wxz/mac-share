# 快速上手 — 三端操作指南

---

## 角色 A：你在 Mac mini 上（管理员，做一次就行）

### 第一步：拿到脚本

Mac mini 开机，打开终端，运行：

```bash
curl -fsSL https://raw.githubusercontent.com/xinzhuwang-wxz/mac-share/main/setup.sh | bash
```

> 如果没装过 Homebrew，脚本会自动装。需要你输入一次 Mac 登录密码（sudo）。

脚本会自动：
- 安装 `tmux` 和 `ttyd`
- 开启 SSH 远程登录
- 装好 `mac-share` 命令

### 第二步：启动共享终端

```bash
mac-share start
```

会输出类似：

```
═══════════════════════════════════════════════
  Mac mini 共享终端已就绪
═══════════════════════════════════════════════

  🌐 Web 终端 (浏览器打开):
     http://192.168.1.100:7681
     (无需密码，直接打开即用)

  💻 MacBook (SSH):
     ssh bamboo@192.168.1.100
     然后: tmux attach -t mac-share

  🪟 Windows 同学 (推荐浏览器):
     http://192.168.1.100:7681
═══════════════════════════════════════════════
```

**记住那个 IP（比如 `192.168.1.100`）**，发给同学。

### 第三步（重要）：检查防火墙

如果同学的浏览器连不上，大概率是 Mac mini 防火墙拦了。在 Mac mini 终端运行：

```bash
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /opt/homebrew/bin/ttyd
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /opt/homebrew/bin/ttyd
```

或者直接去「系统设置 → 网络 → 防火墙」关掉（局域网内安全，关掉最省事）。

### 日常使用

```bash
mac-share status     # 看谁在线
mac-share connect    # 重新显示连接方式
mac-share stop       # 不用时停掉
mac-share start      # 再次启动
```

> ⚠️ Mac mini 别关机/睡眠，否则服务就断了。去「系统设置 → 电池 → 电源适配器」把「防止自动睡眠」打开。

---

## 角色 B：你 — MacBook 连接 Mac mini

### 方式一：SSH（推荐，最快）

```bash
ssh bamboo@192.168.1.100     # 替换成 Mac mini 的 IP 和用户名
tmux attach -t mac-share      # 进入共享终端
```

> 第一次 SSH 会问 `yes/no`，输入 `yes` 回车。

断开时按 `Ctrl+B` 然后 `D`（先按 Ctrl+B 松开，再按 D）。终端里的东西继续跑，下次 `tmux attach` 回来接着看。

### 方式二：浏览器（和 Windows 同学一样）

打开 `http://192.168.1.100:7681`，直接在浏览器里操作。

### tmux 快捷键速查

| 操作 | 按键 |
|------|------|
| 断开（后台继续跑） | `Ctrl+B` 然后 `D` |
| 新建窗口 | `Ctrl+B` 然后 `C` |
| 切换窗口 | `Ctrl+B` 然后 `N`（下一个）/ `P`（上一个） |
| 滚屏翻看历史 | `Ctrl+B` 然后 `[`，用方向键翻，`Q` 退出 |

---

## 角色 C：同学 — Windows 连接 Mac mini

### 方式一：浏览器（最推荐，不用装任何东西）

1. 打开 Chrome / Edge / Firefox
2. 地址栏输入 `http://192.168.1.100:7681`（IP 换成你给的）
3. 直接就能看到终端，可以打字

> 如果页面打不开：确认连的是**同一个 WiFi**，IP 没输错。还是不行让 Mac mini 那边查防火墙。

### 方式二：SSH（Windows 10/11 自带）

1. 按 `Win+R`，输入 `cmd` 回车
2. 在黑色窗口输入：
   ```
   ssh bamboo@192.168.1.100
   ```
3. 登录成功后输入：
   ```
   tmux attach -t mac-share
   ```

> 提示 `tmux: command not found`？这是正常的——tmux 在 Mac mini 上，不在你 Windows 上。SSH 登录后就已经在 Mac mini 的终端里了，直接敲 `tmux attach` 即可。

---

## 常见问题

| 问题 | 解决 |
|------|------|
| 浏览器打不开 | ① 确认同 WiFi ② Ping IP ③ 查 Mac mini 防火墙 |
| SSH 连不上 | Mac mini 去「系统设置 → 通用 → 共享 → 远程登录」打开 |
| `tmux: command not found`（SSH 后） | Mac mini 没装 tmux — 重跑 `setup.sh` |
| Mac mini 休眠了 | 系统设置 → 电池 → 电源适配器 → 防止自动睡眠 |
| 想让两人各用各的终端 | 各自 `tmux new-session -s 自己的名字` |
| 想加密码 | `TTYD_USER=admin TTYD_PASS=123456 mac-share start` |
| 不在同一个 WiFi | 三人装 [Tailscale](https://tailscale.com)，IP 换成 Tailscale 的 |
