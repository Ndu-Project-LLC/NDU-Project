#!/usr/bin/env bash
#
# push_staging_repo.sh — One-shot push of the local ndu_staging_repo to GitHub.
#
# This is a one-time setup script. After the initial push, the main repo's
# deploy-to-staging-repo.yml workflow will handle all future pushes automatically.
#
# Usage:
#   ./push_staging_repo.sh                          # uses the token from NDU-Project's git config
#   ./push_staging_repo.sh ghp_your_token_here      # explicit token
#   ./push_staging_repo.sh --remote-url https://... # full remote URL with token embedded
#
set -euo pipefail

STAGING_REPO_LOCAL="${STAGING_REPO_LOCAL:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STAGING_REPO_GITHUB="Ndu-Project-LLC/ndu-staging"

log()  { printf '\033[1;34m▶\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m⚠\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

# ─── Sanity ──────────────────────────────────────────────────────────────────
[ -d "$STAGING_REPO_LOCAL/.git" ] || die "Local staging repo not found: $STAGING_REPO_LOCAL"

# ─── Resolve token ───────────────────────────────────────────────────────────
TOKEN=""
REMOTE_URL=""

for arg in "$@"; do
  case "$arg" in
    --remote-url=*) REMOTE_URL="${arg#--remote-url=}" ;;
    --remote-url)   shift; REMOTE_URL="$1" ;;
    ghp_*|github_pat_*) TOKEN="$arg" ;;
    -h|--help)
      sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

# If no explicit URL, try to extract token from NDU-Project's git config
if [ -z "$REMOTE_URL" ] && [ -z "$TOKEN" ]; then
  log "No token provided — attempting to extract from NDU-Project's git config..."
  # Try to extract token from parent repo's git config
  PARENT_GIT_CONFIG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.git/config"
  if [ -f "$PARENT_GIT_CONFIG" ]; then
    TOKEN=$(python3 -c "
import re
with open('$PARENT_GIT_CONFIG') as f:
    m = re.search(r'https://([^@]+)@github\.com', f.read())
    print(m.group(1) if m else '')
" 2>/dev/null || echo "")
    [ -n "$TOKEN" ] && ok "Token extracted from parent repo git config" || warn "Could not extract token"
  fi
fi

# Build remote URL
if [ -n "$REMOTE_URL" ]; then
  : # use as-is
elif [ -n "$TOKEN" ]; then
  REMOTE_URL="https://${TOKEN}@github.com/${STAGING_REPO_GITHUB}.git"
else
  die "No token available. Pass a PAT as the first argument:
  $0 ghp_xxxxxxxxxxxxxxxxxxxx"
fi

# ─── Push ────────────────────────────────────────────────────────────────────
cd "$STAGING_REPO_LOCAL"

log "Local repo:  $STAGING_REPO_LOCAL"
log "Target repo: $STAGING_REPO_GITHUB"
log "Branch:      main"

# Set/update remote
if git remote get-url origin &>/dev/null; then
  git remote set-url origin "$REMOTE_URL"
else
  git remote add origin "$REMOTE_URL"
fi
ok "Remote 'origin' configured"

log "Pushing to origin/main (--force to overwrite any auto-created README)..."
git push -u origin main --force 2>&1 | tail -10

ok "Push complete!"
echo ""
echo "Next steps:"
echo "  1. Enable GitHub Pages: https://github.com/${STAGING_REPO_GITHUB}/settings/pages"
echo "     Source: Deploy from a branch → main / (root)"
echo "  2. Set custom domain: staging.nduproject.com"
echo "  3. Configure DNS CNAME: staging → ndu-project-llc.github.io."
echo "  4. Add ACCESS_TOKEN secret to Ndu-Project-LLC/NDU-Project"
echo "  5. Verify: https://staging.nduproject.com"
