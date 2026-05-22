# Accessing the AI Server

How to connect to the Herzig Group AI server from your own machine.
Requires access to the university network (LAN or VPN).

## Endpoints

| Service | Port | Protocol | Use case |
|---------|------|----------|----------|
| LiteLLM Proxy | 4000 | Anthropic-compatible | Claude Code, Anthropic SDK |
| SGLang | 30000 | OpenAI-compatible | OpenAI SDK, curl, VS Code extensions |

**Server IPs**
- LAN (office): `132.180.21.140`
- WLAN (fallback): `10.42.0.231`

**Authentication:** No real API key is required — any non-empty string works (e.g. `"no-key"`).

---

## Claude Code CLI

The recommended way for developers. The repo [**HerzigGroup/claude_code_local**](https://github.com/HerzigGroup/claude_code_local) contains everything needed:
- `setup.sh` — automated setup for Linux/macOS
- `setup.ps1` — setup for Windows
- Full README with troubleshooting

After setup, run `claude-qwen` instead of `claude` to use the local model.

---

## curl

Quick test or scripting. Two options depending on which endpoint you target:

**Via LiteLLM (Anthropic message format, port 4000)**
```bash
curl http://132.180.21.140:4000/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: no-key" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "model": "claude-sonnet-4-6",
    "max_tokens": 1024,
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

**Via SGLang directly (OpenAI chat completions format, port 30000)**
```bash
curl http://132.180.21.140:30000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer no-key" \
  -d '{
    "model": "Qwen36_35B_A3B",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

---

## Python — Anthropic SDK

Uses the LiteLLM proxy on port 4000. Model names are the familiar Claude aliases (all route to Qwen3.6 internally).

```python
import anthropic  # pip install anthropic

client = anthropic.Anthropic(
    base_url="http://132.180.21.140:4000",
    api_key="no-key",
)

message = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Hello!"}],
)
print(message.content[0].text)
```

Available model aliases: `claude-sonnet-4-6`, `claude-opus-4-7`, `claude-haiku-4-5-20251001`, `claude-3-5-sonnet-20241022`

---

## Python — OpenAI SDK

Uses SGLang directly on port 30000.

```python
from openai import OpenAI  # pip install openai

client = OpenAI(
    base_url="http://132.180.21.140:30000/v1",
    api_key="no-key",
)

response = client.chat.completions.create(
    model="Qwen36_35B_A3B",
    messages=[{"role": "user", "content": "Hello!"}],
)
print(response.choices[0].message.content)
```

---

## VS Code Extensions (Continue, Cline, etc.)

Any extension that supports an OpenAI-compatible endpoint works. Point it to SGLang on port 30000:

| Setting | Value |
|---------|-------|
| Provider | OpenAI-compatible / Custom |
| Base URL | `http://132.180.21.140:30000/v1` |
| API Key | `no-key` (any non-empty string) |
| Model | `Qwen36_35B_A3B` |

**Continue** (`~/.continue/config.json` or via GUI):
```json
{
  "models": [
    {
      "title": "Qwen3.6 (HerzigGroup)",
      "provider": "openai",
      "model": "Qwen36_35B_A3B",
      "apiBase": "http://132.180.21.140:30000/v1",
      "apiKey": "no-key"
    }
  ]
}
```

**Cline**: Settings → API Provider → *OpenAI Compatible* → paste base URL and model name above.
