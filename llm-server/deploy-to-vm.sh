#!/bin/bash
# =============================================================================
# Deploy the self-hosted LLM stack to the Oracle Cloud Always-Free ARM VM
# and verify the gate responds.
#
# Usage (run from the llm-server/ directory on your laptop):
#   ./deploy-to-vm.sh <VM_PUBLIC_IP> [ssh-user] [ssh-key]
#     ssh-user  default: ubuntu
#     ssh-key   default: ~/.ssh/oracle-key
#
# What it does:
#   1. rsyncs llm-server/ (including .env with your tokens) to the VM
#   2. installs Docker on the VM if missing
#   3. builds + starts the ollama + gate stack (first boot pulls ~4.7 GB
#      Qwen2.5-7B GGUF from Hugging Face using HF_TOKEN)
#   4. waits for the gate to come up and verifies health + a completion
#   5. prints the public gate URL (check the VCN security list allows
#      TCP 8080 from 0.0.0.0/0 if the public health check fails)
#
# Requires locally: rsync, ssh, and the VM's SSH private key.
# =============================================================================
set -euo pipefail

VM_IP="${1:?usage: ./deploy-to-vm.sh <VM_PUBLIC_IP> [ssh-user] [ssh-key]}"
SSH_USER="${2:-ubuntu}"
SSH_KEY="${3:-$HOME/.ssh/oracle-key}"

if [ ! -f "$SSH_KEY" ]; then
  echo "✗ SSH key not found: $SSH_KEY" >&2
  exit 1
fi

if [ ! -f .env ]; then
  echo "✗ llm-server/.env missing. Create it first:" >&2
  echo "    cp .env.example .env" >&2
  echo "    # then set LLM_API_TOKEN, HF_TOKEN, LLM_MODEL" >&2
  exit 1
fi

# Token values are only used on the VM; never printed.
if ! grep -q '^HF_TOKEN=.\+' .env; then
  echo "✗ HF_TOKEN is not set in .env (required for the Hugging Face model pull)." >&2
  exit 1
fi
if grep -q '^LLM_API_TOKEN=change-me' .env; then
  echo "✗ LLM_API_TOKEN is still 'change-me' in .env." >&2
  exit 1
fi

SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15"
DEST="$SSH_USER@$VM_IP"

echo "▶ Testing SSH connection to $DEST ..."
ssh $SSH_OPTS "$DEST" 'echo connected; uname -m' || {
  echo "✗ Cannot reach $DEST. Check the IP, the SSH key, and that the VM is running." >&2
  exit 1
}

echo "▶ Syncing llm-server/ to $DEST:~/ndu-llm-server ..."
rsync -az --delete -e "ssh $SSH_OPTS" ./ "$DEST":~/ndu-llm-server/

echo "▶ Setting up Docker + starting the stack on the VM (first boot pulls the model, this takes a few minutes) ..."
ssh $SSH_OPTS "$DEST" 'bash -s' <<'REMOTE'
set -euo pipefail
cd ~/ndu-llm-server

if ! command -v docker >/dev/null 2>&1; then
  echo "  Installing Docker..."
  sudo apt-get update -qq
  sudo apt-get install -y -qq docker.io docker-compose-v2 >/dev/null
fi

echo "  Building and starting services..."
sudo docker compose up -d --build

echo "  Waiting for the gate to come up (up to 8 min)..."
ok=0
for i in $(seq 1 96); do
  if curl -fsS http://localhost:8080/healthz >/dev/null 2>&1; then
    ok=1
    break
  fi
  sleep 5
done
if [ "$ok" -ne 1 ]; then
  echo "  ✗ Gate did not become healthy. Check logs:" >&2
  sudo docker compose logs --tail=50 gate ollama >&2
  exit 1
fi

echo "  ✓ Gate is up (http://localhost:8080/healthz)"

# Load tokens from .env (LLM_API_TOKEN / LLM_MODEL)
set -a
# shellcheck disable=SC1091
. ./.env
set +a

echo "  Sending a test completion through the gate..."
RESP=$(curl -s http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LLM_API_TOKEN" \
  -d '{"model":"any","messages":[{"role":"user","content":"Reply with exactly: KAZ AI local model OK"}],"max_tokens":30}')
echo "$RESP" | grep -q '"content"' && echo "  ✓ Completion returned content" || {
  echo "  ✗ Unexpected response:" >&2
  echo "$RESP" >&2
  exit 1
}

echo
echo "  ✓ Stack deployed and verified locally on the VM."
REMOTE

echo
echo "▶ Verifying from the internet (port 8080 must be open in the VCN security list) ..."
if curl -fsS --connect-timeout 10 "http://$VM_IP:8080/healthz" >/dev/null 2>&1; then
  echo "  ✓ Public gate responds: http://$VM_IP:8080/healthz"
  echo
  echo "  Next step — point the Firebase proxy at it and deploy:"
  echo "    cat >> functions/.env <<'EOF'"
  echo "    LLM_SERVER_URL=http://$VM_IP:8080"
  echo "    LLM_MODEL_NAME=hf.co/Qwen/Qwen2.5-7B-Instruct-GGUF:q4_k_m"
  echo "    EOF"
  echo "    firebase functions:secrets:set LLM_SERVER_API_TOKEN --project ndu-d3f60   # paste LLM_API_TOKEN from llm-server/.env"
  echo "    firebase deploy --only functions:openaiProxy --project ndu-d3f60"
else
  echo "  ✗ Public gate unreachable at http://$VM_IP:8080/healthz"
  echo "    The stack works on the VM (verified above). Open TCP 8080 in the"
  echo "    instance's VCN security list (ingress from 0.0.0.0/0) and retry:"
  echo "      ./deploy-to-vm.sh $VM_IP $SSH_USER"
fi