#!/bin/bash
# SGLang server for Qwen3.6-35B-A3B-FP8
# DGX Spark / GB10 Grace Blackwell — via Docker (no local build required)

MODEL_DIR=/home/herzig_group/models/Qwen3.6-35B-A3B-FP8
PORT=30000
IMAGE=lmsysorg/sglang:latest-cu130-runtime
CONTAINER=qwen36

# If the container already exists (stopped), just start it
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "Container '${CONTAINER}' already exists — starting it..."
  docker start "${CONTAINER}"
else
  echo "Creating and starting container '${CONTAINER}'..."
  docker run -d \
    --name "${CONTAINER}" \
    --restart unless-stopped \
    --gpus all \
    --ipc=host \
    --ulimit memlock=-1 \
    -v "$MODEL_DIR":/model:ro \
    -p ${PORT}:${PORT} \
    "$IMAGE" \
    python3 -m sglang.launch_server \
      --model-path /model \
      --served-model-name Qwen36_35B_A3B \
      --port ${PORT} \
      --host 0.0.0.0 \
      --tp-size 1 \
      --mem-fraction-static 0.80 \
      --context-length 131072 \
      --reasoning-parser qwen3 \
      --tool-call-parser qwen3_coder
fi

echo ""
echo "Connecting qwen36 to searxng_default network..."
docker network connect searxng_default "${CONTAINER}" 2>/dev/null || true

echo "Server starting... waiting for /health"
for i in $(seq 1 60); do
  if curl -sf http://localhost:${PORT}/health >/dev/null 2>&1; then
    echo "Server ready: http://localhost:${PORT}"
    break
  fi
  sleep 5
done
