#!/usr/bin/env bash
#
# deploy_ndu.sh — Build + deploy the NDU Project Flutter web app to staging
#
# This script is the SINGLE SOURCE OF TRUTH for staging deploys.
# It exists to prevent the CNAME regression documented in worklog task
# staging-publish-1: Flutter's build copies source web/CNAME (= admin.nduproject.com,
# used by the Azure SWA admin deploy target) into build/web/CNAME, and a naive
# `cp -r build/web/* <deploy-dir>/` silently overwrites the correct staging
# CNAME. This script excludes CNAME from the copy and writes the correct one
# explicitly.
#
# Usage:
#   ./deploy_ndu.sh                    # build + deploy + commit (no push)
#   ./deploy_ndu.sh --push             # build + deploy + commit + push to origin/gh-pages
#   ./deploy_ndu.sh --no-build         # deploy only (skip Flutter build — use existing build/web/)
#   ./deploy_ndu.sh --push --no-build  # deploy + push only
#
# Environment:
#   NDG_SOURCE_DIR     default: /home/z/my-project/ndu_source     (Flutter source worktree on main)
#   NDU_DEPLOY_DIR     default: /home/z/my-project/Ndu_Project    (deploy worktree on gh-pages-kazai-final)
#   STAGING_DOMAIN     default: staging.nduproject.com
#   FLUTTER_BIN        default: /home/z/flutter/bin/flutter
#
set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────────
SOURCE_DIR="${NDU_SOURCE_DIR:-/home/z/my-project/ndu_source}"
DEPLOY_DIR="${NDU_DEPLOY_DIR:-/home/z/my-project/Ndu_Project}"
STAGING_DOMAIN="${STAGING_DOMAIN:-staging.nduproject.com}"
FLUTTER_BIN="${FLUTTER_BIN:-/home/z/flutter/bin/flutter}"

DO_PUSH=0
DO_BUILD=1

# ─── Arg parsing ─────────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --push) DO_PUSH=1 ;;
    --no-build) DO_BUILD=0 ;;
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

# ─── Helpers ─────────────────────────────────────────────────────────────────
log()  { printf '\033[1;34m▶\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m⚠\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

# ─── Sanity checks ───────────────────────────────────────────────────────────
[ -d "$SOURCE_DIR" ]               || die "Source dir not found: $SOURCE_DIR"
[ -d "$DEPLOY_DIR" ]               || die "Deploy dir not found: $DEPLOY_DIR"
[ -x "$FLUTTER_BIN" ]              || die "Flutter not found at: $FLUTTER_BIN"
[ -f "$SOURCE_DIR/pubspec.yaml" ]  || die "pubspec.yaml missing in $SOURCE_DIR — not a Flutter project?"

cd "$SOURCE_DIR"
log "Source:  $SOURCE_DIR (branch: $(git rev-parse --abbrev-ref HEAD))"
log "Deploy:  $DEPLOY_DIR (branch: $(cd "$DEPLOY_DIR" && git rev-parse --abbrev-ref HEAD))"
log "Domain:  $STAGING_DOMAIN"

# ─── Step 1: Build (optional) ────────────────────────────────────────────────
if [ "$DO_BUILD" -eq 1 ]; then
  log "[1/5] Flutter pub get"
  "$FLUTTER_BIN" pub get 2>&1 | tail -3

  log "[2/5] Flutter build web (release)"
  # --no-tree-shake-icons: project loads icons dynamically from JSON data
  "$FLUTTER_BIN" build web --no-tree-shake-icons --release --no-wasm-dry-run 2>&1 | tail -5
  ok "Build complete: $(du -h build/web/main.dart.js | cut -f1)"
else
  log "[1/5] Skipping build (--no-build)"
  log "[2/5] Skipping build (--no-build)"
  [ -f "$SOURCE_DIR/build/web/main.dart.js" ] || die "No existing build found at $SOURCE_DIR/build/web/ — run without --no-build"
fi

# ─── Step 3: Copy build to deploy dir, EXCLUDING CNAME ───────────────────────
log "[3/5] Sync build/web/ → $DEPLOY_DIR/ (excluding CNAME)"

# rsync is the cleanest tool here: --exclude=CNAME prevents the source CNAME
# (admin.nduproject.com) from overwriting the deploy dir's CNAME.
# --delete keeps the deploy dir in sync (removes stale files).
if command -v rsync &> /dev/null; then
  rsync -a --delete --exclude=CNAME --exclude=.git --exclude=.nojekyll \
    "$SOURCE_DIR/build/web/" "$DEPLOY_DIR/"
else
  # Fallback: cp + manual CNAME preservation (less robust, no stale-file cleanup)
  warn "rsync not found, using cp fallback (no stale-file cleanup)"
  find "$DEPLOY_DIR" -mindepth 1 -maxdepth 1 \
    ! -name CNAME ! -name .git ! -name .nojekyll -exec rm -rf {} +
  cp -r "$SOURCE_DIR/build/web/." "$DEPLOY_DIR/"
  # Restore CNAME if cp clobbered it (cp doesn't have --no-clobber for directories reliably)
fi

# ─── Step 4: Force-write correct CNAME (idempotent safety net) ───────────────
log "[4/5] Force-write CNAME → $STAGING_DOMAIN"
echo "$STAGING_DOMAIN" > "$DEPLOY_DIR/CNAME"

# Sanity: verify CNAME content
CNAME_CONTENT="$(cat "$DEPLOY_DIR/CNAME")"
[ "$CNAME_CONTENT" = "$STAGING_DOMAIN" ] || die "CNAME verification failed: expected '$STAGING_DOMAIN', got '$CNAME_CONTENT'"
ok "CNAME = $STAGING_DOMAIN"

# ─── Step 5: Commit (and optionally push) ────────────────────────────────────
log "[5/5] Commit deploy to gh-pages-kazai-final"
cd "$DEPLOY_DIR"
BUILD_STAMP="$(date +%s)"
git add -A
if git diff --cached --quiet; then
  ok "No changes to commit (deploy dir already up-to-date)"
else
  git -c user.email="ndu-bot@local" -c user.name="NDU Bot" commit -m \
    "deploy: build $BUILD_STAMP — staging deploy via deploy_ndu.sh

Bundle size: $(du -h main.dart.js | cut -f1)
CNAME: $STAGING_DOMAIN (force-written by deploy_ndu.sh)
Source: $(cd "$SOURCE_DIR" && git rev-parse --short HEAD) on main"
  ok "Committed deploy (build $BUILD_STAMP)"
fi

if [ "$DO_PUSH" -eq 1 ]; then
  log "Pushing gh-pages-kazai-final → origin/gh-pages"
  git push origin gh-pages-kazai-final:gh-pages 2>&1 | tail -5
  ok "Pushed. Staging will rebuild in ~60s at https://$STAGING_DOMAIN/"
fi

echo ""
ok "Deploy complete."
[ "$DO_PUSH" -eq 0 ] && warn "Run with --push to publish to https://$STAGING_DOMAIN/"
