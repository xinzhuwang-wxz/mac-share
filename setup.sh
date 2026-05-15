#!/usr/bin/env bash
# ============================================================
#  mac-share setup — 在 Mac mini 上运行，一键配好多用户终端共享
#  curl -fsSL https://raw.githubusercontent.com/<user>/mac-share/main/setup.sh | bash
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; exit 1; }

TMUX_SESSION="mac-share"
TTYD_PORT="${TTYD_PORT:-7681}"
# 留空 = 无需密码。局域网内推荐留空；公网建议设置
TTYD_USER="${TTYD_USER:-}"
TTYD_PASS="${TTYD_PASS:-}"

# ─── 0. 探测环境 ───────────────────────────────────────────
log "检测系统环境..."
[ "$(uname -s)" = "Darwin" ] || err "请在 Mac 上运行本脚本"
command -v brew &>/dev/null || {
    warn "未安装 Homebrew，正在安装..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}
BREW_PREFIX="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
eval "$($BREW_PREFIX/bin/brew shellenv 2>/dev/null || true)"

# ─── 1. 安装依赖 ───────────────────────────────────────────
log "安装依赖 (tmux, ttyd)..."
brew install tmux 2>/dev/null || warn "tmux 已安装或安装失败，继续..."
brew install ttyd 2>/dev/null || warn "ttyd 已安装或安装失败，继续..."

# ─── 2. 配置 SSH ───────────────────────────────────────────
log "配置 SSH 远程登录..."
sudo systemsetup -setremotelogin on 2>/dev/null || {
    warn "无法启用 SSH，请在「系统设置 > 通用 > 共享 > 远程登录」手动开启"
}

# ─── 3. 配置 tmux ──────────────────────────────────────────
log "配置 tmux..."
cat > "$HOME/.tmux.macshare.conf" << 'TMUXEOF'
# mac-share tmux 配置
set -g default-terminal "screen-256color"
set -g mouse on
set -g history-limit 50000
set -g status-style bg=colour236,fg=white
set -g status-left '#[fg=green]#S '
set -g status-right '#[fg=yellow]%Y-%m-%d %H:%M '
setw -g window-status-format '#[fg=white]#I #W'
setw -g window-status-current-format '#[fg=cyan,bold]#I #W'
TMUXEOF
log "tmux 配置写入 ~/.tmux.macshare.conf"

# ─── 4. 创建管理脚本 ───────────────────────────────────────
SCRIPT_DIR="$HOME/.local/bin"
mkdir -p "$SCRIPT_DIR"

cat > "$SCRIPT_DIR/mac-share" << 'SCRIPTEOF'
#!/usr/bin/env bash
# mac-share CLI — 管理 Mac mini 共享终端
# 用法: mac-share {start|stop|status|connect|attach}

set -euo pipefail
TMUX_SESSION="mac-share"
TTYD_PORT="${TTYD_PORT:-7681}"
# 留空 = 无需密码。局域网内推荐留空；公网建议设置
TTYD_USER="${TTYD_USER:-}"
TTYD_PASS="${TTYD_PASS:-}"
FIFO="$HOME/.mac-share/ttyd.fifo"
PID_FILE="$HOME/.mac-share/ttyd.pid"
CONF="$HOME/.tmux.macshare.conf"

_get_ip() {
    local ip
    ip=$(ifconfig en0 2>/dev/null | grep 'inet ' | awk '{print $2}')
    [ -n "$ip" ] && echo "$ip" && return
    ip=$(ifconfig en1 2>/dev/null | grep 'inet ' | awk '{print $2}')
    [ -n "$ip" ] && echo "$ip" && return
    echo "无法获取 IP，请手动指定"
}

cmd_start() {
    mkdir -p "$HOME/.mac-share"

    # 启动 tmux session (如果不存在)
    if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        echo "创建 tmux session: $TMUX_SESSION"
        tmux -f "$CONF" new-session -d -s "$TMUX_SESSION"
    else
        echo "tmux session 已存在: $TMUX_SESSION"
    fi

    # 启动 ttyd (如果未运行)
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "ttyd 已在运行 (PID: $(cat "$PID_FILE"))"
    else
        rm -f "$FIFO"
        mkfifo "$FIFO"
        echo "启动 ttyd 在端口 $TTYD_PORT ..."
        nohup ttyd -p "$TTYD_PORT" \
            -W \
            ${TTYD_USER:+ -c "$TTYD_USER:$TTYD_PASS"} \
            -t "titleFixed=mac-share" \
            tmux -f "$CONF" attach -t "$TMUX_SESSION" \
            > "$HOME/.mac-share/ttyd.log" 2>&1 &
        echo $! > "$PID_FILE"
        sleep 2
        if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "ttyd 启动成功 (PID: $(cat "$PID_FILE"))"
        else
            echo "ttyd 启动失败，查看日志: $HOME/.mac-share/ttyd.log"
            rm -f "$PID_FILE"
            exit 1
        fi
    fi

    IP=$(_get_ip)
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Mac mini 共享终端已就绪"
    echo "═══════════════════════════════════════════════"
    echo ""
    echo "  🌐 Web 终端 (浏览器打开):"
    echo "     http://$IP:$TTYD_PORT"
    echo "     用户名: $TTYD_USER"
    echo "     密码:   $TTYD_PASS"
    echo ""
    echo "  💻 SSH + tmux (MacBook):"
    echo "     ssh $(whoami)@$IP"
    echo "     tmux -f ~/.tmux.macshare.conf attach -t $TMUX_SESSION"
    echo ""
    echo "  🪟 Windows 终端:"
    echo "     ssh $(whoami)@$IP"
    echo "     然后: tmux -f ~/.tmux.macshare.conf attach -t $TMUX_SESSION"
    echo "═══════════════════════════════════════════════"
}

cmd_stop() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        kill "$PID" 2>/dev/null && echo "已停止 ttyd (PID: $PID)" || true
        rm -f "$PID_FILE"
    fi
    tmux kill-session -t "$TMUX_SESSION" 2>/dev/null && echo "已停止 tmux session" || true
    rm -f "$FIFO"
}

