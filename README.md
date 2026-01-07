# GitHub Copilot Proxy for Claude Code

This repository contains the configuration to use GitHub Copilot's LLM API as a backend for Claude Code, allowing you to use your GitHub Copilot subscription instead of a separate Claude API subscription.

## Prerequisites

- GitHub Copilot subscription
- Python 3.8 or higher
- Claude Code installed (`npm install -g @anthropic-ai/claude-code`)

## Quick Start

### Step 1: Install LiteLLM

```bash
pip install 'litellm[proxy]'
```

### Step 2: Create Local Configuration

Create a `config.local.yaml` file with your API key:

```bash
cp config.yaml config.local.yaml
# Edit config.local.yaml and replace "your-anthropic-api-key-here" with your actual token
```

**Note:** `config.local.yaml` is gitignored and won't be committed to version control.

### Step 3: Start the Proxy Server

From this directory, run:

```bash
./start-proxy.sh
```

The script automatically uses `config.local.yaml` if it exists, otherwise falls back to `config.yaml`.

The proxy will start on `http://0.0.0.0:4000`.

**Leave this terminal running** - the proxy needs to stay active for Claude Code to work.

### Step 4: First-Time Authentication

On first run, LiteLLM will prompt you to authenticate:

1. You'll see a message like:
   ```
   Please visit https://github.com/login/device and enter code XXXX-XXXX
   ```
2. Open that URL in your browser
3. Enter the code shown
4. Authorize the application
5. Authentication is cached in `~/.config/litellm/github_copilot/` - you won't need to do this again

### Step 5: Configure Claude Code

You have two options:

**Option A: Environment Variables in ~/.zshrc (Recommended)**

Add these to your `~/.zshrc`:

```bash
export ANTHROPIC_BASE_URL="http://127.0.0.1:4000"
export ANTHROPIC_AUTH_TOKEN="your-anthropic-api-key-here"
export ANTHROPIC_MODEL="claude-sonnet-4.5"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="claude-haiku-4.5"
export DISABLE_NON_ESSENTIAL_MODEL_CALLS="1"
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"
```

Then reload: `source ~/.zshrc`

**Option B: Claude Settings File**

Create `~/.claude/settings.json` or `.claude/settings.json` in your project directory:

```bash
mkdir -p ~/.claude
cp claude-settings-example.json ~/.claude/settings.json
# Edit and replace "your-anthropic-api-key-here" with your token
```

See `claude-settings-example.json` for the format.

### Step 6: Launch Claude Code

In a **new terminal** (keep the proxy running), start Claude Code:

```bash
claude-code
```

All requests will now be routed through LiteLLM to your GitHub Copilot subscription.

## Configuration

### config.yaml

The `config.yaml` file contains the model routing configuration. It maps standard Anthropic model names to GitHub Copilot backends:

**Supported model names:**

**Claude Models:**
- `claude-sonnet-4.5` → GitHub Copilot's Claude Sonnet 4.5
- `claude-4.5-sonnet` → GitHub Copilot's Claude Sonnet 4.5
- `anthropic--claude-4.5-sonnet` → GitHub Copilot's Claude Sonnet 4.5
- `claude-haiku-4.5` → GitHub Copilot's GPT-5 Mini (for faster operations)

**OpenAI Models:**
- `gpt-5` → GitHub Copilot's GPT-5
- `gpt-5.1` → GitHub Copilot's GPT-5.1
- `gpt-5.2` → GitHub Copilot's GPT-5.2
- `gpt-5.1-codex` → GitHub Copilot's GPT-5.1 Codex
- `gpt-4` → GitHub Copilot's GPT-5 (legacy mapping)
- `gpt-4o` → GitHub Copilot's GPT-5 (legacy mapping)
- `gpt-4-turbo` → GitHub Copilot's GPT-5.1 (legacy mapping)
- `o1` → GitHub Copilot's o1
- `o1-mini` → GitHub Copilot's o1-mini
- `o1-preview` → GitHub Copilot's o1-preview

**Wildcards:**
- `anthropic/*` → GitHub Copilot's Claude Sonnet 4.5
- `openai/*` → GitHub Copilot's GPT-5

