#!/usr/bin/env bash
# ============================================================================
# one_shot_staging_deploy.sh
# ----------------------------------------------------------------------------
# Bypasses broken CI. Builds the Flutter web app locally and force-pushes the
# artifacts to the `gh-pages` branch so https://staging.nduproject.com/ updates.
#
# Usage:
#   bash one_shot_staging_deploy.sh            # builds current main branch
#   bash one_shot_staging_deploy.sh comments   # builds PR #6 branch instead
#
# Requirements:
#   - Flutter SDK (>= 3.19) on PATH  ->  check with:  flutter --version
#   - Git
#   - A GitHub PAT with `repo` scope (create fresh one — DO NOT reuse any
#     token you've ever pasted into a chat)
# ============================================================================

set -euo pipefail

# ---------- Config ----------
REPO_HTTPS="https://github.com/NduProject/NDU-Project.git"
REPO_GIT_URL_BASE="github.com/NduProject/NDU-Project.git"
TARGET_BRANCH="${1:-main}"          # default to main; pass "comments" for PR #6
WORK_DIR="$(mktemp -d /tmp/ndu-staging-deploy.XXXXXX)"
GH_PAGES_BRANCH="gh-pages"
CNAME_DOMAIN="staging.nduproject.com"

echo "======================================================"
echo "  NDU Project — one-shot staging deploy"
echo "  Target branch : $TARGET_BRANCH"
echo "  Work dir      : $WORK_DIR"
echo "  Dest branch   : $GH_PAGES_BRANCH   (force push)"
echo "  Site          : https://$CNAME_DOMAIN/"
echo "======================================================"
echo ""

# ---------- Preflight ----------
if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: Flutter SDK not found on PATH."
  echo "       Install: https://docs.flutter.dev/get-started/install"
  exit 1
fi
if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git not found on PATH."; exit 1; fi

echo "[1/7] Flutter version:"
flutter --version | head -3
echo ""

# ---------- Clone ----------
echo "[2/7] Cloning repo (depth 50)..."
git clone --depth 50 --no-single-branch "$REPO_HTTPS" "$WORK_DIR"
cd "$WORK_DIR"
git fetch origin "$GH_PAGES_BRANCH" 2>/dev/null || echo "  (no existing gh-pages branch — will create)"

# Checkout target branch
if git ls-remote --exit-code --heads origin "$TARGET_BRANCH" >/dev/null 2>&1; then
  git checkout "$TARGET_BRANCH"
  git pull --ff-only origin "$TARGET_BRANCH" 2>/dev/null || true
else
  echo "ERROR: branch '$TARGET_BRANCH' not found on remote."
  exit 1
fi

echo ""
echo "[3/7] HEAD is now:"
git log -1 --format='  %h %an  %s'
echo ""

# ---------- Build ----------
echo "[4/7] flutter pub get..."
flutter pub get

echo ""
echo "[5/7] flutter build web --release  (base-href = /)"
# base-href "/" because the site is served at the domain root (not /repo/)
flutter build web --release --web-renderer auto --base-href "/"

BUILD_DIR="$WORK_DIR/build/web"
if [ ! -f "$BUILD_DIR/index.html" ]; then
  echo "ERROR: build/web/index.html not found — build failed."
  exit 1
fi

# ---------- Stage gh-pages ----------
echo ""
echo "[6/7] Preparing gh-pages branch..."
GH_PAGES_WORK="$(mktemp -d /tmp/ndu-gh-pages.XXXXXX)"
cd "$GH_PAGES_WORK"
git clone --depth 1 "$REPO_HTTPS" -b "$GH_PAGES_BRANCH" . 2>/dev/null || {
  echo "  gh-pages branch does not exist yet — initializing..."
  git init -b "$GH_PAGES_BRANCH" .
  git remote add origin "$REPO_HTTPS"
}

# Wipe old artifacts (we will replace wholesale) but keep .git, CNAME, .nojekyll
find . -mindepth 1 -maxdepth 1 \
  ! -name '.git' \
  ! -name 'CNAME' \
  ! -name '.nojekyll' \
  -exec rm -rf {} +

# Copy fresh build in
cp -R "$BUILD_DIR/." .

# Ensure CNAME & .nojekyll exist
echo "$CNAME_DOMAIN" > CNAME
touch .nojekyll

# ---------- Commit & push ----------
git add -A
git config user.email "ndu-staging-deploy@users.noreply.github.com"
git config user.name  "NDU Staging Deploy (one-shot)"

if git diff --cached --quiet; then
  echo "  No changes vs. current gh-pages — nothing to push."
  echo "  staging.nduproject.com is already up to date."
  exit 0
fi

SHORT_SHA="$(cd "$WORK_DIR" && git rev-parse --short HEAD)"
COMMIT_MSG="chore(staging): deploy $SHORT_SHA from '$TARGET_BRANCH' (one-shot, bypass CI)

Built locally with flutter build web --release --base-href /
Source: $REPO_HTTPS (branch $TARGET_BRANCH @ $SHORT_SHA)
"

git commit -m "$COMMIT_MSG" --quiet
echo ""
echo "[7/7] Force-pushing to origin/$GH_PAGES_BRANCH ..."
echo "      (you will be prompted for your GitHub username + PAT)"
echo ""
git push --force origin "$GH_PAGES_BRANCH"

echo ""
echo "======================================================"
echo "  DEPLOYED"
echo "======================================================"
echo "  Live URL    : https://$CNAME_DOMAIN/"
echo "  Commit      : $SHORT_SHA  ($TARGET_BRANCH)"
echo " Propagation  : ~30–90 seconds (GitHub Pages CDN cache)"
echo ""
echo "  If the site doesn't update, hard-refresh (Cmd+Shift+R)"
echo "  or check: https://github.com/NduProject/NDU-Project/actions"
echo "======================================================"
