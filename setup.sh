#!/usr/bin/env bash
# ============================================================
#  mac-share — Mac mini 一键变多人共享终端
#  curl -fsSL https://raw.githubusercontent.com/xinzhuwang-wxz/mac-share/main/setup.sh | bash
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; exit 1; }
info() { echo -e "${BLUE}[i]${NC} $*"; }

# ─── 环境检查 ────────────────────────────────────────────
clear
echo "════════════════════════════════════════════════"
echo "  mac-share 安装程序"
echo "════════════════════════════════════════════════"
echo ""

[ "$(uname -s)" = "Darwin" ] || err "请在 Mac 上运行本脚本"

# Homebrew
if ! command -v brew &>/dev/null; then
    info "安装 Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$($(brew --prefix)/bin/brew shellenv 2>/dev/null || true)"

# ─── 安装软件 ────────────────────────────────────────────
echo ""
echo "── 安装软件 ────────────────────────────────"

install_pkg() {
    if brew list "$1" &>/dev/null; then
        log "$1 已安装"
    else
        info "安装 $1..."
        brew install "$1" >> /tmp/mac-share-install.log 2>&1 && log "$1 安装完成" || warn "$1 安装失败"
    fi
}

install_pkg tmux
install_pkg ttyd
install_pkg tailscale

# 启动 Tailscale 后台服务
if command -v tailscale &>/dev/null; then
    info "启动 Tailscale 服务..."
    brew services start tailscale >> /tmp/mac-share-install.log 2>&1 || true
    sleep 2

    if tailscale status &>/dev/null 2>&1; then
        TS_IP=$(tailscale ip -4 2>/dev/null || echo "")
        [ -n "$TS_IP" ] && log "Tailscale 已登录: $TS_IP"
    else
        warn "Tailscale 未登录，稍后运行: tailscale up"
    fi
fi

# ─── 配置 SSH ────────────────────────────────────────────
echo ""
echo "── 配置 SSH ──────────────────────────────────"
sudo systemsetup -setremotelogin on 2>/dev/null && log "SSH 已开启" || {
    warn "无法自动开启 SSH，请手动去「系统设置 → 通用 → 共享 → 远程登录」打开"
}

# ─── 创建 CLI 工具 ────────────────────────────────────────
SCRIPT_DIR="$HOME/.local/bin"
mkdir -p "$SCRIPT_DIR"

cat > "$SCRIPT_DIR/mac-share" << 'SCRIPTEOF'
#!/usr/bin/env bash
set -euo pipefail

TMUX_SESSION="mac-share"
TTYD_PORT="${TTYD_PORT:-7681}"
CONF="$HOME/.tmux.macshare.conf"

_get_lan_ip() {
    ifconfig en0 2>/dev/null | awk '/inet /{print $2;exit}' || \
    ifconfig en1 2>/dev/null | awk '/inet /{print $2;exit}' || \
    echo "未知"
}

_get_ts_ip() {
    command -v tailscale &>/dev/null || { echo ""; return; }
    tailscale ip -4 2>/dev/null || echo ""
}

cmd_start() {
    mkdir -p "$HOME/.mac-share"

    # tmux
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        echo "tmux session 已存在: $TMUX_SESSION"
    else
        tmux -f "$CONF" new-session -d -s "$TMUX_SESSION"
        echo "创建 tmux session: $TMUX_SESSION"
    fi

    # ttyd
    if pgrep -f "ttyd.*$TTYD_PORT" &>/dev/null; then
        echo "ttyd 已在运行 (端口 $TTYD_PORT)"
    else
        echo "启动 ttyd 端口 $TTYD_PORT ..."
        nohup ttyd -p "$TTYD_PORT" -W \
            ${TTYD_USER:+ -c "$TTYD_USER:$TTYD_PASS"} \
            -t "titleFixed=mac-share" \
            tmux -f "$CONF" attach -t "$TMUX_SESSION" \
            > "$HOME/.mac-share/ttyd.log" 2>&1 &
        sleep 2
        if pgrep -f "ttyd.*$TTYD_PORT" &>/dev/null; then
            echo "ttyd 启动成功"
        else
            echo "ttyd 启动失败，查看: $HOME/.mac-share/ttyd.log"
            exit 1
        fi
    fi

    LAN=$(_get_lan_ip)
    TS=$(_get_ts_ip)
    IP="${TS:-$LAN}"

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  共享终端已就绪"
    echo "═══════════════════════════════════════════════"
    echo ""
    if [ -n "$TS" ]; then
        echo "  🔗 Tailscale (跨子网):"
        echo "     ssh $(whoami)@$TS"
        echo "     http://$TS:$TTYD_PORT"
        echo ""
    fi
    if [ -n "$LAN" ] && [ "$LAN" != "未知" ]; then
        echo "  🏠 局域网:"
        echo "     ssh $(whoami)@$LAN"
        echo "     http://$LAN:$TTYD_PORT"
    fi
    if [ -z "$TS" ] && { [ -z "$LAN" ] || [ "$LAN" = "未知" ]; }; then
        echo "  ❌ 无法获取 IP，请检查网络"
    fi
    echo ""
    [ -z "$TS" ] && echo "  ⚠️  未检测到 Tailscale。建议运行 tailscale up"
    echo "═══════════════════════════════════════════════"
}

