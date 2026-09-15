#!/bin/sh
set -e

# Start the Ollama server in the background.
ollama serve &
SERVER_PID=$!

# Wait until the server socket accepts commands (up to ~60s).
i=0
until ollama list >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -gt 60 ]; then
    echo "Ollama server failed to start" >&2
    exit 1
  fi
  sleep 1
done

# Pull the configured model. On later boots this is a fast no-op because the
# model is cached in the volume.
MODEL="${LLM_MODEL:-qwen2.5:7b-instruct}"

# Models sourced from Hugging Face (hf.co/... tags) authenticate the pull with
# the HF_TOKEN env var (see docker-compose.yml). Warn early if it is missing.
case "$MODEL" in
  hf.co/*)
    if [ -z "${HF_TOKEN:-}" ]; then
      echo "WARNING: LLM_MODEL points at Hugging Face ($MODEL) but HF_TOKEN is" >&2
      echo "not set — the pull may fail for gated repos or large files." >&2
    else
      echo "Authenticating Hugging Face pull for $MODEL (HF_TOKEN set)."
    fi
    ;;
esac

# When the configured model is the custom ndu-assistant, build it from the
# Modelfile baked into the image (first boot pulls the ~9 GB qwen2.5-coder:14b
# base; later boots rebuild instantly from the cached base).
case "$MODEL" in
  ndu-assistant|ndu-assistant:*)
    if [ -f /root/ndu-assistant.Modelfile ]; then
      echo "Building custom model ndu-assistant from /root/ndu-assistant.Modelfile..."
      ollama create ndu-assistant -f /root/ndu-assistant.Modelfile
    else
      echo "WARNING: /root/ndu-assistant.Modelfile not found in image; pulling ${MODEL} directly." >&2
    fi
    ;;
esac

echo "Pulling model: ${MODEL}"
ollama pull "$MODEL"
echo "Model ready: ${MODEL}"

# Keep serving in the foreground so the container stays alive.
wait "$SERVER_PID"