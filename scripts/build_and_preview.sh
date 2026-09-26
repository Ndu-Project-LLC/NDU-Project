#!/bin/bash
set -euo pipefail

# Resolve project root relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Use system Flutter if available, otherwise check /tmp
if ! command -v flutter &> /dev/null; then
    if [ -d "/tmp/flutter-sdk/bin" ]; then
        export PATH="/tmp/flutter-sdk/bin:$PATH"
    else
        echo "ERROR: Flutter not found. Install Flutter or ensure /tmp/flutter-sdk exists."
        exit 1
    fi
fi

echo "=========================================="
echo "  Building Flutter Web App for Preview"
echo "=========================================="
echo ""

echo "[1/4] Cleaning previous build..."
flutter clean 2>&1 || true
rm -rf build/web

echo ""
echo "[2/4] Getting dependencies..."
flutter pub get

echo ""
echo "[3/4] Building web app (release mode)..."
# Build with optimizations for preview
flutter build web \
  --release \
  --no-tree-shake-icons \
  --pwa-strategy=none \
  --dart-define=FLUTTER_WEB_USE_SKIA=true \
  --base-href "/" \
  2>&1 | tee build_log.txt

echo ""
echo "[4/4] Verifying build output..."
if [ -f "build/web/index.html" ] && [ -f "build/web/main.dart.js" ]; then
    echo "✅ Build successful!"
    echo ""
    echo "Build artifacts:"
    ls -lh build/web/*.js build/web/*.html 2>/dev/null | head -10
    echo ""
    du -sh build/web/
else
    echo "❌ Build failed - missing files"
    exit 1
fi

echo ""
echo "=========================================="
echo "  BUILD COMPLETE!"
echo "=========================================="
