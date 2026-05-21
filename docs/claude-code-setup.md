# Claude Code Konfiguration

> Die vollständige Einrichtung von Claude Code mit lokalem Modell (Installation, Konfiguration, Skripte) ist im separaten Repo dokumentiert:
> **https://github.com/HerzigGroup/claude_code_local**

## Lokales Modell nutzen (`claude-qwen`)

In `~/.bashrc` ist ein Alias definiert, der Claude Code mit dem lokalen LiteLLM-Proxy startet:

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

**Umgebungsvariablen erklärt:**

| Variable | Wert | Bedeutung |
|----------|------|-----------|
| `ANTHROPIC_BASE_URL` | `http://132.180.21.140:4000` | LiteLLM-Proxy statt echte Anthropic-API |
| `ANTHROPIC_API_KEY` | `no-key` | Pflichtfeld, aber LiteLLM prüft es nicht |
| `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS` | `1` | Deaktiviert Beta-Features, die das lokale Modell nicht unterstützt |
| `API_TIMEOUT_MS` | `600000` | 10 Min. Timeout — lokale Inferenz kann länger dauern als Cloud |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | `131072` | Passt zum 128k Kontextfenster des Modells |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `80` | Kompaktiert Kontext ab 80 % Auslastung |
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS` | `20480` | ~20k max. Ausgabe-Token |

**Verwendung:**
```bash
claude-qwen          # Startet Claude Code mit lokalem Modell
claude-qwen /path/to/project
```

---

## Websuche (MCP SearXNG)

Claude Code ist so konfiguriert, dass es SearXNG als Websuch-Tool nutzt (statt dem eingebauten WebSearch-Tool, das keinen Anthropic-API-Zugang hat).

**MCP-Server-Konfiguration** (`~/.claude.json`):
```json
"mcpServers": {
  "searxng": {
    "type": "http",
    "url": "http://132.180.21.140:8001/mcp"
  }
}
```

**CLAUDE.md Instruktion** (in `~/CLAUDE.md`):
- Immer `mcp__searxng__web_search` verwenden, nie das eingebaute Web Search Tool

**MCP-Tool-Name in Prompts:** `mcp__searxng__web_search`

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

## Modellnamen in LiteLLM

LiteLLM registriert mehrere Claude-Modellnamen — alle leiten auf denselben Qwen-Server weiter:

| Claude-Modellname | Interner Endpunkt |
|-------------------|-------------------|
| `claude-sonnet-4-6` | SGLang :30000 |
| `claude-opus-4-7` | SGLang :30000 |
| `claude-haiku-4-5-20251001` | SGLang :30000 |
| `claude-3-5-sonnet-20241022` | SGLang :30000 |

So kann Claude Code beliebige Modelle "auswählen", und alle landen beim selben lokalen Modell.