The `extra_headers` are required by GitHub Copilot API for proper authentication.

### Environment Variables

Alternatively, you can set these as environment variables instead of using settings.json:

```bash
export ANTHROPIC_BASE_URL="http://127.0.0.1:4000"
export ANTHROPIC_AUTH_TOKEN="your-anthropic-api-key-here"
export ANTHROPIC_MODEL="claude-sonnet-4.5"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="claude-haiku-4.5"
export DISABLE_NON_ESSENTIAL_MODEL_CALLS="1"
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"
```

**Environment Variable Details:**
- `ANTHROPIC_BASE_URL`: Points to the local LiteLLM proxy (use 127.0.0.1 or localhost)
- `ANTHROPIC_AUTH_TOKEN`: Dummy token (auth is disabled for local use, but Claude Code requires a value)
- `ANTHROPIC_MODEL`: Primary model to use (Claude Sonnet 4.5)
- `ANTHROPIC_DEFAULT_HAIKU_MODEL`: Faster model for simple operations (GPT-5 Mini)
- `DISABLE_NON_ESSENTIAL_MODEL_CALLS`: Reduces unnecessary API calls
- `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`: Further optimizes traffic

## Verification

To verify everything is working:

1. The proxy terminal should show incoming requests
2. Claude Code should respond normally to your queries
3. Check proxy logs for any errors

## Stopping the Proxy

Press `Ctrl+C` in the terminal running the proxy server.

## Troubleshooting

### Proxy doesn't start

- Ensure Python and LiteLLM are installed: `pip install --upgrade 'litellm[proxy]'`
- Check if port 4000 is available: `lsof -i :4000`

### "Connection refused" error

- Make sure the proxy is running (`./start-proxy.sh`)
- Verify the proxy is on port 4000: `lsof -i :4000`
- Check that `ANTHROPIC_BASE_URL` matches the proxy address

### Authentication errors

- Complete the device flow authentication (visit the URL and enter the code)
- Verify your GitHub Copilot subscription is active at https://github.com/settings/copilot
- If auth is cached but expired, delete it: `rm -rf ~/.config/litellm/github_copilot/` and re-authenticate

### Claude Code can't connect

- Verify the proxy is running: `curl http://localhost:4000/health`
- Check that `ANTHROPIC_BASE_URL` in settings.json matches the proxy URL
- Ensure `ANTHROPIC_AUTH_TOKEN` matches the `master_key` in config.yaml

### Proxy starts but requests fail

- Check proxy logs for detailed error messages
- Enable verbose logging (see below)

### Enable debugging

Edit `config.yaml` and set:
```yaml
litellm_settings:
  set_verbose: True
```

This will show detailed logs of all requests. Restart the proxy after changes.

## Advanced Configuration

### Change Port

To run LiteLLM on a different port:

```bash
litellm --config config.yaml --port 8080
```

Don't forget to update `ANTHROPIC_BASE_URL` in Claude Code settings.

### Add More Models

You can add more model mappings in `config.yaml`:

```yaml
model_list:
  - model_name: my-custom-model
    litellm_params:
      model: github_copilot/some-other-model
      extra_headers:
        editor-version: "vscode/1.85.1"
        Copilot-Integration-Id: "vscode-chat"
```

## Tips

- Keep the proxy terminal visible to monitor requests
- Use verbose mode (`set_verbose: True`) for debugging
- Authentication is cached after first use - no need to re-authenticate
- All Claude Code requests will now use your GitHub Copilot subscription

## Cost Savings

By using GitHub Copilot's API:
- No separate Claude API subscription needed
- Leverage your existing GitHub Copilot subscription
- Access to both Claude and GPT models through one subscription

## References

- [LiteLLM Documentation](https://docs.litellm.ai/)
- [GitHub Copilot API](https://github.com/features/copilot)
- [Claude Code Documentation](https://github.com/anthropics/claude-code)
- [Original Setup Guide](https://dev.to/allentcm/using-claude-code-with-github-copilot-subscription-2obj)
