# Common Changes

## Swap the Model

1. Download the new model to `~/models/` (e.g. with `huggingface-cli download`)
2. Update `sglang/start.sh`:
   - Set `MODEL_DIR` to the new path
   - Rename `--served-model-name` if needed
   - Check `--reasoning-parser` and `--tool-call-parser` (model-dependent)
3. In `litellm/config.yaml`: update the `model` path if relevant
4. Restart the container: `docker stop qwen36 && docker rm qwen36 && ./sglang/start.sh`

## Change Context Length

In `sglang/start.sh`:
```bash
--context-length 262144   # Adjust value (e.g. 131072 for 128k)
```
Also update `CLAUDE_CODE_AUTO_COMPACT_WINDOW` in the `claude-qwen` alias (in `claude_code_local/setup.sh`) and in `litellm/config.yaml` (`context_window`).

## Disable Thinking Mode for a Model Alias

Thinking is currently disabled for `claude-haiku-4-5-20251001` (see `litellm/config.yaml`).
To disable thinking for another model alias, three entries are required together — using only `enable_thinking: false` will cause 500 errors when Claude Code sends thinking-related beta headers:

```yaml
model_list:
  - model_name: your-model-alias
    litellm_params:
      ...
      drop_params: ["tool_choice", "thinking", "budget_tokens"]
      extra_body:
        chat_template_kwargs:
          enable_thinking: false
    model_info:
      supports_reasoning: false   # prevents LiteLLM from routing to /v1/responses
```

**Why all three are needed:** Claude Code sends `anthropic-beta: interleaved-thinking-2025-05-14` for haiku-class models, which triggers LiteLLM's internal Responses API routing (`_route_openai_thinking_to_responses_api_if_needed`). SGLang's `/v1/responses` endpoint only accepts `web_search_preview`/`code_interpreter` tool types — not `function` — causing a 500. `supports_reasoning: false` bypasses this routing; `drop_params` strips the conflicting thinking params before they reach SGLang.

To disable thinking globally (all models), add to `litellm_settings.default_params` instead:
```yaml
litellm_settings:
  default_params:
    extra_body:
      chat_template_kwargs:
        enable_thinking: false
```
Note: this does not need `model_info` because it applies after LiteLLM's routing decision.

## Add a New Search Engine in SearXNG

Add to `searxng/config/settings.yml` under `engines:`:
```yaml
  - name: startpage
    engine: startpage
```
Then restart the SearXNG container: `cd ~/searxng && docker compose restart`

## Port Changes

- **SGLang port** (30000): Update in `sglang/start.sh` (`PORT=`), `litellm/config.yaml` (`api_base`), `open-webui/.env` (`OPENAI_API_BASE_URL`), `open-webui/docker-compose.yml` (`SGLANG_URL`)
- **LiteLLM port** (4000): Update in `litellm/litellm.service` (`--port`), and in the `claude-qwen` alias in `~/.bashrc`
- **SearXNG port** (8080): Update in `searxng/docker-compose.yml`, `open-webui/.env`, `searxng/mcp-searxng.service` (`SEARXNG_URL`)
- **MCP port** (8001): Update in `searxng/mcp-searxng.service`, and in `~/.claude.json` (MCP URL)

## IP Address Changes

If the server's IP changes (e.g. after DHCP reassignment):
- `~/.claude.json`: update `mcpServers.searxng.url`
- `~/.bashrc`: update `ANTHROPIC_BASE_URL` in the `claude-qwen` alias
- Current: `132.180.21.140` (Ethernet) / `10.42.0.231` (WLAN)

## Adjust LiteLLM Parameters

In `litellm/config.yaml` under `litellm_settings.default_params`:
```yaml
temperature: 0.6    # Qwen3 recommendation for coding with thinking mode
top_p: 0.95        # Nucleus sampling
```

For per-model overrides, add a `temperature` value to each model's `litellm_params` entry.

## Add a New Service to the Docker Network

The `searxng_default` network connects all services:
```bash
docker network connect searxng_default <container-name>
```

Or add it to a `docker-compose.yml` under `networks:`:
```yaml
networks:
  searxng_default:
    external: true
```

## Restart Everything (after reboot)

All services are configured with `restart: unless-stopped` (Docker) or `Restart=on-failure` (systemd) and start automatically. To start manually:

```bash
# 1. SGLang (model loading takes ~2-5 min.)
~/start_qwen36.sh

# 2. SearXNG
cd ~/searxng && docker compose up -d

# 3. Open-WebUI + SGLang-Proxy
cd ~/open-webui && docker compose up -d

# 4. LiteLLM (systemd)
sudo systemctl start litellm

# 5. MCP server (systemd)
sudo systemctl start mcp-searxng
```
