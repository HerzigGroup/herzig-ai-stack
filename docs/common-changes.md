# Häufige Änderungen

## Modell wechseln

1. Neues Modell nach `~/models/` herunterladen (z.B. mit `huggingface-cli download`)
2. In `sglang/start.sh` anpassen:
   - `MODEL_DIR` auf den neuen Pfad setzen
   - `--served-model-name` ggf. umbenennen
   - `--reasoning-parser` und `--tool-call-parser` prüfen (modellabhängig)
3. In `litellm/config.yaml`: `served-model-name` in `api_base` bzw. den `model`-Pfad anpassen (falls relevant)
4. Container neu starten: `docker stop qwen36 && docker rm qwen36 && ./sglang/start.sh`

## Kontext-Länge ändern

In `sglang/start.sh`:
```bash
--context-length 131072   # Wert anpassen (z.B. 65536 für 64k)
```
Auch `CLAUDE_CODE_AUTO_COMPACT_WINDOW` im `claude-qwen`-Alias anpassen.

## Thinking-Modus standardmäßig deaktivieren (SGLang-weite Einstellung)

Aktuell wird Thinking für Claude Code über LiteLLM nicht explizit gesteuert — es ist im Modell aktiv. Soll es global deaktiviert werden, kann in `litellm/config.yaml` ergänzt werden:
```yaml
default_params:
  extra_body:
    chat_template_kwargs:
      enable_thinking: false
```

## Neue Suchmaschine in SearXNG hinzufügen

In `searxng/config/settings.yml` unter `engines:` eintragen:
```yaml
  - name: startpage
    engine: startpage
```
Danach SearXNG-Container neu starten: `cd ~/searxng && docker compose restart`

## Port-Änderungen

- **SGLang-Port** (30000): In `sglang/start.sh` (`PORT=`), in `litellm/config.yaml` (`api_base`), in `open-webui/.env` (`OPENAI_API_BASE_URL`), in `open-webui/docker-compose.yml` (`SGLANG_URL`)
- **LiteLLM-Port** (4000): In `litellm/litellm.service` (`--port`), im `claude-qwen`-Alias in `~/.bashrc`
- **SearXNG-Port** (8080): In `searxng/docker-compose.yml`, in `open-webui/.env`, in `searxng/mcp-searxng.service` (`SEARXNG_URL`)
- **MCP-Port** (8001): In `searxng/mcp-searxng.service`, in `~/.claude.json` (MCP-URL)

## IP-Adresse ändert sich

Wenn die IP des Servers sich ändert (z.B. nach DHCP-Wechsel):
- `~/.claude.json`: `mcpServers.searxng.url` aktualisieren
- `~/.bashrc`: `ANTHROPIC_BASE_URL` im `claude-qwen`-Alias aktualisieren
- Aktuell: `132.180.21.140` (Ethernet) / `10.42.0.231` (WLAN)

## LiteLLM-Parameter anpassen

In `litellm/config.yaml` unter `litellm_settings.default_params`:
```yaml
temperature: 0.3    # Kreativität (0.0 = deterministisch, 1.0 = kreativ)
top_p: 0.9         # Nucleus-Sampling (Alternative zu temperature)
```

Für spezifische Modell-Overrides kann jedem Modell in `litellm_params` ein eigener `temperature`-Wert gegeben werden.

## Neuen Dienst zum Docker-Netzwerk hinzufügen

Das Netzwerk `searxng_default` verbindet alle Dienste:
```bash
docker network connect searxng_default <container-name>
```

Oder in einer `docker-compose.yml` unter `networks:` eintragen:
```yaml
networks:
  searxng_default:
    external: true
```

## Alles neu starten (nach Reboot)

Die Dienste sind alle mit `restart: unless-stopped` (Docker) bzw. `Restart=on-failure` (systemd) konfiguriert und starten automatisch. Manuell:

```bash
# 1. SGLang (Modell laden dauert ~2-5 Min.)
~/start_qwen36.sh

# 2. SearXNG
cd ~/searxng && docker compose up -d

# 3. Open-WebUI + SGLang-Proxy
cd ~/open-webui && docker compose up -d

# 4. LiteLLM (systemd)
sudo systemctl start litellm

# 5. MCP-Server (systemd)
sudo systemctl start mcp-searxng
```
