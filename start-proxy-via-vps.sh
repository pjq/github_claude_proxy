#!/bin/bash

# Start the GitHub Copilot proxy routed through an SSH tunnel to a VPS.
#
# Why: the SAP corporate firewall blocks api.individual.githubcopilot.com by
# TLS SNI (TCP connects, TLS handshake is killed). DNS/hosts/IP tricks don't
# help. Wrapping the traffic in SSH to an external VPS bypasses the SNI block.
#
# Chain: Claude Code / pi / omp
#          -> litellm proxy (127.0.0.1:4000)
#          -> HTTPS_PROXY http bridge (127.0.0.1:$BRIDGE_PORT)
#          -> ssh -D SOCKS5 tunnel (127.0.0.1:$SOCKS_PORT)
#          -> VPS ($VPS_HOST) -> api.individual.githubcopilot.com
#
# Config via env (with defaults):
#   VPS_HOST=proxy.pjq.me  SOCKS_PORT=1080  BRIDGE_PORT=8118  PORT=4000  HOST=0.0.0.0

set -e
cd "$(dirname "$0")"

VPS_HOST="${VPS_HOST:-proxy.pjq.me}"
SOCKS_PORT="${SOCKS_PORT:-1080}"
BRIDGE_PORT="${BRIDGE_PORT:-8118}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-4000}"

echo "🚀 Starting GitHub Copilot Proxy via VPS tunnel ($VPS_HOST)..."
echo ""

# venv (same as start-proxy.sh)
VENV_DIR=".venv"
if [ ! -d "$VENV_DIR" ]; then
    echo "📦 Creating virtual environment in $VENV_DIR..."
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"
if ! command -v litellm &> /dev/null; then
    echo "📦 Installing LiteLLM..."
    pip install 'litellm[proxy]'
fi

# Pick config
if [ -f "config.local.yaml" ]; then CONFIG_FILE="config.local.yaml"
elif [ -f "config.yaml" ]; then CONFIG_FILE="config.yaml"
else echo "❌ No config file found"; exit 1; fi

SSH_PID=""; BRIDGE_PID=""
cleanup() {
    echo ""; echo "🧹 Cleaning up tunnel and bridge..."
    [ -n "$BRIDGE_PID" ] && kill "$BRIDGE_PID" 2>/dev/null || true
    [ -n "$SSH_PID" ] && kill "$SSH_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# 1) SSH SOCKS5 tunnel to the VPS
echo "🔌 Opening SSH SOCKS5 tunnel: 127.0.0.1:$SOCKS_PORT -> $VPS_HOST"
ssh -o ConnectTimeout=10 -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes \
    -N -D "$SOCKS_PORT" "$VPS_HOST" &
SSH_PID=$!
sleep 3
if ! kill -0 "$SSH_PID" 2>/dev/null; then
    echo "❌ SSH tunnel failed to start (check: ssh $VPS_HOST)"; exit 1
fi

# 2) HTTP-CONNECT -> SOCKS5 bridge (litellm's async client needs an HTTP proxy)
echo "🌉 Starting HTTP->SOCKS bridge: 127.0.0.1:$BRIDGE_PORT -> 127.0.0.1:$SOCKS_PORT"
python http_to_socks_bridge.py "$BRIDGE_PORT" 127.0.0.1 "$SOCKS_PORT" &
BRIDGE_PID=$!
sleep 2
if ! kill -0 "$BRIDGE_PID" 2>/dev/null; then
    echo "❌ Bridge failed to start"; exit 1
fi

# 3) litellm proxy with outbound traffic forced through the bridge.
#    NO_PROXY keeps localhost callers direct.
echo ""
echo "🌐 LiteLLM proxy → GitHub Copilot (via $VPS_HOST)"
echo "   Base URL: http://${HOST}:${PORT}   Config: $CONFIG_FILE"
echo "   Outbound via HTTPS_PROXY=http://127.0.0.1:$BRIDGE_PORT"
echo "   Press Ctrl+C to stop (tunnel + bridge shut down automatically)"
echo ""

export HTTPS_PROXY="http://127.0.0.1:$BRIDGE_PORT"
export HTTP_PROXY="http://127.0.0.1:$BRIDGE_PORT"
export NO_PROXY="127.0.0.1,localhost"

litellm --config "$CONFIG_FILE" --host "$HOST" --port "$PORT"
