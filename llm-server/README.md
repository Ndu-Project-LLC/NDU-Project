# NDU Project — Self-hosted LLM server (cost-free AI)

This folder deploys a **self-hosted, always-on LLM server** on the Oracle
Cloud **Always Free** ARM VM (Ampere A1: 4 OCPU / 24 GB RAM — no monthly
cost). It serves every KAZ AI feature in the app, so OpenAI credits are only
used when this server is unreachable (automatic fallback — see
`functions/README.md`).

```
Flutter app
   │  OpenAI-format request
   ▼
Firebase openaiProxy (cloud function)
   │  primary route
   ▼
http://<vm-ip>:8080/v1/chat/completions   ← token gate (this repo)
   │  Bearer <LLM_API_TOKEN>
   ▼
Ollama :11434  (qwen2.5:7b-instruct, private Docker network)
```

## 1. One-time Oracle Cloud setup

## Local development

The same server can run locally without Docker or a cloud VM. This is the
recommended way to develop and test all AI screens on a workstation with
Ollama installed:

```bash
cd llm-server
chmod +x start-local.sh
./start-local.sh
```

The default model is `ndu-assistant:latest`; override it with
`LLM_MODEL=qwen3:8b ./start-local.sh`. In a second terminal, start Flutter
with the local endpoint compiled into the app:

```bash
flutter run -d chrome \
  --dart-define=OPENAI_PROXY_ENDPOINT=http://127.0.0.1:8080
```

Local auth mode accepts the Firebase ID token already sent by the app and is
safe for this script because the gate is bound to `127.0.0.1`. It must not be
enabled on a public host. The local gate translates every app request from
OpenAI Chat Completions format to Ollama, so all existing AI screens use the
same service path.

1. Sign up at <https://signup.oraclecloud.com> and pick **Always Free** when
   offered. (A card is required for identity verification but nothing is
   charged on the Always Free tier.)
2. Create a VM instance:
   - **Shape**: `VM.Standard.A1.Flex` (ARM), 4 OCPU / 24 GB RAM — the free
     max. Any smaller slice also works; a 7B model needs at least ~8 GB RAM.
   - **Image**: Ubuntu 22.04 (or 24.04) — the steps below assume Ubuntu.
   - **SSH key**: save the private key — you'll need it to log in.
3. Open the firewall: in the instance's VCN security list add an **ingress
   rule** for **TCP port 8080** from `0.0.0.0/0`. (Ollama itself stays on a
   private Docker network and is never exposed.)

## Choosing a model

`LLM_MODEL` can be any model Ollama can serve:

- **Hugging Face GGUF (default)** — `hf.co/Qwen/Qwen2.5-7B-Instruct-GGUF:q4_k_m`
  (Qwen2.5-7B-Instruct, official Q4_K_M quant). Set `HF_TOKEN` in `.env` and
  Ollama authenticates the pull from hf.co. This is the default replacement
  for the OpenAI model — a strong, license-permissive instruct model that
  runs comfortably on the free-tier ARM VM.
- **Ollama library** — e.g. `qwen2.5:7b-instruct`, `llama3.2:3b` — see
  <https://ollama.com/library>. No token needed.
- **Any other HF GGUF** — `hf.co/<owner>/<repo>:<tag>` (e.g.
  `hf.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF:Q4_K_M`).

### Hugging Face token

Set `HF_TOKEN` in `.env` (gitignored — never commit it):

```bash
HF_TOKEN=hf_...
```

The token authenticates hf.co pulls; it is required for gated/private repos
and makes large downloads reliable. To iterate on a custom model prompt, edit
`ndu-assistant.Modelfile`, rebuild the image
(`docker compose build ollama`), and restart.

The NDU project also ships a custom `ndu-assistant` model (built on
`qwen2.5-coder:14b`), baked into the image — set `LLM_MODEL=ndu-assistant:latest`
in `.env` to use it (14B answers slower on the free VM; swap back to the 7B HF
model if responses feel too slow).

## 2. Deploy the stack

```bash
# From your laptop, using the private key from step 1:
ssh -i ~/.ssh/oracle-key ubuntu@<VM_PUBLIC_IP>

# On the VM:
sudo apt-get update && sudo apt-get install -y docker.io docker-compose-v2
sudo usermod -aG docker ubuntu && newgrp docker

git clone https://github.com/<your-org>/<ndu-repo>.git ndu
cd ndu/llm-server

cp .env.example .env
# Edit .env:
#   LLM_API_TOKEN=$(openssl rand -hex 32)   ← generate once, copy the value
#   HF_TOKEN=hf_...                         ← your Hugging Face token
#   LLM_MODEL=hf.co/Qwen/Qwen2.5-7B-Instruct-GGUF:q4_k_m

docker compose up -d --build
```

