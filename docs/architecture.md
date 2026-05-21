# System Architecture

## Overview

```
                        ┌─────────────────────────────────────────┐
                        │       Docker network: searxng_default    │
                        │                                         │
  Browser/Client        │  ┌──────────────┐   ┌───────────────┐  │
  Port 3000 ───────────►│  │  open-webui  │──►│  qwen36       │  │
                        │  │  (Port 3000) │   │  SGLang       │  │
  Claude Code           │  └──────┬───────┘   │  Port 30000   │  │
  (claude-qwen) ────────┼─────────┼───────────►               │  │
  Port 4000 via LiteLLM │         │           └───────────────┘  │
                        │  ┌──────▼───────┐   ┌───────────────┐  │
                        │  │  searxng     │   │  sglang-proxy │  │
                        │  │  Port 8080   │   │  Port 8000    │  │
                        │  └──────────────┘   └───────────────┘  │
                        └─────────────────────────────────────────┘

  Claude Code MCP ─────► mcp-searxng (Port 8001, systemd)
                              │
                              └──► searxng:8080

  LiteLLM Proxy ──────► localhost:30000/v1 (SGLang, outside Docker)
  (systemd, Port 4000)

  PostgreSQL ──────────► 127.0.0.1:5432 (litellm-db, Docker)
```

## Data Flow

### Claude Code → Local Model
1. `claude-qwen` sets `ANTHROPIC_BASE_URL=http://132.180.21.140:4000`
2. Claude Code sends requests in Anthropic format to LiteLLM (port 4000)
3. LiteLLM translates Anthropic API → OpenAI format and forwards to SGLang (port 30000)
4. SGLang runs inference on the NVIDIA GB10 GPU (Qwen3.6-35B-A3B-FP8)
5. Response travels back the same way

### Claude Code → Web Search
1. Claude Code uses MCP tool `mcp__searxng__web_search`
2. MCP server (port 8001, systemd) receives the request
3. MCP server queries SearXNG API (port 8080)
4. Result returned to Claude Code

### Open-WebUI → Model (with thinking)
1. Browser opens port 3000 → Open-WebUI
2. Open-WebUI sends directly to `http://qwen36:30000/v1` (via Docker network)
3. Model `Qwen36_35B_A3B` with reasoning active

### Open-WebUI → Model (without thinking)
1. Open-WebUI uses model `Qwen36_35B_A3B_no-think`
2. Request goes to sglang-proxy (port 8000 internal)
3. sglang-proxy appends `chat_template_kwargs: {enable_thinking: false}`
4. Forwarded to qwen36:30000

## Networks

| Network | Type | Members |
|---------|------|---------|
| `searxng_default` | Docker bridge | searxng, qwen36, sglang-proxy, open-webui |
| `bridge` (default) | Docker bridge | litellm-db |
| Host network | — | LiteLLM (systemd), mcp-searxng (systemd) |

## Ports (externally accessible)

| Port | Service | Accessible from |
|------|---------|----------------|
| 3000 | Open-WebUI | Network (0.0.0.0) |
| 4000 | LiteLLM Proxy (Anthropic API) | Network (0.0.0.0) |
| 8001 | SearXNG MCP Server | Network (0.0.0.0) |
| 8080 | SearXNG Web UI | Network (0.0.0.0) |
| 30000 | SGLang / OpenAI API | Network (0.0.0.0) |
| 5432 | PostgreSQL (LiteLLM DB) | localhost only |
