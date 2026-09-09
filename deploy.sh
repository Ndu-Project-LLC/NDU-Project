#!/bin/bash

# =============================================================================
# NDU Project — Full Deployment Script
# =============================================================================
# Builds and deploys both user and admin applications to Firebase Hosting,
# and deploys Cloud Functions (openaiProxy, payment functions, etc.).
#
# Usage:
#   ./deploy.sh                  # full deploy (build + functions + hosting)
#   ./deploy.sh --hosting-only   # skip functions (faster for UI-only changes)
#   ./deploy.sh --functions-only # skip hosting builds
#   ./deploy.sh --no-stamp       # skip build version stamping
#   ./deploy.sh --dry-run        # show what would happen without deploying
#   ./deploy.sh --no-confirm     # skip confirmation prompt
# =============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
DIM='\033[2m'
NC='\033[0m'

# Defaults
DEPLOY_HOSTING=true
DEPLOY_FUNCTIONS=true
DO_STAMP=true
DRY_RUN=false
NO_CONFIRM=false
FIREBASE_PROJECT="ndu-d3f60"

# Parse args
for arg in "$@"; do
  case "$arg" in
    --hosting-only)    DEPLOY_FUNCTIONS=false ;;
    --functions-only)  DEPLOY_HOSTING=false ;;
    --no-stamp)        DO_STAMP=false ;;
    --dry-run)         DRY_RUN=true ;;
    --no-confirm)      NO_CONFIRM=true ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo -e "${RED}Unknown arg: $arg${NC}" >&2; exit 2 ;;
  esac
done

echo -e "${BLUE}NDU Project Deployment Script${NC}"
echo "=============================="
echo "Project:   $FIREBASE_PROJECT"
echo "Hosting:   $DEPLOY_HOSTING"
echo "Functions: $DEPLOY_FUNCTIONS"
echo "Dry run:   $DRY_RUN"
echo ""

# ── Pre-flight checks ───────────────────────────────────────────────────────
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}Flutter is not installed.${NC}"; exit 1
fi
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}Firebase CLI is not installed.${NC}"; exit 1
fi

# Verify Firebase auth (skip during dry run)
if [[ "$DRY_RUN" == "false" ]]; then
    if ! firebase projects:list --project "$FIREBASE_PROJECT" &> /dev/null 2>&1; then
        echo -e "${RED}Firebase credentials invalid. Run: firebase login --reauth${NC}"
        exit 1
    fi
fi

# ── Confirmation prompt ─────────────────────────────────────────────────────
if [[ "$DRY_RUN" == "false" && "$NO_CONFIRM" == "false" && -t 0 ]]; then
    read -rp "$(echo -e "${YELLOW}Deploy to $FIREBASE_PROJECT? [y/N] ${NC}")" confirm
    if [[ "${confirm,,}" != "y" && "${confirm,,}" != "yes" ]]; then
        echo "Aborted."
        exit 0
    fi
    echo ""
fi

# ── Helper: run or print ────────────────────────────────────────────────────
run() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${DIM}▶ $*${NC}"
    else
        "$@"
    fi
}

# ── Step 1: Dependencies ────────────────────────────────────────────────────
echo -e "${BLUE}Step 1:${NC} Getting dependencies..."
run flutter pub get

# ── Step 2: Build user app ──────────────────────────────────────────────────
echo ""
echo -e "${BLUE}Step 2:${NC} Building user app..."
BUILD_FLAGS=(--target=lib/main.dart --no-tree-shake-icons --release --pwa-strategy=none)
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "  ${DIM}▶ flutter build web ${BUILD_FLAGS[*]}${NC}"
else
    flutter build web "${BUILD_FLAGS[@]}"
    if [[ "$DO_STAMP" == "true" ]] && [ -f scripts/stamp_build_version.py ]; then
        python3 scripts/stamp_build_version.py --build-dir build/web 2>/dev/null || true
    fi
fi
echo -e "${GREEN}✓ User app built successfully${NC}"

# ── Step 3: Build admin app ─────────────────────────────────────────────────
echo ""
echo -e "${BLUE}Step 3:${NC} Building admin app..."
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "  ${DIM}▶ flutter build web --target=lib/main_admin.dart ... --output=build/admin_web/${NC}"
else
    flutter build web --target=lib/main_admin.dart --no-tree-shake-icons --release \
        --output=build/admin_web/ --pwa-strategy=none
fi
echo -e "${GREEN}✓ Admin app built successfully${NC}"

# ── Step 4: Sync build outputs to hosting directories ───────────────────────
echo ""
echo -e "${BLUE}Step 4:${NC} Syncing build outputs..."

# Admin app → docs/ (Firebase hosting target "admin")
# Fully replace docs/ contents to avoid stale files from previous builds.
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "  ${DIM}▶ rm -rf docs/ && cp -r build/admin_web/* docs/${NC}"
else
    rm -rf docs
    mkdir -p docs
    cp -r build/admin_web/* docs/
fi
echo -e "${GREEN}✓ Build outputs synced${NC}"

# ── Step 5: Deploy Cloud Functions ──────────────────────────────────────────
if [[ "$DEPLOY_FUNCTIONS" == "true" ]]; then
    echo ""
    echo -e "${BLUE}Step 5:${NC} Deploying Cloud Functions..."
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${DIM}▶ cd functions && npm install${NC}"
        echo -e "  ${DIM}▶ firebase deploy --only functions --project $FIREBASE_PROJECT${NC}"
    else
        # Subshell so cd/npm errors don't leave us in functions/
        (
            cd functions
            npm install --silent
        )
        firebase deploy --only functions --project "$FIREBASE_PROJECT"
    fi
    echo -e "${GREEN}✓ Cloud Functions deployed${NC}"
else
    echo ""
    echo -e "${YELLOW}Step 5:${NC} Skipping Cloud Functions (--hosting-only)"
fi

# ── Step 6: Deploy Hosting ──────────────────────────────────────────────────
if [[ "$DEPLOY_HOSTING" == "true" ]]; then
    echo ""
    echo -e "${BLUE}Step 6:${NC} Deploying to Firebase Hosting..."
    run firebase deploy --only hosting --project "$FIREBASE_PROJECT"
    echo -e "${GREEN}✓ Hosting deployed${NC}"
else
    echo ""
    echo -e "${YELLOW}Step 6:${NC} Skipping Hosting (--functions-only)"
fi

echo ""
echo -e "${GREEN}=================================${NC}"
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}Dry run complete — no changes made${NC}"
else
    echo -e "${GREEN}✓ Deployment completed!${NC}"
fi
echo -e "${GREEN}=================================${NC}"
echo ""
echo -e "${YELLOW}Live URLs:${NC}"
echo "  User App:  https://staging.nduproject.com"
echo "  Admin App: https://admin.nduproject.com"
echo ""
