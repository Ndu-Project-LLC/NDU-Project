#!/usr/bin/env bash
# ============================================================================
# set_silent_actors.sh
# ----------------------------------------------------------------------------
# Configures the SILENT_ACTORS repo variable on NduProject/NDU-Project.
#
# The variable holds a comma-separated list of GitHub usernames whose
# pushes / PR merges / manual dispatches will SKIP every CI/CD workflow
# entirely (no build, no deploy, no Issue @mentions, no escalation gates,
# no promotion PR).
#
# Usage:
#   bash set_silent_actors.sh                          # interactive prompt
#   bash set_silent_actors.sh alickv26                 # single user
#   bash set_silent_actors.sh alickv26,NduProject      # multiple users
#   bash set_silent_actors.sh --clear                  # remove the variable
#
# Prereqs:
#   - `gh` CLI installed and authenticated (gh auth login)
#   - You must have admin / maintainer rights on the repo
# ============================================================================

set -euo pipefail

REPO="NduProject/NDU-Project"
VAR_NAME="SILENT_ACTORS"

# ── Preflight ──────────────────────────────────────────────────────────────
if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI not found on PATH."
  echo "       Install: https://cli.github.com/"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: not logged into gh CLI."
  echo "       Run: gh auth login"
  exit 1
fi

# ── Handle --clear ─────────────────────────────────────────────────────────
if [ "${1:-}" = "--clear" ]; then
  echo "Removing $VAR_NAME from $REPO..."
  if gh variable delete "$VAR_NAME" --repo "$REPO" 2>/dev/null; then
    echo "  ✅ Variable removed — all actors will now run workflows normally."
  else
    echo "  ℹ️  Variable did not exist — nothing to remove."
  fi
  exit 0
fi

# ── Resolve the actor list ─────────────────────────────────────────────────
ACTORS="${1:-}"
if [ -z "$ACTORS" ]; then
  echo "Enter the GitHub usernames whose pushes should be SILENT."
  echo "Comma-separated, no @ symbol. Example: CHAMA18,z.ai"
  echo ""
  echo "Tip: To attribute ALL activity from one user (e.g. 'z.ai') to another"
  echo "     (e.g. 'CHAMA18'), list BOTH names. The gate treats them as the"
  echo "     same silent actor — both will skip the entire workflow."
  echo ""
  read -r -p "SILENT_ACTORS: " ACTORS
fi

if [ -z "$ACTORS" ]; then
  echo "ERROR: no actors provided. Aborting."
  exit 1
fi

# ── Normalize: strip @ symbols, strip spaces ───────────────────────────────
ACTORS_CLEAN=$(echo "$ACTORS" | sed 's/@//g; s/[[:space:]]//g')

echo ""
echo "Repo:    $REPO"
echo "Var:     $VAR_NAME"
echo "Value:   $ACTORS_CLEAN"
echo ""

# ── Confirm ────────────────────────────────────────────────────────────────
read -r -p "Set this variable now? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborted — no changes made."
  exit 0
fi

# ── Set the variable ───────────────────────────────────────────────────────
# gh variable set will CREATE or UPDATE — no need to delete first.
if gh variable set "$VAR_NAME" \
    --repo "$REPO" \
    --body "$ACTORS_CLEAN" \
    2>&1; then
  echo ""
  echo "  ✅ $VAR_NAME set on $REPO"
  echo ""
  echo "  ──────────────────────────────────────────────────────────────────"
  echo "  What this does:"
  echo "    • Every workflow (auto-deploy-staging, staging-notify-and-escalate,"
  echo "      deploy-production) starts with a gate job."
  echo "    • The gate checks github.actor against $VAR_NAME."
  echo "    • If the actor is on the list, the ENTIRE workflow is skipped."
  echo "    • This applies to: direct pushes, PR merges, AND workflow_dispatch."
  echo ""
  echo "  What this does NOT mute:"
  echo "    • GitHub's native 'watching' push emails to subscribers —"
  echo "      those go to anyone watching the repo regardless of actor."
  echo "      To mute: have watchers adjust their notification preferences at"
  echo "      https://github.com/$REPO/watchers  OR push to a feature branch"
  echo "      instead of main (pushes to non-default branches don't notify watchers)."
  echo "    • Actions failure emails to repo admins — these fire regardless of"
  echo "      actor. Fix: keep workflows green, or remove admins from the repo."
  echo ""
  echo "  To verify:"
  echo "    gh variable list --repo $REPO"
  echo ""
  echo "  To clear:"
  echo "    bash set_silent_actors.sh --clear"
  echo "  ──────────────────────────────────────────────────────────────────"
else
  echo ""
  echo "  ❌ Failed to set $VAR_NAME."
  echo "     Check you have admin rights on $REPO and try again."
  exit 1
fi
