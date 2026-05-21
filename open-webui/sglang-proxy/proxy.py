import httpx
import json
import os
from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse, JSONResponse

MODEL = os.getenv("SGLANG_MODEL", "/model")
MODEL_ALIAS = os.getenv("SGLANG_MODEL_ALIAS", "qwen3-no-think")
UPSTREAM = os.getenv("SGLANG_URL", "http://qwen36:30000")
DISABLE_THINKING = os.getenv("DISABLE_THINKING", "true").lower() == "true"

app = FastAPI()


@app.api_route("/v1/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def proxy(path: str, request: Request):
    headers = {k: v for k, v in request.headers.items() if k.lower() not in ("host", "transfer-encoding", "content-length")}
    headers["host"] = "qwen36:30000"

    content_type = request.headers.get("content-type", "application/json")
    headers["content-type"] = content_type

    content = await request.body()
    target = f"{UPSTREAM}/v1/{path}"

    skip_resp_headers = {"content-length", "transfer-encoding", "content-encoding"}

    if not content or request.method == "GET":
        async with httpx.AsyncClient(timeout=None) as client:
            resp = await client.request(
                request.method.upper(), target, headers=headers, content=content
            )
            body = resp.json()
            if path == "models":
                for m in body.get("data", []):
                    m["id"] = MODEL_ALIAS
            fwd = {k: v for k, v in resp.headers.items() if k.lower() not in skip_resp_headers}
            return JSONResponse(content=body, status_code=resp.status_code, headers=fwd)

    data = json.loads(content)
    data["model"] = MODEL
    if DISABLE_THINKING and path == "chat/completions":
        # Use tokenizer-level switch: prepends empty <think></think> block so model skips reasoning
        extra_body = data.setdefault("chat_template_kwargs", {})
        extra_body["enable_thinking"] = False

    stream = data.pop("stream", False)
    if stream:
        data["stream"] = True  # forward stream flag to upstream
        client = httpx.AsyncClient(timeout=None)
        req = client.build_request(request.method.upper(), target, json=data, headers=headers)
        resp = await client.send(req, stream=True)

        async def generate():
            try:
                async for chunk in resp.aiter_raw():
                    yield chunk
            finally:
                await resp.aclose()
                await client.aclose()

        fwd = {k: v for k, v in resp.headers.items() if k.lower() not in skip_resp_headers}
        return StreamingResponse(generate(), status_code=resp.status_code, headers=fwd, media_type="text/event-stream")

    async with httpx.AsyncClient(timeout=None) as client:
        resp = await client.request(
            request.method.upper(), target, json=data, headers=headers
        )
        fwd = {k: v for k, v in resp.headers.items() if k.lower() not in skip_resp_headers}
        return JSONResponse(content=resp.json(), status_code=resp.status_code, headers=fwd)
