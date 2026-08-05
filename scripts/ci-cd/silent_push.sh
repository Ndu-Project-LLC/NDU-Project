#!/usr/bin/env bash
# ============================================================================
# silent_push.sh
# ----------------------------------------------------------------------------
# One-command silent install of the SILENT_ACTORS-gated NDU CI/CD workflows.
#
# Order of operations (deliberately chosen so the install itself is silent):
#   1. Authenticate gh CLI (secure token prompt — token never echoes, never
#      lands in shell history)
#   2. Set SILENT_ACTORS repo variable FIRST (before any workflow file lands)
#      → so the gate has a value to read the moment workflows appear
#   3. PUT all 3 workflow files via GitHub Contents API (no local clone needed)
#   4. Verify: variable + workflow list
#
# Why this is "silent":
#   - The commit that adds/updates the workflow files is made by CHAMA18 (the
#     token owner). Since SILENT_ACTORS is already set to include CHAMA18,z.ai
#     BEFORE the workflow files land, any workflow that fires on the install
#     commit will hit the gate and skip every downstream job.
#   - All FUTURE pushes by CHAMA18 or z.ai → gate fires → no build, no deploy,
#     no Issue @mentions, no escalation, no promotion PR.
#
# Usage:
#   bash silent_push.sh                              # default repo + actors
#   bash silent_push.sh <owner>/<repo>              # different repo
#   bash silent_push.sh <owner>/<repo> <actors>     # different repo + actors
#
# Defaults:
#   REPO    = NduProject/NDU-Project
#   ACTORS  = CHAMA18,z.ai
#
# Prereqs:
#   - gh CLI installed (script will use $GH_BIN, falling back to PATH)
#   - A GitHub PAT with repo + workflow scopes
#     Create one at: https://github.com/settings/tokens (classic) — check
#     `repo` and `workflow` scopes. Or fine-grained: Contents RW + Actions RW
#     + Workflows RW on the target repo.
# ============================================================================

set -euo pipefail

REPO="${1:-NduProject/NDU-Project}"
ACTORS="${2:-CHAMA18,z.ai}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOWS_SRC="$SCRIPT_DIR/../.github/workflows"

# ── Locate gh CLI ───────────────────────────────────────────────────────────
GH_BIN=""
for candidate in "/home/z/my-project/sdk/gh/gh" "$(command -v gh 2>/dev/null)"; do
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    GH_BIN="$candidate"
    break
  fi
done

if [ -z "$GH_BIN" ]; then
  echo "ERROR: gh CLI not found."
  echo "  Install: https://cli.github.com/"
  echo "  Or on this sandbox: it's at /home/z/my-project/sdk/gh/gh"
  exit 1
fi

echo "======================================================"
echo "  NDU CI/CD — SILENT push to GitHub"
echo "======================================================"
echo "  gh binary:  $GH_BIN"
echo "  Target repo: $REPO"
echo "  Silent actors: $ACTORS"
echo "  Workflows src: $WORKFLOWS_SRC"
echo "======================================================"
echo ""

# ── 1. Authenticate ─────────────────────────────────────────────────────────
if "$GH_BIN" auth status >/dev/null 2>&1; then
  echo "[1/4] gh already authenticated as: $("$GH_BIN" api user --jq .login 2>/dev/null || echo '?')"
else
  echo "[1/4] gh not authenticated. Paste a GitHub PAT (scopes: repo, workflow)."
  echo "      Token will NOT echo and will NOT be saved to shell history."
  echo "      Create one at: https://github.com/settings/tokens"
  printf "      PAT> "
  read -rs GH_TOKEN_INPUT
  echo ""
  if [ -z "$GH_TOKEN_INPUT" ]; then
    echo "  [fail] No token entered. Aborting."
    exit 1
  fi
  echo "$GH_TOKEN_INPUT" | "$GH_BIN" auth login --with-token >/dev/null 2>&1 || {
    echo "  [fail] gh auth login failed. Check token + scopes."
    exit 1
  }
  unset GH_TOKEN_INPUT
  echo "  [ok] Authenticated as: $("$GH_BIN" api user --jq .login)"
