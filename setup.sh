#!/usr/bin/env bash
# ============================================================
#  mac-share — Mac mini 一键变共享终端
#  curl -fsSL https://raw.githubusercontent.com/xinzhuwang-wxz/mac-share/main/setup.sh | bash
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
die()  { echo -e "${RED}[✗]${NC} $*"; exit 1; }
info() { echo -e "${BLUE}[i]${NC} $*"; }

clear
echo "════════════════════════════════════════════════"
echo "  mac-share 安装程序"
echo "════════════════════════════════════════════════"
echo ""

[ "$(uname -s)" = "Darwin" ] || die "请在 Mac 上运行本脚本"

# ─── Homebrew ─────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
    info "安装 Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$($(brew --prefix)/bin/brew shellenv 2>/dev/null || true)"

# ─── 安装软件 ─────────────────────────────────────────────
echo "── 安装软件 ────────────────────────────────"

pkg_install() {
    if brew list "$1" &>/dev/null; then
        ok "$1 已安装"
        return 0
    fi
    info "安装 $1..."
    brew install "$1" || warn "$1 安装失败，继续..."
}

pkg_install tmux
pkg_install ttyd
pkg_install tailscale

# ─── Tailscale 服务（系统 LaunchDaemon，不受 GUI 会话影响）──
echo ""
echo "── Tailscale ────────────────────────────────"

TAILSCALED="/opt/homebrew/bin/tailscaled"
PLIST="/Library/LaunchDaemons/com.tailscale.tailscaled.plist"

setup_tailscale_daemon() {
    # 彻底清旧进程和旧 Daemon（不管什么方式跑的）
    info "清理旧 Tailscale 进程..."
    for domain in system "gui/$(id -u)"; do
        sudo launchctl bootout "$domain/com.tailscale.tailscaled" 2>/dev/null || true
    done
    brew services stop tailscale 2>/dev/null || true
    sudo pkill -9 tailscaled 2>/dev/null || true
    sleep 1

    # 写入系统 LaunchDaemon，显式指定 socket 路径
    info "安装 Tailscale 系统服务..."
    sudo tee "$PLIST" > /dev/null << PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.tailscale.tailscaled</string>
    <key>ProgramArguments</key>
    <array>
        <string>$TAILSCALED</string>
        <string>--socket=/var/run/tailscaled.socket</string>
        <string>--statedir=/var/lib/tailscale</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/tailscaled.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/tailscaled.err</string>
</dict>
</plist>
PLISTEOF

    sudo mkdir -p /var/lib/tailscale
    sudo launchctl load -w "$PLIST"

    sleep 3
    if pgrep -x tailscaled &>/dev/null; then
        ok "Tailscale 服务已启动（系统级）"
    else
        warn "Tailscale 启动失败，查看日志:"
        echo "  sudo cat /var/log/tailscaled.err"
        echo "  sudo tail -20 /var/log/tailscaled.log"
    fi
}

setup_tailscale_daemon

# 登录状态
if tailscale status &>/dev/null 2>&1; then
    TS_IP=$(tailscale ip -4 2>/dev/null || echo "")
    [ -n "$TS_IP" ] && ok "Tailscale 已登录: $TS_IP"
else
    warn "Tailscale 未登录，安装后运行: tailscale up"
fi

# ─── SSH 远程登录 ─────────────────────────────────────────
echo ""
echo "── SSH ──────────────────────────────────────"

if systemsetup -getremotelogin 2>/dev/null | grep -q "On"; then
    ok "SSH 远程登录已开启"
else
    info "开启 SSH 远程登录..."
    sudo systemsetup -setremotelogin on 2>/dev/null && ok "SSH 已开启" || {
        # 备选方案：直接加载 sshd launchd
        info "尝试备选方案..."
        sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist 2>/dev/null && \
            ok "SSH 已通过 launchctl 开启" || \
            warn "无法自动开启 SSH，请手动：系统设置 → 通用 → 共享 → 远程登录"
    }
fi

# ─── CLI 工具 ─────────────────────────────────────────────
echo ""
echo "── CLI ─────────────────────────────────────"

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

cat > "$BIN_DIR/mac-share" << 'SCRIPTEOF'
#!/usr/bin/env bash
set -euo pipefail

TMUX_SESSION="mac-share"
TTYD_PORT="${TTYD_PORT:-7681}"
CONF="$HOME/.tmux.macshare.conf"

_lan_ip() {
    ifconfig en0 2>/dev/null | awk '/inet /{print $2;exit}' || \
    ifconfig en1 2>/dev/null | awk '/inet /{print $2;exit}' || \
    echo "未知"
}

_ts_ip() {
    command -v tailscale &>/dev/null || { echo ""; return; }
    tailscale ip -4 2>/dev/null || echo ""
}

