#!/bin/bash

# GitHub Copilot Proxy Startup Script
# This script starts the LiteLLM proxy server for Claude Code

set -e

echo "🚀 Starting GitHub Copilot Proxy for Claude Code..."
echo ""

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

# Start the proxy
echo "🌐 Starting LiteLLM proxy on http://0.0.0.0:4000"
echo "📝 Press Ctrl+C to stop"
echo ""
echo "Note: First time? Follow the device authentication prompt to connect GitHub Copilot"
echo ""

litellm --config "$CONFIG_FILE"
