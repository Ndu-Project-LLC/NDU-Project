#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MODEL="${LLM_MODEL:-ndu-assistant:latest}"
PORT="${LLM_PORT:-8080}"

if ! command -v ollama >/dev/null 2>&1; then
  echo "Ollama is required. Install it from https://ollama.com/download" >&2
  exit 1
fi

if ! ollama list >/dev/null 2>&1; then
  echo "Starting Ollama..."
  ollama serve >/tmp/ndu-ollama.log 2>&1 &
  OLLAMA_PID=$!
  cleanup_ollama() {
    kill "$OLLAMA_PID" 2>/dev/null || true
  }
  trap cleanup_ollama EXIT INT TERM

  ready=0
  for _ in $(seq 1 60); do
    if ollama list >/dev/null 2>&1; then
      ready=1
      break
    fi
    sleep 1
  done
  if [ "$ready" -ne 1 ]; then
    echo "Ollama did not become ready. See /tmp/ndu-ollama.log" >&2
    exit 1
  fi
fi

if ! ollama list | awk 'NR > 1 {print $1}' | grep -Fxq "$MODEL"; then
  echo "Pulling local model: $MODEL"
  ollama pull "$MODEL"
fi

echo "Starting local NDU AI server on http://127.0.0.1:$PORT"
echo "Run Flutter with: flutter run -d chrome --dart-define=OPENAI_PROXY_ENDPOINT=http://127.0.0.1:$PORT"

cd "$ROOT_DIR"
PORT="$PORT" \
HOST=127.0.0.1 \
LLM_MODEL="$MODEL" \
LLM_ALLOW_LOCAL_AUTH=true \
OLLAMA_HOST=http://127.0.0.1:11434 \
node gate/auth-gate.js
