# Dienste im Detail

## 1. SGLang Server (`qwen36`)

**Zweck:** Führt das Sprachmodell aus, stellt eine OpenAI-kompatible API bereit.

**Start:** `~/start_qwen36.sh` (startet Docker-Container oder resumed ihn)

**Stopp:** `docker stop qwen36`

**Logs:** `docker logs -f qwen36`

**Wichtige Parameter in `sglang/start.sh`:**

| Parameter | Wert | Bedeutung |
|-----------|------|-----------|
| `--model-path` | `/model` | Pfad zum Modell im Container (gemountet von `~/models/Qwen3.6-35B-A3B-FP8`) |
| `--served-model-name` | `Qwen36_35B_A3B` | Name, unter dem das Modell in der API erscheint |
| `--port` | `30000` | Port der OpenAI-API |
| `--tp-size` | `1` | Tensor-Parallelismus (1 = kein Multi-GPU) |
| `--mem-fraction-static` | `0.80` | 80 % des GPU-Speichers für KV-Cache |
| `--context-length` | `131072` | Max. Kontextlänge (128k Tokens) |
| `--reasoning-parser` | `qwen3` | Aktiviert Thinking-Modus (gibt `<think>` Blöcke zurück) |
| `--tool-call-parser` | `qwen3_coder` | Parst Tool-Calls im Qwen3-Format |

**Netzwerk:** Nach dem Start wird der Container manuell in das `searxng_default` Docker-Netzwerk eingebunden (für open-webui-Zugang).

**Modell auf Disk:** `~/models/Qwen3.6-35B-A3B-FP8` (~35 GB, FP8-quantisiert)

**Gesundheitsprüfung:** `curl http://localhost:30000/health`

---

## 2. LiteLLM Proxy

**Zweck:** Übersetzt die Anthropic Claude API auf den lokalen SGLang-Server. Ermöglicht die Nutzung von Claude Code mit lokalem Modell.

**Start/Stopp:** `sudo systemctl start|stop|restart litellm`

**Status:** `systemctl status litellm`

**Logs:** `journalctl -u litellm -f`

**Config:** `~/litellm_config.yaml` (bzw. `litellm/config.yaml` in diesem Repo)

**Wichtige Konfigurationsdetails:**

- Registrierte Modellnamen: `claude-sonnet-4-6`, `claude-opus-4-7`, `claude-haiku-4-5-20251001`, `claude-3-5-sonnet-20241022` — alle zeigen auf denselben SGLang-Endpunkt
- `merge_reasoning_content_in_choices: true` — Thinking-Inhalt wird in die normale Antwort eingebettet (Anthropic-API-kompatibel)
- `drop_params: ["tool_choice"]` — SGLang/Qwen unterstützt diesen Parameter nicht
- `max_tokens: 16384` — Maximale Output-Token-Anzahl
- `temperature: 0.3`, `top_p: 0.9` — Qwen3-optimierte Sampling-Parameter
- `request_timeout: 300` — 5 Min. Timeout für lange Anfragen
- `use_chat_completions_url_for_anthropic_messages: true` — nötig für Anthropic-Messages-API-Kompatibilität

**Installation (falls neu aufsetzen):**
```bash
python3 -m venv ~/litellm_env
~/litellm_env/bin/pip install litellm
sudo cp litellm/litellm.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now litellm
```

**PostgreSQL-Datenbank (litellm-db):**
- Container: `litellm-db` (postgres:16-alpine)
- Port: 5432 (nur localhost)
- Datenbank: `litellm`, User: `litellm`
- Start: `docker start litellm-db`
- Hinweis: Die DB wird für Logging/Usage-Tracking genutzt, ist aber nicht zwingend erforderlich für den Proxy-Betrieb.

---

## 3. SearXNG

**Zweck:** Lokale Meta-Suchmaschine. Wird von Open-WebUI (Websuche) und Claude Code (über MCP) genutzt.

**Start:** `cd ~/searxng && docker compose up -d`

**Stopp:** `cd ~/searxng && docker compose down`

**Logs:** `docker logs -f searxng`

**Web-UI:** http://localhost:8080

**Config:** `~/searxng/config/settings.yml` (bzw. `searxng/config/settings.yml` in diesem Repo)

**Aktivierte Suchmaschinen:** Google, Bing, DuckDuckGo, Wikipedia (DE)

**API-Endpoint für Suche:** `http://localhost:8080/search?q=<query>&format=json`

---

## 4. SearXNG MCP Server

**Zweck:** Stellt SearXNG als MCP-Tool für Claude Code bereit (`mcp__searxng__web_search`).

**Start/Stopp:** `sudo systemctl start|stop mcp-searxng`

**Logs:** `journalctl -u mcp-searxng -f`

**Endpoint:** `http://132.180.21.140:8001/mcp` (Streamable HTTP)

**Script:** `~/searxng/mcp_server.py`

**Claude Code Konfiguration** (in `~/.claude.json`):
```json
"mcpServers": {
  "searxng": {
    "type": "http",
    "url": "http://132.180.21.140:8001/mcp"
  }
}
```

**Installation (falls neu aufsetzen):**
```bash
pip3 install mcp fastmcp requests
sudo cp searxng/mcp-searxng.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now mcp-searxng
```

---

## 5. Open-WebUI

**Zweck:** Web-Frontend für den Chat mit dem lokalen Modell. Inkl. Websuche und Datei-Upload.

**Start:** `cd ~/open-webui && docker compose up -d`

**Stopp:** `cd ~/open-webui && docker compose down`

**Logs:** `docker logs -f open-webui`

**Web-UI:** http://localhost:3000

**Konfiguration** (`~/open-webui/.env`):
- Verbindet sich direkt mit SGLang: `OPENAI_API_BASE_URL=http://qwen36:30000/v1`
- Websuche über SearXNG aktiviert

**Volumes:** Open-WebUI-Daten (Nutzerprofile, Gespräche) liegen in einem Docker-Volume `open-webui`.

---

## 6. SGLang-Proxy (sidecar in open-webui)

**Zweck:** Proxy, der den Thinking-Modus für Open-WebUI optional deaktiviert. Stellt das Modell unter dem Alias `Qwen36_35B_A3B_no-think` bereit.

**Code:** `~/open-webui/sglang-proxy/proxy.py`

**Umgebungsvariablen** (in `open-webui/docker-compose.yml`):

| Variable | Wert | Bedeutung |
|----------|------|-----------|
| `SGLANG_URL` | `http://qwen36:30000` | SGLang-Upstream |
| `SGLANG_MODEL` | `Qwen36_35B_A3B` | Interner Modellname für Upstream |
| `SGLANG_MODEL_ALIAS` | `Qwen36_35B_A3B_no-think` | Name, der in der API erscheint |
| `DISABLE_THINKING` | `true` | Setzt `enable_thinking: false` via `chat_template_kwargs` |

**Wie Thinking deaktiviert wird:** Das Modell wird via `chat_template_kwargs: {enable_thinking: false}` angewiesen, den `<think>` Block zu überspringen (Tokenizer-Level-Schalter, kein Prompt-Hack).
