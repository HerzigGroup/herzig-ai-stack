# Claude Code Configuration

> The full Claude Code setup with the local model (installation, configuration, scripts) is documented in a separate repo:
> **https://github.com/HerzigGroup/claude_code_local**

## Using the Local Model (`claude-qwen`)

An alias defined in `~/.bashrc` starts Claude Code with the local LiteLLM proxy:

```bash
alias claude-qwen='ANTHROPIC_BASE_URL=http://132.180.21.140:4000 \
  ANTHROPIC_API_KEY=no-key \
  CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1 \
  API_TIMEOUT_MS=600000 \
  CLAUDE_CODE_AUTO_COMPACT_WINDOW=131072 \
  CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=80 \
  CLAUDE_CODE_MAX_OUTPUT_TOKENS=20480 \
  claude'
```

**Environment variables explained:**

| Variable | Value | Meaning |
|----------|-------|---------|
| `ANTHROPIC_BASE_URL` | `http://132.180.21.140:4000` | LiteLLM proxy instead of the real Anthropic API |
| `ANTHROPIC_API_KEY` | `no-key` | Required field, but LiteLLM does not validate it |
| `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS` | `1` | Disables beta features not supported by the local model |
| `API_TIMEOUT_MS` | `600000` | 10-minute timeout — local inference can take longer than cloud |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | `131072` | Matches the 128k context window of the model |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `80` | Compacts context at 80% utilization |
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS` | `20480` | ~20k max output tokens |

**Usage:**
```bash
claude-qwen          # Start Claude Code with local model
claude-qwen /path/to/project
```

---

## Web Search (MCP SearXNG)

Claude Code is configured to use SearXNG as a web search tool (instead of the built-in WebSearch tool, which has no Anthropic API access in this setup).

**MCP server configuration** (`~/.claude.json`):
```json
"mcpServers": {
  "searxng": {
    "type": "http",
    "url": "http://132.180.21.140:8001/mcp"
  }
}
```

**CLAUDE.md instruction** (in `~/CLAUDE.md`):
- Always use `mcp__searxng__web_search`, never the built-in Web Search tool

**MCP tool name in prompts:** `mcp__searxng__web_search`

---

## Claude Code Settings (`~/.claude/settings.json`)

```json
{
  "permissions": {
    "allow": [
      "Bash(nvidia-smi *)",
      "Bash(nmcli device status)",
      "Bash(pip3 index *)",
      "WebSearch(*)"
    ]
  },
  "enabledMcpjsonServers": ["searxng"],
  "skipDangerousModePermissionPrompt": true,
  "agentPushNotifEnabled": true,
  "skipAutoPermissionPrompt": true
}
```

---

## Model Names in LiteLLM

LiteLLM registers multiple Claude model names — all of them route to the same Qwen server:

| Claude model name | Internal endpoint |
|------------------|------------------|
| `claude-sonnet-4-6` | SGLang :30000 |
| `claude-opus-4-7` | SGLang :30000 |
| `claude-haiku-4-5-20251001` | SGLang :30000 |
| `claude-3-5-sonnet-20241022` | SGLang :30000 |

This way Claude Code can "select" any model and they all land on the same local model.
