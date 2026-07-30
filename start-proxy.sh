#!/bin/bash

# GitHub Copilot Proxy Startup Script
# This script starts the LiteLLM proxy server for Claude Code

set -e

echo "🚀 Starting GitHub Copilot Proxy for Claude Code..."
echo ""

# Set up a virtual environment so we don't touch the system (Homebrew) Python
VENV_DIR=".venv"
if [ ! -d "$VENV_DIR" ]; then
    echo "📦 Creating virtual environment in $VENV_DIR..."
    python3 -m venv "$VENV_DIR"
fi

# Activate the virtual environment
source "$VENV_DIR/bin/activate"

# Check if litellm is installed
if ! command -v litellm &> /dev/null; then
    echo "❌ LiteLLM is not installed."
    echo "📦 Installing LiteLLM..."
    pip install 'litellm[proxy]'
    echo "✅ LiteLLM installed successfully"
    echo ""
fi

# Determine which config file to use
if [ -f "config.local.yaml" ]; then
    CONFIG_FILE="config.local.yaml"
    echo "📋 Using local configuration: config.local.yaml"
elif [ -f "config.yaml" ]; then
    CONFIG_FILE="config.yaml"
    echo "📋 Using default configuration: config.yaml"
else
    echo "❌ No config file found (config.yaml or config.local.yaml)"
    echo "Please run this script from the repository root"
    exit 1
fi

# Configurable host/port (override with HOST=... PORT=... ./start-proxy.sh)
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-4000}"

# Print proxy information: endpoints + supported models parsed from the config
echo "════════════════════════════════════════════════════════════════"
echo "🌐 LiteLLM proxy → GitHub Copilot"
echo "   Base URL:   http://${HOST}:${PORT}"
echo "   Config:     $CONFIG_FILE"
echo ""
echo "   Endpoints:"
echo "     Anthropic (Claude Code):  POST /v1/messages"
echo "     OpenAI chat:              POST /v1/chat/completions"
echo "     OpenAI responses (Codex): POST /v1/responses"
echo "     Model list:               GET  /v1/models"
echo "     Health:                   GET  /health/liveliness"
echo ""

# List the models defined in the config (name -> backend). Uses the venv python.
python - "$CONFIG_FILE" <<'PY' || echo "   (install PyYAML to list models: pip install pyyaml)"
import sys
try:
    import yaml
except ImportError:
    sys.exit(1)
with open(sys.argv[1]) as f:
    cfg = yaml.safe_load(f) or {}
models = cfg.get("model_list", []) or []
print("   Supported models ({}):".format(len(models)))
width = max((len(m.get("model_name", "?")) for m in models), default=0)
for m in models:
    name = m.get("model_name", "?")
    backend = (m.get("litellm_params", {}) or {}).get("model", "?")
    print("     {:<{w}}  ->  {}".format(name, backend, w=width))
PY
echo "════════════════════════════════════════════════════════════════"
echo ""

# Start the proxy
echo "📝 Press Ctrl+C to stop"
echo ""
echo "Note: First time? Follow the device authentication prompt to connect GitHub Copilot"
echo ""

litellm --config "$CONFIG_FILE" --host "$HOST" --port "$PORT"