cmd_start() {
    mkdir -p "$HOME/.mac-share"

    if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        tmux -f "$CONF" new-session -d -s "$TMUX_SESSION"
        echo "创建 tmux session: $TMUX_SESSION"
    else
        echo "tmux session 已存在: $TMUX_SESSION"
    fi

    if ! pgrep -f "ttyd.*$TTYD_PORT" &>/dev/null; then
        echo "启动 ttyd 端口 $TTYD_PORT ..."
        nohup ttyd -p "$TTYD_PORT" -W \
            ${TTYD_USER:+ -c "$TTYD_USER:$TTYD_PASS"} \
            -t "titleFixed=mac-share" \
            tmux -f "$CONF" attach -t "$TMUX_SESSION" \
            > "$HOME/.mac-share/ttyd.log" 2>&1 &
        sleep 2
        pgrep -f "ttyd.*$TTYD_PORT" &>/dev/null && echo "ttyd 启动成功" || {
            echo "ttyd 启动失败，查看: $HOME/.mac-share/ttyd.log"
            exit 1
        }
    else
        echo "ttyd 已在运行 (端口 $TTYD_PORT)"
    fi

    LAN=$(_lan_ip)
    TS=$(_ts_ip)
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  共享终端已就绪"
    echo "═══════════════════════════════════════════════"
    [ -n "$TS" ] && echo "  Tailscale:  ssh $(whoami)@$TS\n              http://$TS:$TTYD_PORT"
    [ -n "$LAN" ] && [ "$LAN" != "未知" ] && echo "  局域网:     ssh $(whoami)@$LAN\n              http://$LAN:$TTYD_PORT"
    [ -z "$TS" ] && echo "  ⚠️  建议安装后运行 tailscale up（跨子网）"
    echo "═══════════════════════════════════════════════"
}

cmd_stop() {
    pkill -f "ttyd.*$TTYD_PORT" 2>/dev/null && echo "已停止 ttyd" || true
    tmux kill-session -t "$TMUX_SESSION" 2>/dev/null && echo "已停止 tmux" || true
}

cmd_status() {
    echo "════════ mac-share 状态 ════════"
    echo "Hostname:  $(hostname)"
    echo "局域网 IP: $(_lan_ip)"
    TS=$(_ts_ip)
    [ -n "$TS" ] && echo "Tailscale: $TS"
    echo ""
    tmux has-session -t "$TMUX_SESSION" 2>/dev/null && echo "tmux: ✅ 运行中" || echo "tmux: ❌ 未运行"
    pgrep -f "ttyd.*$TTYD_PORT" &>/dev/null && echo "ttyd: ✅ 运行中 (端口 $TTYD_PORT)" || echo "ttyd: ❌ 未运行"
    echo "════════════════════════════════"
}

cmd_connect() {
    LAN=$(_lan_ip)
    TS=$(_ts_ip)
    [ -n "$TS" ] && echo -e "\n═ Tailscale ════════════\n  ssh $(whoami)@$TS\n  http://$TS:$TTYD_PORT"
    echo -e "\n═ 局域网 ═══════════════\n  ssh $(whoami)@$LAN\n  http://$LAN:$TTYD_PORT"
    echo -e "\n═ 快捷键 ═══════════════\n  Ctrl+B D  断开会话\n  Ctrl+B C  新建窗口\n  Ctrl+B [  滚屏 (q 退出)"
}

mkdir -p "$HOME/.mac-share"
case "${1:-}" in
    start)     cmd_start ;;
    stop)      cmd_stop ;;
    status)    cmd_status ;;
    connect)   cmd_connect ;;
    tailscale) _ts_ip ;;
    *) echo "用法: mac-share {start|stop|status|connect|tailscale}" ;;
esac
SCRIPTEOF

chmod +x "$BIN_DIR/mac-share"
ok "CLI 已安装: mac-share"

# ─── PATH ─────────────────────────────────────────────────
for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
    [ -f "$rc" ] && ! grep -q "$BIN_DIR" "$rc" 2>/dev/null && \
        echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$rc"
done
export PATH="$BIN_DIR:$PATH"

# ─── tmux 配置 ────────────────────────────────────────────
cat > "$HOME/.tmux.macshare.conf" << 'TMUXEOF'
set -g default-terminal "screen-256color"
set -g mouse on
set -g history-limit 50000
set -g status-style bg=colour236,fg=white
set -g status-left '#[fg=green]#S '
set -g status-right '#[fg=yellow]%Y-%m-%d %H:%M '
setw -g window-status-format '#[fg=white]#I #W'
setw -g window-status-current-format '#[fg=cyan,bold]#I #W'
TMUXEOF

# ─── 完成 ─────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════"
echo "  安装完成"
echo "════════════════════════════════════════════════════════"
echo ""
echo "  Mac mini（本机）:"
echo "    tailscale up             # 登录一次"
echo "    mac-share start          # 启动共享终端"
echo ""
echo "  其他设备连入:"
echo "    （自己用）同一账号登录 Tailscale"
echo "    （分享他人）各自账号，Mac mini 控制台 Share 节点"
echo "    2. mac-share connect                        # 拿地址"
echo "    3. ssh <user>@<IP>                          # 终端连接"
echo ""
echo "  Windows: https://tailscale.com/download"
echo "════════════════════════════════════════════════════════"
