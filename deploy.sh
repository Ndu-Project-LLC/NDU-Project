#!/bin/bash

# NDU Project Deployment Script
# Builds and deploys both user and admin applications

set -e

echo "🚀 NDU Project Deployment Script"
echo "================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first."
    exit 1
fi

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI is not installed. Please install it first:"
    echo "   npm install -g firebase-tools"
    exit 1
fi

echo -e "${BLUE}Step 1:${NC} Getting dependencies..."
flutter pub get

echo ""
echo -e "${BLUE}Step 2:${NC} Building user app..."
flutter build web --target=lib/main.dart --no-tree-shake-icons --release --pwa-strategy=none
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ User app built successfully${NC}"
else
    echo "❌ User app build failed"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 3:${NC} Copying build to docs/ for staging deployment..."
# Copy the web build to docs/ (Firebase hosting public directory)
rm -rf docs/assets docs/canvaskit docs/icons docs/flutter*.js docs/main.dart.js docs/index.html docs/version.json docs/manifest.json docs/favicon.png docs/CNAME 2>/dev/null || true
cp -r build/web/* docs/
echo "staging.nduproject.com" > docs/CNAME
echo -e "${GREEN}✓ Staging build copied to docs/${NC}"

echo ""
echo -e "${BLUE}Step 4:${NC} Building admin app..."
flutter build web --target=lib/main_admin.dart --no-tree-shake-icons --release --output=build/admin_web/ --pwa-strategy=none
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Admin app built successfully${NC}"
else
    echo "❌ Admin app build failed"
    exit 1
fi

echo ""
echo -e "${BLUE}Step 5:${NC} Deploying to Firebase Hosting..."
firebase deploy --only hosting

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}=================================${NC}"
    echo -e "${GREEN}✓ Deployment completed successfully!${NC}"
    echo -e "${GREEN}=================================${NC}"
    echo ""
    echo -e "${YELLOW}Your apps are now live:${NC}"
    echo "  User App:  https://staging.nduproject.com"
    echo "  Admin App: https://admin.nduproject.com"
    echo ""
else
    echo "❌ Firebase deployment failed"
    exit 1
fi