cmd_status() {
    echo "──────────── mac-share 状态 ────────────"
    echo "Hostname: $(hostname)"
    echo "IP:       $(_get_ip)"
    echo ""
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        echo "tmux:     ✅ 运行中 (session: $TMUX_SESSION)"
        tmux list-clients -t "$TMUX_SESSION" 2>/dev/null | while read -r client; do
            echo "           ↳ $client"
        done
    else
        echo "tmux:     ❌ 未运行"
    fi
    echo ""
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "ttyd:     ✅ 运行中 (端口 $TTYD_PORT, PID $(cat "$PID_FILE"))"
    else
        echo "ttyd:     ❌ 未运行"
    fi
    echo "─────────────────────────────────────────"
}

cmd_connect() {
    IP=$(_get_ip)
    echo ""
    echo "═ MacBook 连接 ══════════════════════════"
    echo "  ssh $(whoami)@$IP"
    echo "  tmux -f ~/.tmux.macshare.conf attach -t $TMUX_SESSION"
    echo ""
    echo "═ Windows 连接 ══════════════════════════"
    echo "  方式1 (Win10+ 自带):"
    echo "    ssh $(whoami)@$IP"
    echo "    tmux -f ~/.tmux.macshare.conf attach -t $TMUX_SESSION"
    echo ""
    echo "  方式2 (浏览器最省事):"
    echo "    http://$IP:$TTYD_PORT  (密码: $TTYD_PASS)"
    echo ""
    echo "═ tmux 快捷键 ═══════════════════════════"
    echo "  Ctrl+B D    断开但保持 session 运行"
    echo "  Ctrl+B C    新建窗口"
    echo "  Ctrl+B N/P  切换窗口"
    echo "  Ctrl+B [    滚屏模式 (q 退出)"
}

cmd_attach() {
    tmux -f "$CONF" attach -t "$TMUX_SESSION"
}

mkdir -p "$HOME/.mac-share"
case "${1:-}" in
    start)    cmd_start ;;
    stop)     cmd_stop ;;
    status)   cmd_status ;;
    connect)  cmd_connect ;;
    attach)   cmd_attach ;;
    *)
        echo "用法: mac-share {start|stop|status|connect|attach}"
        echo ""
        echo "  start   启动共享 (tmux + ttyd)"
        echo "  stop    停止共享"
        echo "  status  查看状态"
        echo "  connect 显示连接指令"
        echo "  attach  直接 attach 到 tmux session"
        exit 1
        ;;
esac
SCRIPTEOF

chmod +x "$SCRIPT_DIR/mac-share"
log "CLI 工具安装到: $SCRIPT_DIR/mac-share"

# ─── 5. 加入 PATH ───────────────────────────────────────────
if ! echo "$PATH" | tr ':' '\n' | grep -qxF "$SCRIPT_DIR"; then
    for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
        if [ -f "$rc" ]; then
            grep -q "$SCRIPT_DIR" "$rc" 2>/dev/null || {
                echo "export PATH=\"$SCRIPT_DIR:\$PATH\"" >> "$rc"
            }
        fi
    done
    export PATH="$SCRIPT_DIR:$PATH"
    log "已将 $SCRIPT_DIR 加入 PATH"
fi

# ─── 6. 收尾 ────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════"
echo "  安装完成！"
echo "════════════════════════════════════════════════════════"
echo ""
echo "  1. 启动共享终端:"
echo "     mac-share start"
echo ""
echo "  2. 查看连接方式:"
echo "     mac-share connect"
echo ""
echo "  3. 停止共享:"
echo "     mac-share stop"
echo "════════════════════════════════════════════════════════"