cmd_stop() {
    pkill -f "ttyd.*$TTYD_PORT" 2>/dev/null && echo "已停止 ttyd" || true
    tmux kill-session -t "$TMUX_SESSION" 2>/dev/null && echo "已停止 tmux" || true
}

cmd_status() {
    echo "════════ mac-share 状态 ════════"
    echo "Hostname:  $(hostname)"
    echo "局域网 IP: $(_get_lan_ip)"
    TS=$(_get_ts_ip)
    [ -n "$TS" ] && echo "Tailscale: $TS"
    echo ""
    tmux has-session -t "$TMUX_SESSION" 2>/dev/null && echo "tmux: ✅ 运行中" || echo "tmux: ❌ 未运行"
    pgrep -f "ttyd.*$TTYD_PORT" &>/dev/null && echo "ttyd: ✅ 运行中 (端口 $TTYD_PORT)" || echo "ttyd: ❌ 未运行"
    echo "════════════════════════════════"
}

cmd_connect() {
    LAN=$(_get_lan_ip)
    TS=$(_get_ts_ip)
    echo ""
    if [ -n "$TS" ]; then
        echo "═ Tailscale ═════════════════════"
        echo "  ssh $(whoami)@$TS"
        echo "  http://$TS:$TTYD_PORT"
        echo ""
    fi
    echo "═ 局域网 ════════════════════════"
    echo "  ssh $(whoami)@$LAN"
    echo "  http://$LAN:$TTYD_PORT"
    echo ""
    echo "═ 快捷键 ════════════════════════"
    echo "  Ctrl+B D  断开会话（后台继续跑）"
    echo "  Ctrl+B C  新建窗口"
    echo "  Ctrl+B N  下一窗口"
    echo "  Ctrl+B [  滚屏模式 (q 退出)"
}

mkdir -p "$HOME/.mac-share"
case "${1:-}" in
    start)     cmd_start ;;
    stop)      cmd_stop ;;
    status)    cmd_status ;;
    connect)   cmd_connect ;;
    tailscale) _get_ts_ip ;;
    *) echo "用法: mac-share {start|stop|status|connect|tailscale}" ;;
esac
SCRIPTEOF

chmod +x "$SCRIPT_DIR/mac-share"
log "CLI 已安装: mac-share"

# ─── PATH 配置 ──────────────────────────────────────────
for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
    [ -f "$rc" ] && grep -q "$SCRIPT_DIR" "$rc" 2>/dev/null || {
        echo "export PATH=\"$SCRIPT_DIR:\$PATH\"" >> "$rc"
    }
done
export PATH="$SCRIPT_DIR:$PATH"

# ─── tmux 配置 ──────────────────────────────────────────
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

# ─── 完成 ────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════"
echo "  安装完成"
echo "════════════════════════════════════════════════════════"
echo ""
echo "  1 启动服务:     mac-share start"
echo "  2 查看连接:     mac-share connect"
echo ""
echo "  ⚠️  同一 WiFi 也可能不通（VLAN 隔离），用 Tailscale:"
echo "     tailscale up              # 浏览器登录一次"
echo "     mac-share tailscale       # 查看固定 IP"
echo ""
echo "  其他设备:  brew install tailscale && tailscale up"
echo "          https://tailscale.com/download  (Windows)"
echo "════════════════════════════════════════════════════════"
