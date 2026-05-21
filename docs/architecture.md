# Systemarchitektur

## Überblick

```
                        ┌─────────────────────────────────────────┐
                        │          Docker-Netzwerk: searxng_default│
                        │                                         │
  Browser/Client        │  ┌──────────────┐   ┌───────────────┐  │
  Port 3000 ───────────►│  │  open-webui  │──►│  qwen36       │  │
                        │  │  (Port 8080) │   │  SGLang       │  │
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

  LiteLLM Proxy ──────► localhost:30000/v1 (SGLang, außerhalb Docker)
  (systemd, Port 4000)

  PostgreSQL ──────────► 127.0.0.1:5432 (litellm-db, Docker)
```

## Datenfluss

### Claude Code → Lokales Modell
1. `claude-qwen` setzt `ANTHROPIC_BASE_URL=http://132.180.21.140:4000`
2. Claude Code sendet Anfragen im Anthropic-Format an LiteLLM (Port 4000)
3. LiteLLM übersetzt Anthropic-API → OpenAI-Format und leitet weiter an SGLang (Port 30000)
4. SGLang führt Inferenz auf dem NVIDIA GB10 GPU aus (Qwen3.6-35B-A3B-FP8)
5. Antwort läuft den gleichen Weg zurück

### Claude Code → Websuche
1. Claude Code nutzt MCP-Tool `mcp__searxng__web_search`
2. MCP-Server (Port 8001, systemd) empfängt Anfrage
3. MCP-Server ruft SearXNG-API (Port 8080) ab
4. Ergebnis zurück an Claude Code

### Open-WebUI → Modell (mit Thinking)
1. Browser öffnet Port 3000 → Open-WebUI
2. Open-WebUI sendet direkt an `http://qwen36:30000/v1` (via Docker-Netzwerk)
3. Modell `Qwen36_35B_A3B` mit Reasoning aktiv

### Open-WebUI → Modell (ohne Thinking)
1. Open-WebUI nutzt Modell `Qwen36_35B_A3B_no-think`
2. Anfrage geht an sglang-proxy (Port 8000 intern)
3. sglang-proxy fügt `chat_template_kwargs: {enable_thinking: false}` hinzu
4. Weiterleitung an qwen36:30000

## Netzwerke

| Netzwerk | Typ | Mitglieder |
|----------|-----|------------|
| `searxng_default` | Docker bridge | searxng, qwen36, sglang-proxy, open-webui |
| `bridge` (default) | Docker bridge | litellm-db |
| Host-Netzwerk | — | LiteLLM (systemd), mcp-searxng (systemd) |

## Ports (von außen erreichbar)

| Port | Dienst | Zugänglich von |
|------|--------|----------------|
| 3000 | Open-WebUI | Netz (0.0.0.0) |
| 4000 | LiteLLM Proxy (Anthropic-API) | Netz (0.0.0.0) |
| 8001 | SearXNG MCP Server | Netz (0.0.0.0) |
| 8080 | SearXNG Web-UI | Netz (0.0.0.0) |
| 30000 | SGLang / OpenAI-API | Netz (0.0.0.0) |
| 5432 | PostgreSQL (LiteLLM-DB) | nur localhost |
