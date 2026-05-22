# Services in Detail

## 1. SGLang Server (`qwen36`)

**Purpose:** Runs the language model, provides an OpenAI-compatible API.

**Start:** `~/start_qwen36.sh` (starts Docker container or resumes it)

**Stop:** `docker stop qwen36`

**Logs:** `docker logs -f qwen36`

**Key parameters in `sglang/start.sh`:**

| Parameter | Value | Meaning |
|-----------|-------|---------|
| `--model-path` | `/model` | Path to the model inside the container (mounted from `~/models/Qwen3.6-35B-A3B-FP8`) |
| `--served-model-name` | `Qwen36_35B_A3B` | Name under which the model is exposed in the API |
| `--port` | `30000` | Port of the OpenAI API |
| `--tp-size` | `1` | Tensor parallelism (1 = no multi-GPU) |
| `--mem-fraction-static` | `0.80` | 80% of GPU memory reserved for KV cache |
| `--context-length` | `262144` | Max context length (262k tokens, full native context) |
| `--mamba-scheduler-strategy` | `extra_buffer` | Scheduling optimization for hybrid GDN/Mamba architecture |
| `--speculative-algo` | `NEXTN` | Multi-token prediction speculative decoding (~20–40% throughput gain) |
| `--speculative-num-steps` | `3` | Number of draft steps per speculative round |
| `--speculative-eagle-topk` | `1` | Top-k candidates per draft step |
| `--speculative-num-draft-tokens` | `4` | Draft tokens generated per step |
| `--reasoning-parser` | `qwen3` | Enables thinking mode (returns `<think>` blocks) |
| `--tool-call-parser` | `qwen3_coder` | Parses tool calls in Qwen3 format |

**Network:** After startup, the container is manually connected to the `searxng_default` Docker network (for open-webui access).

**Model on disk:** `~/models/Qwen3.6-35B-A3B-FP8` (~35 GB, FP8-quantized)

**Health check:** `curl http://localhost:30000/health`

---

## 2. LiteLLM Proxy

**Purpose:** Translates the Anthropic Claude API to the local SGLang server. Enables Claude Code to use the local model.

**Start/Stop:** `sudo systemctl start|stop|restart litellm`

**Status:** `systemctl status litellm`

**Logs:** `journalctl -u litellm -f`

**Config:** `~/litellm_config.yaml` (or `litellm/config.yaml` in this repo)

**Key configuration details:**

- Registered model names: `claude-sonnet-4-6`, `claude-opus-4-7`, `claude-haiku-4-5-20251001`, `claude-3-5-sonnet-20241022` — all point to the same SGLang endpoint
- `claude-haiku-4-5-20251001` has thinking disabled (`enable_thinking: false`) — used by Claude Code for fast internal ops where thinking is unnecessary overhead. **Important:** two additional config entries are required to make this work correctly:
  - `model_info: {supports_reasoning: false}` — Claude Code sends `anthropic-beta: interleaved-thinking-2025-05-14` specifically for haiku-4-5, which triggers a second routing path in LiteLLM (`_route_openai_thinking_to_responses_api_if_needed`). Without this flag, LiteLLM routes the request to SGLang's `/v1/responses` endpoint, which rejects `type: function` tool definitions with a 500 error. The flag has an explicit early-exit that bypasses the Responses API routing.
  - `drop_params: [thinking, budget_tokens]` — defense-in-depth: strips the thinking parameters before they reach SGLang, preventing conflicts with `enable_thinking: false`
- `merge_reasoning_content_in_choices: false` — thinking content is returned as a separate `reasoning_content` field; not stored in conversation history → less context consumption, no verbose dump in Claude Code console
- `drop_params: ["tool_choice"]` — SGLang/Qwen does not support this parameter
- `max_tokens: 32768` — maximum output token count
- `context_window: 262144` — tells LiteLLM the actual context size for this backend
- `temperature: 0.6`, `top_p: 0.95` — Qwen3 recommended settings for coding with thinking mode
- `request_timeout: 300` — 5-minute timeout for long requests
- `use_chat_completions_url_for_anthropic_messages: true` — required for Anthropic Messages API compatibility

**Installation (if setting up from scratch):**
```bash
python3 -m venv ~/litellm_env
~/litellm_env/bin/pip install litellm
sudo cp litellm/litellm.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now litellm
```

**PostgreSQL database (litellm-db):**
- Container: `litellm-db` (postgres:16-alpine)
- Port: 5432 (localhost only)
- Database: `litellm`, user: `litellm`
- Start: `docker start litellm-db`
- Note: The DB is used for logging/usage tracking but is not strictly required for proxy operation.

---

## 3. SearXNG

**Purpose:** Local meta search engine. Used by Open-WebUI (web search) and Claude Code (via MCP).

**Start:** `cd ~/searxng && docker compose up -d`

**Stop:** `cd ~/searxng && docker compose down`

**Logs:** `docker logs -f searxng`

**Web UI:** http://localhost:8080

**Config:** `~/searxng/config/settings.yml` (or `searxng/config/settings.yml` in this repo)

**Enabled search engines:** Google, Bing, DuckDuckGo, Wikipedia (DE)

**API endpoint for search:** `http://localhost:8080/search?q=<query>&format=json`

---

## 4. SearXNG MCP Server

**Purpose:** Exposes SearXNG as an MCP tool for Claude Code (`mcp__searxng__web_search`).

**Start/Stop:** `sudo systemctl start|stop mcp-searxng`

**Logs:** `journalctl -u mcp-searxng -f`

**Endpoint:** `http://132.180.21.140:8001/mcp` (Streamable HTTP)

**Script:** `~/searxng/mcp_server.py`

**Claude Code configuration** (in `~/.claude.json`):
```json
"mcpServers": {
  "searxng": {
    "type": "http",
    "url": "http://132.180.21.140:8001/mcp"
  }
}
```

**Installation (if setting up from scratch):**
```bash
pip3 install mcp fastmcp requests
sudo cp searxng/mcp-searxng.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now mcp-searxng
```

---

## 5. Open-WebUI

**Purpose:** Web frontend for chatting with the local model. Includes web search and file upload.

**Start:** `cd ~/open-webui && docker compose up -d`

**Stop:** `cd ~/open-webui && docker compose down`

**Logs:** `docker logs -f open-webui`

**Web UI:** http://localhost:3000

**Configuration** (`~/open-webui/.env`):
- Connects directly to SGLang: `OPENAI_API_BASE_URL=http://qwen36:30000/v1`
- Web search via SearXNG enabled

**Volumes:** Open-WebUI data (user profiles, conversations) is stored in a Docker volume `open-webui`.

---

## 6. SGLang-Proxy (sidecar in open-webui)

**Purpose:** Proxy that optionally disables thinking mode for Open-WebUI. Exposes the model under the alias `Qwen36_35B_A3B_no-think`.

**Code:** `~/open-webui/sglang-proxy/proxy.py`

**Environment variables** (in `open-webui/docker-compose.yml`):

| Variable | Value | Meaning |
|----------|-------|---------|
| `SGLANG_URL` | `http://qwen36:30000` | SGLang upstream |
| `SGLANG_MODEL` | `Qwen36_35B_A3B` | Internal model name for upstream |
| `SGLANG_MODEL_ALIAS` | `Qwen36_35B_A3B_no-think` | Name exposed in the API |
| `DISABLE_THINKING` | `true` | Sets `enable_thinking: false` via `chat_template_kwargs` |

**How thinking is disabled:** The model is instructed via `chat_template_kwargs: {enable_thinking: false}` to skip the `<think>` block (tokenizer-level switch, not a prompt hack).
