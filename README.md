# GitHub Copilot Proxy for Claude Code

This repository contains the configuration to use GitHub Copilot's LLM API as a backend for Claude Code, allowing you to use your GitHub Copilot subscription instead of a separate Claude API subscription.

**Based on:** [Using Claude Code with GitHub Copilot Subscription](https://dev.to/allentcm/using-claude-code-with-github-copilot-subscription-2obj) by Allen T.

It also exposes a standard **OpenAI-compatible API** (`/v1/models`, `/v1/chat/completions`), so the same proxy can back OpenAI-compatible tools such as **Codex** and **Pi** — see [Using with OpenAI-compatible tools](#using-with-openai-compatible-tools-codex--pi).

> **Model choice:** Claude Code will most often use the Anthropic (Claude) models, but it can also run on the OpenAI models exposed here — e.g. set `ANTHROPIC_MODEL="gpt-5.5"` and Claude Code drives GPT-5.5 through the proxy (litellm bridges it onto Copilot's Responses API). Which models are actually available depends on your Copilot login — see [Supported model names](#configyaml).

## Prerequisites

- GitHub Copilot subscription
- Python 3.8 or higher
- Claude Code installed (`npm install -g @anthropic-ai/claude-code`)

## Quick Start

### Step 1: Install LiteLLM

`./start-proxy.sh` handles this for you: on first run it creates a virtual
environment in `.venv/` and installs LiteLLM into it (Homebrew Python blocks
system-wide `pip` installs under PEP 668, so a venv is required on macOS).

To install manually instead:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install 'litellm[proxy]'
```

### Step 2: Create Local Configuration

Copy the template to `config.yaml` and add your API key:

```bash
cp config.example.yaml config.yaml
# Edit config.yaml and replace "your-anthropic-api-key-here" with your actual token
```

**Note:** `config.yaml` is gitignored and won't be committed. The committed
template is `config.example.yaml` (placeholder key only).

### Step 3: Start the Proxy Server

From this directory, run:

```bash
./start-proxy.sh
```

The script uses `config.yaml` (your live config; copy it from `config.example.yaml` first — see Step 2).

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
export ANTHROPIC_MODEL="gpt-5.5"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="gpt-5-mini"
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

The `config.yaml` file contains the model routing configuration. It maps friendly model names to GitHub Copilot backends.

> **Important:** GitHub Copilot's backend catalog changes over time and is **network-gated** — the Claude / Kimi backends are only visible when connected to the corporate **VPN**. Off-VPN, `/models` returns a reduced list (GPT / Gemini / Grok only) and any request to a hidden backend fails with a connection error. Connect the VPN before starting the proxy for Claude models.
>
> To see the models Copilot currently offers for your account, query the live endpoint once the proxy has authenticated:
> ```bash
> API_KEY=$(python3 -c "import json;print(json.load(open('$HOME/.config/litellm/github_copilot/api-key.json'))['token'])")
> curl -s https://api.githubcopilot.com/models \
>   -H "Authorization: Bearer $API_KEY" \
>   -H "Copilot-Integration-Id: vscode-chat" \
>   -H "editor-version: vscode/1.85.1" | python3 -m json.tool
> ```
> If a backend ID you rely on isn't listed, update `config.yaml` to point at one that is.

**Supported model names:**

> Model availability depends on your Copilot login. On the **business/enterprise seat** (`api.business.githubcopilot.com`) the working models are GPT-only (below). The Claude/Gemini aliases require the **personal** login + VPS tunnel — see [Using with the VPS tunnel](#connectivity--vps-tunnel).

**OpenAI GPT (business seat):**
- **`gpt-5.5`, `gpt-5.4`, `gpt-5.4-mini`, `gpt-5.3-codex`** — Responses-API only; configured with `model_info: {mode: responses}` (see note below). Usable from Claude Code, pi/omp, and OpenAI clients.
- `gpt-5-mini`, `gpt-4.1`, `gpt-4o`, `gpt-4o-mini` — standard chat/completions.

**Claude** — SAP AI Core naming `anthropic--claude-<version>-<tier>` (personal login + tunnel):
- `anthropic--claude-4.5-sonnet`/`-4.6-sonnet`/`-5-sonnet`, `anthropic--claude-4.5-haiku` (verified working). Opus/Fable aliases exist but their backends currently return `model_not_supported`.

**Google Gemini** (personal login + tunnel): `gemini-3.6-flash`, `gemini-3.5-flash`, `gemini-3.1-pro-preview`, `gemini-3-flash-preview`, `gemini-2.5-pro`.

**Wildcards:** `anthropic/*` → `claude-sonnet-4.5`, `openai/*` → `gpt-4.1`

> **Responses-API models** (`gpt-5.5`/`5.4`/`5.4-mini`/`5.3-codex`): these are served only via Copilot's `/responses` endpoint. Their config entries set `model_info: {mode: responses}` and carry **no `extra_headers`** (a `Copilot-Integration-Id` header collides with litellm's default and returns `400 unknown Copilot-Integration-Id`). litellm bridges them onto `/v1/messages`, `/v1/chat/completions`, and `/v1/responses`. Restart the proxy after any config change — litellm loads config once at startup.

The `extra_headers` on the non-responses entries are required by the GitHub Copilot API for authentication.

### Environment Variables

Alternatively, you can set these as environment variables instead of using settings.json:

```bash
export ANTHROPIC_BASE_URL="http://127.0.0.1:4000"
export ANTHROPIC_AUTH_TOKEN="your-anthropic-api-key-here"
export ANTHROPIC_MODEL="gpt-5.5"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="gpt-5-mini"
export DISABLE_NON_ESSENTIAL_MODEL_CALLS="1"
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"
```

**Environment Variable Details:**
- `ANTHROPIC_BASE_URL`: Points to the local LiteLLM proxy (use 127.0.0.1 or localhost)
- `ANTHROPIC_AUTH_TOKEN`: Dummy token (auth is disabled for local use, but Claude Code requires a value)
- `ANTHROPIC_MODEL`: Primary model to use (`gpt-5.5` on the business seat, routed via Copilot's Responses API)
- `ANTHROPIC_DEFAULT_HAIKU_MODEL`: Faster model for simple operations (`gpt-5-mini`)
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

For full request/response tracing, edit `config.yaml` and set:
```yaml
litellm_settings:
  set_verbose: True
```

For concise per-request diagnostics instead (model, resolved `api_base`,
`copilot-integration-id` header, and full failure details), the config ships
with a custom logging callback:
```yaml
litellm_settings:
  callbacks: proxy_logging.copilot_logger   # defined in proxy_logging.py
```
It prints `[GHPROXY request]` and `[GHPROXY FAILURE]` lines to the proxy's
stderr — handy for tracing intermittent Copilot errors (e.g. an occasional
`unknown Copilot-Integration-Id` 400 during token refresh, which Claude Code
retries through). The start scripts set `PYTHONPATH=.` so the module is
importable. Restart the proxy after any config change.

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

## Using with OpenAI-compatible tools (Codex / Pi)

LiteLLM serves a standard **OpenAI-compatible API** alongside the Anthropic one, so any tool that speaks the OpenAI protocol can use the same proxy and the same GitHub Copilot subscription.

**Endpoints:**
- `GET  /v1/models` — lists every model in `config.yaml` (OpenAI format)
- `POST /v1/chat/completions` — chat completions (OpenAI format)
- `POST /v1/responses` — the OpenAI **Responses API** (used by the Codex CLI)

**Connection settings** for any OpenAI-compatible client:

| Setting   | Value |
|-----------|-------|
| Base URL  | `http://localhost:4000/v1` (or `http://localhost:4000`) |
| API key   | the `master_key` from `config.local.yaml` |
| Model     | any name from the config, e.g. `gpt-5.6-sol`, `gpt-5.5`, `gemini-3.6-flash`, `grok-4.5` |

> **Auth is required.** Requests must send `Authorization: Bearer <master_key>`. A missing/invalid key currently returns HTTP `500` (rather than a clean `401`) because the proxy runs without the optional `prisma`/database layer — this is harmless; just send a valid key.

Quick check that it's up:

```bash
curl -s http://localhost:4000/v1/models \
  -H "Authorization: Bearer <your-master-key>" | python3 -m json.tool
```

### Codex CLI

Current versions of the Codex CLI use the OpenAI **Responses API** (`/v1/responses`) exclusively — chat-completions is no longer supported. The proxy serves `/v1/responses`, so point Codex at it directly. In `~/.codex/config.toml`:

```toml
[model_providers.copilot-proxy]
name = "copilot-proxy"
base_url = "http://localhost:4000/v1"
wire_api = "responses"     # Codex is Responses-API only
env_key = "COPILOT_PROXY_KEY"

[profiles.copilot]
model = "gpt-5.6-sol"
model_provider = "copilot-proxy"
```

Then:

```bash
export COPILOT_PROXY_KEY="<your-master-key>"
codex --profile copilot
```

Test the Responses endpoint directly:

```bash
curl -s http://localhost:4000/v1/responses \
  -H "Authorization: Bearer <your-master-key>" -H "Content-Type: application/json" \
  -d '{"model":"gpt-5.6-sol","input":"say hi in 3 words"}'
```

### Pi (or any other OpenAI-compatible client)

Point it at the base URL and key above. For example, with the OpenAI Python SDK:

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:4000/v1",
    api_key="<your-master-key>",
)
resp = client.chat.completions.create(
    model="gpt-5.6-sol",
    messages=[{"role": "user", "content": "Hello!"}],
)
print(resp.choices[0].message.content)
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
