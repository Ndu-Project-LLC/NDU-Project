#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=========================================="
echo "  NDU Project - Staging Deployment Script"
echo "  Target: staging.nduproject.com"
echo "=========================================="

cd "$REPO_ROOT"

# Set Firebase project
export FIREBASE_PROJECT="ndu-d3f60"
export DEPLOY_TARGET="staging"
export DEPLOY_CHANNEL="staging-ndu"

echo "[1/4] Using Firebase project: $FIREBASE_PROJECT"

# Verify build exists
if [ ! -f "build/web/main.dart.js" ]; then
    echo "ERROR: Build output not found in build/web/"
    echo "Please run: flutter build web --release"
    exit 1
fi
echo "[2/4] ✓ Build output verified"

# Update CNAME for custom domain
echo "staging.nduproject.com" > build/web/CNAME
echo "[3/4] ✓ CNAME configured for staging.nduproject.com"

# Deploy to Firebase Hosting
echo "[4/4] Deploying to Firebase Hosting..."
echo "  Target: $DEPLOY_TARGET"
echo "  Channel: $DEPLOY_CHANNEL"
echo ""

firebase hosting:build \
    --project "$FIREBASE_PROJECT" \
    --only "$DEPLOY_TARGET" || true

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
echo "  Firebase URL: https://$FIREBASE_PROJECT.web.app"
echo "  Preview URL: https://$FIREBASE_PROJECT.web.app/?channel=$DEPLOY_CHANNEL"
echo ""