fi

# Sanity: confirm we can reach the repo
if ! "$GH_BIN" repo view "$REPO" >/dev/null 2>&1; then
  echo "  [fail] Cannot access $REPO. Check repo name + token scopes."
  exit 1
fi
echo "  [ok] Repo accessible: $REPO"
echo ""

# ── 2. Set SILENT_ACTORS variable FIRST ─────────────────────────────────────
echo "[2/4] Setting SILENT_ACTORS=$ACTORS on $REPO (before workflows land)..."
if "$GH_BIN" variable set SILENT_ACTORS \
      --body "$ACTORS" \
      --repo "$REPO" >/dev/null 2>&1; then
  echo "  [ok] SILENT_ACTORS set"
else
  echo "  [fail] Could not set SILENT_ACTORS. Check token has Actions:RW scope."
  exit 1
fi
echo ""

# ── 3. Push all 3 workflow files via Contents API ──────────────────────────
echo "[3/4] Pushing SILENT_ACTORS-gated workflows to $REPO..."

WORKFLOWS=(
  "auto-deploy-staging.yml"
  "staging-notify-and-escalate.yml"
  "deploy-production.yml"
)

for WF in "${WORKFLOWS[@]}"; do
  SRC="$WORKFLOWS_SRC/$WF"
  if [ ! -f "$SRC" ]; then
    echo "  [skip] $WF — source not found at $SRC"
    continue
  fi

  CONTENT_BASE64=$(base64 -w 0 "$SRC")

  # Get current SHA (if file exists) so we can overwrite
  CURRENT_SHA=$("$GH_BIN" api "/repos/$REPO/contents/.github/workflows/$WF" \
                  --jq '.sha' 2>/dev/null || echo "")

  PAYLOAD=$(jq -n \
    --arg msg "chore(ci): install SILENT_ACTORS-gated $WF [silent-push]" \
    --arg content "$CONTENT_BASE64" \
    --arg sha "$CURRENT_SHA" \
    '{message: $msg, content: $content, sha: (if $sha == "" then null else $sha end)}')

  if echo "$PAYLOAD" | "$GH_BIN" api \
        --method PUT \
        "/repos/$REPO/contents/.github/workflows/$WF" \
        --input - >/dev/null 2>&1; then
    echo "  [ok]   $WF"
  else
    echo "  [fail] $WF — Contents API PUT failed. Check token has Contents:RW."
    exit 1
  fi
done
echo ""

# ── 4. Verify ───────────────────────────────────────────────────────────────
echo "[4/4] Verifying install..."
echo ""
echo "  ── Repo variables ──"
"$GH_BIN" variable list --repo "$REPO" 2>&1 | sed 's/^/    /'
echo ""
echo "  ── Workflows ──"
"$GH_BIN" workflow list --repo "$REPO" 2>&1 | sed 's/^/    /'
echo ""

echo "======================================================"
echo "  DONE — silent push complete"
echo "======================================================"
echo ""
echo "  What just happened:"
echo "    1. SILENT_ACTORS=$ACTORS was set on $REPO"
echo "    2. 3 SILENT_ACTORS-gated workflows were pushed via Contents API"
echo "    3. The install commit was made by you (the token owner) — and"
echo "       since you're in SILENT_ACTORS, any workflow that fired on the"
echo "       install push hit the gate and skipped all downstream jobs."
echo ""
echo "  What happens next:"
echo "    - Future pushes by $ACTORS → gate fires → workflows skip entirely"
echo "      (no build, no deploy, no Issue @mentions, no escalation, no PR)"
echo "    - Pushes by anyone ELSE → workflows run normally"
echo ""
echo "  To verify the gate fires on your next push:"
echo "    - Push any commit to main on $REPO"
echo "    - Open the Actions tab — you'll see the gate job (green check)"
echo "      followed by every downstream job showing 'Skipped'"
echo ""
echo "  To re-enable notifications for everyone:"
echo "    bash $SCRIPT_DIR/set_silent_actors.sh --clear"
echo ""
