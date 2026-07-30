# CLAUDE.md — github_claude_proxy

## What this is

A thin config repo around **LiteLLM** that turns a **GitHub Copilot subscription** into a local LLM backend. It exposes:

- an **Anthropic-compatible API** for Claude Code (`/v1/messages`), and
- an **OpenAI-compatible API** — `/v1/models`, `/v1/chat/completions`, and `/v1/responses` — for tools like Codex and Pi. Current Codex is **Responses-API only** (no chat-completions); LiteLLM routes `/v1/responses` to the same model groups, so set Codex `wire_api = "responses"`.

There is almost no code here — the repo is the two YAML configs plus a start script. LiteLLM does the actual work.

## Files

- `config.yaml` — committed template. `master_key` is the placeholder `your-anthropic-api-key-here`.
- `config.local.yaml` — **gitignored**, holds the real `master_key`. `start-proxy.sh` prefers it over `config.yaml`.
- `start-proxy.sh` — creates/activates `.venv/`, installs `litellm[proxy]` if missing, then runs `litellm --config <config>` on `0.0.0.0:4000`.
- `claude-settings-example.json` — sample `~/.claude/settings.json`.
- `.venv/` — gitignored local virtualenv.

When editing model mappings, **change both `config.yaml` and `config.local.yaml`** and keep each file's own `master_key`. They should otherwise be identical.

## Key facts / gotchas

- **macOS + Homebrew Python ⇒ PEP 668.** System-wide `pip install` fails with `externally-managed-environment`. That's why `start-proxy.sh` uses a `.venv`. Don't revert it to a bare `pip install`.
- **The Copilot model catalog is volatile and NOT Claude.** Copilot periodically renames/removes backends, and currently exposes **no `claude-*` models**. Never assume a model ID — query the live list first:
  ```bash
  API_KEY=$(python3 -c "import json;print(json.load(open('$HOME/.config/litellm/github_copilot/api-key.json'))['token'])")
  curl -s https://api.githubcopilot.com/models \
    -H "Authorization: Bearer $API_KEY" \
    -H "Copilot-Integration-Id: vscode-chat" \
    -H "editor-version: vscode/1.85.1" | python3 -m json.tool
  ```
  The `litellm_params.model` values (after the `github_copilot/` prefix) MUST be IDs from that list, or requests fail. The left-hand `model_name` is a free alias.
- **Claude aliases are routed to a GPT backend** (currently `gpt-5.6-sol`; Haiku-tier → `gpt-5.4-mini`) precisely because no Claude backend exists. Update these when the catalog changes.
- **Auth returns 500, not 401,** on a missing/bad key because the proxy runs without the optional `prisma` DB layer. Harmless — a valid `master_key` works fine.
- **`extra_headers`** (`editor-version`, `Copilot-Integration-Id: vscode-chat`) are required on every entry for Copilot auth.

## Verifying a config change

Parse-check, then smoke-test against the live endpoints (use a throwaway port so you don't collide with a running proxy):

```bash
.venv/bin/python -c "import yaml; d=yaml.safe_load(open('config.local.yaml')); print(len(d['model_list']),'models')"
.venv/bin/litellm --config config.local.yaml --port 4123 --host 127.0.0.1 &
sleep 5
curl -s http://127.0.0.1:4123/v1/models -H "Authorization: Bearer <master-key>" | python3 -m json.tool | head
kill %1
```

## Conventions

- This is a config repo, not an app — prefer small, surgical YAML edits over restructuring.
- Never commit `config.local.yaml` or a real key into `config.yaml`.
- Keep the README's model list in sync with the configs when mappings change.