First boot downloads the model (~4.7 GB Q4_K_M from Hugging Face) — check
progress with `docker compose logs -f ollama`. Subsequent boots are instant
(the model is cached in the `ollama_models` volume).

## 3. Verify it works

```bash
# Health (no auth):
curl http://localhost:8080/healthz

# Completion (must send the token from .env):
curl -s http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LLM_API_TOKEN" \
  -d '{"model":"anything","messages":[{"role":"user","content":"Say hello in one sentence"}],"max_tokens":50}'
```

Expect an OpenAI-shaped response (`choices[0].message.content`). The model
name in the request is ignored — the gate always uses `LLM_MODEL`.

## 4. Point the app at it

From the repository root (needs `firebase` CLI, authenticated to
`ndu-d3f60`):

```bash
# 1. Tell the proxy where the server lives (non-secret, goes into functions/.env)
cat >> functions/.env <<'EOF'
LLM_SERVER_URL=http://<VM_PUBLIC_IP>:8080
EOF

# 2. Store the gate token as a Firebase secret (paste at the hidden prompt)
firebase functions:secrets:set LLM_SERVER_API_TOKEN --project ndu-d3f60

# 3. (Recommended) Make the proxy request the HF-sourced model by name — the
#    value should match LLM_MODEL in llm-server/.env. Optional: if unset, the
#    proxy defaults to qwen2.5:7b-instruct while the gate still serves
#    whatever LLM_MODEL is configured, so this is purely cosmetic.
cat >> functions/.env <<'EOF'
LLM_MODEL_NAME=hf.co/Qwen/Qwen2.5-7B-Instruct-GGUF:q4_k_m
EOF

# 4. Redeploy the proxy
firebase deploy --only functions:openaiProxy --project ndu-d3f60
```

> **CI deploys** (`.github/workflows/deploy-staging.yml`): `functions/.env` is
> gitignored, so GitHub Actions won't see the local file. Instead, add the
> non-secret `LLM_SERVER_URL` (and optionally `LLM_MODEL_NAME`) as **repo
> secrets** — the workflow writes them into `functions/.env` before deploying.

That's it — the proxy now routes AI requests to your VM first and only falls
back to OpenAI when the VM is unreachable. There is no client change: the app
still talks to the same Cloud Function with the same payloads.

## 5. Keeping it running

- `docker compose up -d` with `restart: unless-stopped` means the stack
  auto-recovers after VM reboots. If you want the VM itself to boot
  automatically, enable the instance's **"Run on startup"** option
  (Instance details → Edit → Boot volume).
- The model is persisted in the `ollama_models` Docker volume, so reboots
  don't re-download it.
- To rotate the token later: change `.env`, `docker compose up -d`, and re-run
  `firebase functions:secrets:set LLM_SERVER_API_TOKEN`.

## Security notes

- Ollama's port is never published — only the gate is reachable, and only
  with a valid `Authorization: Bearer` token.
- The token is never committed. `.env` is gitignored; the Firebase side keeps
  it in Secret Manager (`LLM_SERVER_API_TOKEN`), not in code.
- For tighter lockdown you can additionally restrict the Oracle security list
  ingress rule to Cloud Functions' egress IP range, but the token gate already
  blocks direct abuse.
- Rate limiting stays in the Cloud Function (unchanged) — the gate is not a
  billing boundary.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `gate` logs `fetch failed` | `OLLAMA_HOST` wrong, or the `ollama` service isn't healthy yet (`docker compose ps`, `docker compose logs ollama`) |
| `ollama` logs `connection refused` at boot | start.sh waits up to 60s; on very slow first boot just watch `docker compose logs -f ollama` until "Model ready" |
| Model answers very slowly | Swap `LLM_MODEL` to a smaller model (e.g. `qwen2.5:3b` or `llama3.2:3b`) — quality drops, speed improves |
| `401` from the gate | `LLM_API_TOKEN` in `.env` doesn't match the Firebase secret `LLM_SERVER_API_TOKEN` |
| App falls back to OpenAI error | VM unreachable from the internet (check security-list rule for port 8080) or the gate is down (`docker compose ps`) |