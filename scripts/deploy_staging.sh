#!/bin/bash
set -euo pipefail

# =============================================================================
# NDU Project — Staging Deployment Script
# =============================================================================
# Deploys the Flutter web build to Firebase Hosting staging target.
# The build must already exist in build/web/ (run deploy.sh or build_web.sh first).
#
# Usage:
#   ./scripts/deploy_staging.sh              # deploy to staging
#   ./scripts/deploy_staging.sh --build      # build first, then deploy
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

FIREBASE_PROJECT="ndu-d3f60"
DEPLOY_TARGET="staging"

# Parse args
DO_BUILD=false
for arg in "$@"; do
    case "$arg" in
        --build) DO_BUILD=true ;;
        -h|--help)
            echo "Usage: $0 [--build]"
            echo "  --build  Run flutter build web before deploying"
            exit 0 ;;
        *) echo "Unknown arg: $arg" >&2; exit 2 ;;
    esac
done

echo "=========================================="
echo "  NDU Project — Staging Deployment"
echo "  Target: https://staging.nduproject.com"
echo "=========================================="
echo ""

# Verify Firebase auth
if ! firebase projects:list --project "$FIREBASE_PROJECT" &> /dev/null 2>&1; then
    echo "ERROR: Firebase credentials invalid. Run: firebase login --reauth"
    exit 1
fi

# Optional: build first
if [[ "$DO_BUILD" == "true" ]]; then
    echo "[1/3] Building Flutter web app..."
    flutter pub get
    flutter build web --target=lib/main.dart --no-tree-shake-icons --release --pwa-strategy=none
    echo "✓ Build complete"
    echo ""
fi

# Verify build exists
if [ ! -f "build/web/main.dart.js" ]; then
    echo "ERROR: Build output not found in build/web/"
    echo "Run: flutter build web --release  or  $0 --build"
    exit 1
fi
echo "[2/3] ✓ Build output verified"

# Deploy to Firebase Hosting (staging target)
echo "[3/3] Deploying to Firebase Hosting (staging)..."
firebase deploy \
    --project "$FIREBASE_PROJECT" \
    --only hosting:"$DEPLOY_TARGET" \
    --message "Deploy staging $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

echo ""
echo "=========================================="
echo "  DEPLOYMENT COMPLETE!"
echo "=========================================="
echo ""
echo "  Live URL: https://staging.nduproject.com"
echo ""
