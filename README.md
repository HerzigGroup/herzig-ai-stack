# Herzig Group AI Stack

Local AI infrastructure on the DGX Spark (NVIDIA GB10 / Grace Blackwell).
This repo documents all services, configurations, and startup scripts.

## Hardware

| Component | Details |
|-----------|---------|
| GPU | NVIDIA GB10 (Grace Blackwell, DGX Spark) |
| CUDA | 13.0 |
| Driver | 580.95.05 |
| IP (LAN) | 132.180.21.140 |
| IP (WLAN) | 10.42.0.231 |

## Model

| Property | Value |
|----------|-------|
| Model | Qwen3.6-35B-A3B-FP8 |
| Path | `~/models/Qwen3.6-35B-A3B-FP8` (~35 GB) |
| Quantization | FP8 |
| Context length | 262,144 tokens (262k) |
| Thinking | Yes (Qwen3 reasoning parser) |
| Tool calls | Yes (Qwen3 coder parser) |

## Services at a Glance

| Service | Port | Managed by | Purpose |
|---------|------|-----------|---------|
| SGLang Server | 30000 | Docker (`qwen36`) | Model inference, OpenAI API |
| LiteLLM Proxy | 4000 | systemd (`litellm`) | Anthropic API compatibility |
| SearXNG | 8080 | Docker Compose (`~/searxng`) | Meta search engine |
| SearXNG MCP | 8001 | systemd (`mcp-searxng`) | Web search for Claude Code |
| Open-WebUI | 3000 | Docker Compose (`~/open-webui`) | Chat frontend |
| SGLang-Proxy | internal | Docker (`sglang-proxy`) | No-think mode for Open-WebUI |
| PostgreSQL | 5432 | Docker (`litellm-db`) | LiteLLM database |

## Architecture (Summary)

```
Claude Code (claude-qwen)
    └─► LiteLLM :4000  (Anthropic→OpenAI translation)
            └─► SGLang :30000  (Qwen3.6-35B inference)

Open-WebUI :3000
    ├─► SGLang :30000          (model with thinking)
    ├─► SGLang-Proxy :8000     (model without thinking)
    └─► SearXNG :8080          (web search)

Claude Code MCP
    └─► mcp-searxng :8001
            └─► SearXNG :8080
```

Detailed architecture: [docs/architecture.md](docs/architecture.md)

## Quickstart: Starting Everything

```bash
# 1. Load model (takes 2–5 min.)
~/start_qwen36.sh

# 2. SearXNG
cd ~/searxng && docker compose up -d

# 3. Open-WebUI + Proxy
cd ~/open-webui && docker compose up -d

# 4. LiteLLM
sudo systemctl start litellm

# 5. MCP for Claude Code
sudo systemctl start mcp-searxng
```

After a reboot, all services start automatically (via `restart: unless-stopped` or systemd).

## Claude Code with Local Model

```bash
claude-qwen          # Starts Claude Code with Qwen via LiteLLM
```

The alias is defined in `~/.bashrc`. Details: [docs/claude-code-setup.md](docs/claude-code-setup.md)

## Managing Services

```bash
# Check status
docker ps
systemctl status litellm
systemctl status mcp-searxng

# Logs
docker logs -f qwen36
journalctl -u litellm -f
journalctl -u mcp-searxng -f

# Restart individual services
docker restart qwen36
sudo systemctl restart litellm
cd ~/open-webui && docker compose restart
```

## Repo Structure

```
herzig-ai-stack/
├── README.md                        # This file
├── docs/
│   ├── architecture.md              # System architecture with ASCII diagrams
│   ├── services.md                  # All services with parameters explained
│   ├── claude-code-setup.md         # Claude Code configuration
│   └── common-changes.md            # Common changes cookbook
├── sglang/
│   └── start.sh                     # Start SGLang container
├── litellm/
│   ├── config.yaml                  # LiteLLM configuration
│   └── litellm.service              # systemd service file
├── searxng/
│   ├── docker-compose.yml           # SearXNG Docker Compose
│   ├── config/settings.yml          # SearXNG settings
│   ├── mcp_server.py                # MCP server script
│   └── mcp-searxng.service          # systemd service file
└── open-webui/
    ├── docker-compose.yml           # Open-WebUI + SGLang-Proxy
    ├── .env.example                 # Environment variables (template)
    └── sglang-proxy/
        ├── Dockerfile               # Proxy image
        └── proxy.py                 # FastAPI proxy (no-think mode)
```

## Configuration Files — Where Things Live

| File in Repo | System Path | Description |
|-------------|-------------|-------------|
| `sglang/start.sh` | `~/start_qwen36.sh` | SGLang startup script |
| `litellm/config.yaml` | `~/litellm_config.yaml` | LiteLLM configuration |
| `litellm/litellm.service` | `/etc/systemd/system/litellm.service` | LiteLLM service |
| `searxng/docker-compose.yml` | `~/searxng/docker-compose.yml` | SearXNG Compose |
| `searxng/config/settings.yml` | `~/searxng/config/settings.yml` | SearXNG settings |
| `searxng/mcp_server.py` | `~/searxng/mcp_server.py` | MCP server script |
| `searxng/mcp-searxng.service` | `/etc/systemd/system/mcp-searxng.service` | MCP service |
| `open-webui/docker-compose.yml` | `~/open-webui/docker-compose.yml` | WebUI Compose |
| `open-webui/.env.example` | `~/open-webui/.env` | WebUI environment variables |
| `open-webui/sglang-proxy/proxy.py` | `~/open-webui/sglang-proxy/proxy.py` | Proxy script |

> **Sync:** `sglang/start.sh` and `litellm/config.yaml` are **symlinked** from the home directory — changes in the repo take effect immediately (restart the service/container to apply).
> For all other files run `bash sync-server.sh` (shows divergence) or `bash sync-server.sh --deploy` (copies changed files).

## Further Documentation

- [docs/architecture.md](docs/architecture.md) — Detailed architecture and networks
- [docs/services.md](docs/services.md) — All services with full parameter reference
- [docs/claude-code-setup.md](docs/claude-code-setup.md) — Claude Code integration (setup details: [claude_code_local](https://github.com/HerzigGroup/claude_code_local))
- [docs/common-changes.md](docs/common-changes.md) — Cookbook for common changes
