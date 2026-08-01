#!/usr/bin/env bash
# ============================================================================
# apply_silent_actors.sh
# ----------------------------------------------------------------------------
# Installs the SILENT_ACTORS-gated versions of all 3 NDU CI/CD workflows
# into the target repo.
#
# After running this script, every push / PR merge / manual dispatch by a
# user listed in the SILENT_ACTORS repo variable will SKIP the entire
# workflow — no build, no deploy, no Issue @mentions, no escalation gates.
#
# Usage:
#   bash apply_silent_actors.sh                       # defaults to NduProject/NDU-Project
#   bash apply_silent_actors.sh <owner>/<repo>        # target a different repo
#   bash apply_silent_actors.sh --dry-run             # show what would happen
#
# Prereqs:
#   - `gh` CLI installed and authenticated
#   - Write access to the target repo's .github/workflows/ directory
# ============================================================================

set -euo pipefail

REPO="${1:-NduProject/NDU-Project}"
DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOWS_SRC="$SCRIPT_DIR/../.github/workflows"

# ── Preflight ──────────────────────────────────────────────────────────────
if [ ! -d "$WORKFLOWS_SRC" ]; then
  echo "ERROR: workflows source dir not found: $WORKFLOWS_SRC"
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI not found. Install: https://cli.github.com/"
  exit 1
fi

echo "======================================================"
echo "  NDU CI/CD — SILENT_ACTORS-gated workflow installer"
echo "======================================================"
echo "  Target repo: $REPO"
echo "  Dry run:     $DRY_RUN"
echo "  Source:      $WORKFLOWS_SRC"
echo "======================================================"
echo ""

WORKFLOWS=(
  "auto-deploy-staging.yml"
  "staging-notify-and-escalate.yml"
  "deploy-production.yml"
)

# ── Install each workflow ──────────────────────────────────────────────────
for WF in "${WORKFLOWS[@]}"; do
  SRC="$WORKFLOWS_SRC/$WF"
  if [ ! -f "$SRC" ]; then
    echo "  [skip] $WF — source file not found"
    continue
  fi

  if [ "$DRY_RUN" = "true" ]; then
    echo "  [dry-run] Would overwrite .github/workflows/$WF on $REPO"
    echo "            Source: $SRC ($(wc -c < "$SRC") bytes)"
    continue
  fi

  # Use gh api to PUT the file directly to the repo
  # This avoids needing a local clone.
  CONTENT_BASE64=$(base64 -w 0 "$SRC")

  # Get the current SHA of the file (if it exists) so we can overwrite
  CURRENT_SHA=$(gh api "/repos/$REPO/contents/.github/workflows/$WF" \
                  --jq '.sha' 2>/dev/null || echo "")

  PAYLOAD=$(jq -n \
    --arg msg "chore(ci): install SILENT_ACTORS-gated $WF" \
    --arg content "$CONTENT_BASE64" \
    --arg sha "$CURRENT_SHA" \
    '{message: $msg, content: $content, sha: (if $sha == "" then null else $sha end)}')

  if echo "$PAYLOAD" | gh api \
        --method PUT \
        "/repos/$REPO/contents/.github/workflows/$WF" \
        --input - >/dev/null 2>&1; then
    echo "  [ok]   $WF installed"
  else
    echo "  [fail] $WF — gh api call failed. Check write access to $REPO"
    exit 1
  fi
done

# ── Post-install instructions ──────────────────────────────────────────────
echo ""
echo "======================================================"
echo "  Workflows installed. Now configure SILENT_ACTORS."
echo "======================================================"
echo ""
echo "  Next step — set the SILENT_ACTORS repo variable:"
echo ""
echo "    bash set_silent_actors.sh <your-github-username>"
echo ""
echo "  Example:"
echo "    bash set_silent_actors.sh alickv26"
echo "    bash set_silent_actors.sh alickv26,NduProject"
echo ""
echo "  Verify it was set:"
echo "    gh variable list --repo $REPO"
echo ""
echo "  To clear (re-enable notifications for everyone):"
echo "    bash set_silent_actors.sh --clear"
echo ""
echo "  ─────────────────────────────────────────────────────────────────"
echo "  IMPORTANT — what this does NOT mute:"
echo ""
echo "  1. GitHub's native 'watching' push emails"
echo "     These go to anyone watching the repo, regardless of who pushed."
echo "     Workarounds:"
echo "       a) Push to a feature branch instead of main"
echo "          (pushes to non-default branches don't notify watchers)"
echo "       b) Have watchers adjust their subscription at:"
echo "          https://github.com/$REPO/watchers"
echo "       c) Use a bot account to push (commits from bots don't notify)"
echo ""
echo "  2. Actions failure emails to repo admins"
echo "     These fire regardless of actor. Fix: keep workflows green."
echo "  ─────────────────────────────────────────────────────────────────"
echo ""

if [ "$DRY_RUN" = "false" ]; then
  echo "Done. Trigger a push from a SILENT_ACTORS user to verify the gate fires."
fi
