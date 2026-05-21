# Herzig Group AI Stack

Lokale KI-Infrastruktur auf dem DGX Spark (NVIDIA GB10 / Grace Blackwell).
Dieses Repo dokumentiert alle Dienste, Konfigurationen und Startskripte.

## Hardware

| Komponente | Details |
|-----------|---------|
| GPU | NVIDIA GB10 (Grace Blackwell, DGX Spark) |
| CUDA | 13.0 |
| Treiber | 580.95.05 |
| IP (LAN) | 132.180.21.140 |
| IP (WLAN) | 10.42.0.231 |

## Modell

| Eigenschaft | Wert |
|------------|------|
| Modell | Qwen3.6-35B-A3B-FP8 |
| Pfad | `~/models/Qwen3.6-35B-A3B-FP8` (~35 GB) |
| Quantisierung | FP8 |
| Kontextlänge | 131.072 Tokens (128k) |
| Thinking | Ja (Qwen3 Reasoning Parser) |
| Tool Calls | Ja (Qwen3 Coder Parser) |

## Dienste auf einen Blick

| Dienst | Port | Verwaltung | Zweck |
|--------|------|-----------|-------|
| SGLang Server | 30000 | Docker (`qwen36`) | Modell-Inferenz, OpenAI-API |
| LiteLLM Proxy | 4000 | systemd (`litellm`) | Anthropic-API-Kompatibilität |
| SearXNG | 8080 | Docker Compose (`~/searxng`) | Meta-Suchmaschine |
| SearXNG MCP | 8001 | systemd (`mcp-searxng`) | Websuche für Claude Code |
| Open-WebUI | 3000 | Docker Compose (`~/open-webui`) | Chat-Frontend |
| SGLang-Proxy | intern | Docker (`sglang-proxy`) | No-Think-Modus für Open-WebUI |
| PostgreSQL | 5432 | Docker (`litellm-db`) | LiteLLM-Datenbank |

## Architektur (Kurzform)

```
Claude Code (claude-qwen)
    └─► LiteLLM :4000  (Anthropic→OpenAI Übersetzung)
            └─► SGLang :30000  (Qwen3.6-35B Inferenz)

Open-WebUI :3000
    ├─► SGLang :30000          (Modell mit Thinking)
    ├─► SGLang-Proxy :8000     (Modell ohne Thinking)
    └─► SearXNG :8080          (Websuche)

Claude Code MCP
    └─► mcp-searxng :8001
            └─► SearXNG :8080
```

Detaillierte Architektur: [docs/architecture.md](docs/architecture.md)

## Quickstart: Alles starten

```bash
# 1. Modell laden (dauert 2–5 Min.)
~/start_qwen36.sh

# 2. SearXNG
cd ~/searxng && docker compose up -d

# 3. Open-WebUI + Proxy
cd ~/open-webui && docker compose up -d

# 4. LiteLLM
sudo systemctl start litellm

# 5. MCP für Claude Code
sudo systemctl start mcp-searxng
```

Nach Reboot starten alle Dienste automatisch (via `restart: unless-stopped` bzw. systemd).

## Claude Code mit lokalem Modell

```bash
claude-qwen          # Startet Claude Code mit Qwen über LiteLLM
```

Alias ist in `~/.bashrc` definiert. Details: [docs/claude-code-setup.md](docs/claude-code-setup.md)

## Dienste verwalten

```bash
# Status prüfen
docker ps
systemctl status litellm
systemctl status mcp-searxng

# Logs
docker logs -f qwen36
journalctl -u litellm -f
journalctl -u mcp-searxng -f

# Einzelne Dienste neu starten
docker restart qwen36
sudo systemctl restart litellm
cd ~/open-webui && docker compose restart
```

## Repo-Struktur

```
herzig-ai-stack/
├── README.md                        # Diese Datei
├── docs/
│   ├── architecture.md              # Systemarchitektur mit ASCII-Diagrammen
│   ├── services.md                  # Alle Dienste mit Parametern erklärt
│   ├── claude-code-setup.md         # Claude Code Konfiguration
│   └── common-changes.md            # Häufige Änderungen (Kochbuch)
├── sglang/
│   └── start.sh                     # SGLang-Container starten
├── litellm/
│   ├── config.yaml                  # LiteLLM-Konfiguration
│   └── litellm.service              # systemd Service-Datei
├── searxng/
│   ├── docker-compose.yml           # SearXNG Docker Compose
│   ├── config/settings.yml          # SearXNG-Einstellungen
│   ├── mcp_server.py                # MCP-Server-Script
│   └── mcp-searxng.service          # systemd Service-Datei
└── open-webui/
    ├── docker-compose.yml           # Open-WebUI + SGLang-Proxy
    ├── .env.example                 # Umgebungsvariablen (Vorlage)
    └── sglang-proxy/
        ├── Dockerfile               # Proxy-Image
        └── proxy.py                 # FastAPI-Proxy (No-Think-Modus)
```

## Konfigurationsdateien — wo was liegt

| Datei im Repo | Systempfad | Beschreibung |
|--------------|------------|-------------|
| `sglang/start.sh` | `~/start_qwen36.sh` | SGLang-Startskript |
| `litellm/config.yaml` | `~/litellm_config.yaml` | LiteLLM-Konfiguration |
| `litellm/litellm.service` | `/etc/systemd/system/litellm.service` | LiteLLM-Service |
| `searxng/docker-compose.yml` | `~/searxng/docker-compose.yml` | SearXNG Compose |
| `searxng/config/settings.yml` | `~/searxng/config/settings.yml` | SearXNG-Einstellungen |
| `searxng/mcp_server.py` | `~/searxng/mcp_server.py` | MCP-Server-Script |
| `searxng/mcp-searxng.service` | `/etc/systemd/system/mcp-searxng.service` | MCP-Service |
| `open-webui/docker-compose.yml` | `~/open-webui/docker-compose.yml` | WebUI Compose |
| `open-webui/.env.example` | `~/open-webui/.env` | WebUI-Umgebungsvariablen |
| `open-webui/sglang-proxy/proxy.py` | `~/open-webui/sglang-proxy/proxy.py` | Proxy-Script |

> **Hinweis:** Änderungen im Repo müssen manuell in die Systempfade übertragen werden (oder Symlinks einrichten).

## Weitere Dokumentation

- [docs/architecture.md](docs/architecture.md) — Detaillierte Architektur und Netzwerke
- [docs/services.md](docs/services.md) — Alle Dienste mit vollständiger Parameterübersicht
- [docs/claude-code-setup.md](docs/claude-code-setup.md) — Claude Code Integration (Setup-Details: [claude_code_local](https://github.com/HerzigGroup/claude_code_local))
- [docs/common-changes.md](docs/common-changes.md) — Kochbuch für häufige Änderungen
