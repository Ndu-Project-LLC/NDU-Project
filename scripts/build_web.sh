#!/usr/bin/env bash
# =============================================================================
# NDU Project — Build & Stamp Web
# =============================================================================
# Convenience wrapper that runs `flutter build web` and then stamps the build
# version into every deployment file. Use this instead of calling
# `flutter build web` directly so the cache-busting logic is always wired up.
#
# Usage:
#   ./scripts/build_web.sh              # build + stamp with epoch seconds
#   ./scripts/build_web.sh --no-stamp   # build only (skip stamping)
#   ./scripts/build_web.sh --base-href /NDU-Test/   # custom base href
#   ./scripts/build_web.sh --source-maps           # include source maps
#
# After this script completes, deploy the contents of build/web/ to your
# hosting provider (Firebase Hosting, GitHub Pages, Netlify, etc.).
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

STAMP=true
BASE_HREF=""
EXTRA_FLAGS=""

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-stamp)
      STAMP=false
      shift
      ;;
    --base-href)
      BASE_HREF="$2"
      shift 2
      ;;
    --source-maps)
      EXTRA_FLAGS="$EXTRA_FLAGS --source-maps"
      shift
      ;;
    --help|-h)
      sed -n '3,18p' "$0"
      exit 0
      ;;
    *)
      EXTRA_FLAGS="$EXTRA_FLAGS $1"
      shift
      ;;
  esac
done

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  NDU Project — Flutter Web Build                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Project root: $PROJECT_ROOT"
echo "Base href:    ${BASE_HREF:-<default>}"
echo "Extra flags:  ${EXTRA_FLAGS:-<none>}"
echo "Stamp:        $STAMP"
echo ""

# 1. Build
BUILD_CMD="flutter build web"
if [[ -n "$BASE_HREF" ]]; then
  BUILD_CMD="$BUILD_CMD --base-href $BASE_HREF"
fi
if [[ -n "$EXTRA_FLAGS" ]]; then
  BUILD_CMD="$BUILD_CMD $EXTRA_FLAGS"
fi

echo "▶ Running: $BUILD_CMD"
$BUILD_CMD

echo ""
echo "✓ Build complete → build/web/"
echo ""

# 2. Stamp (optional)
if [[ "$STAMP" == "true" ]]; then
  echo "▶ Stamping build version..."
  python3 "$SCRIPT_DIR/stamp_build_version.py" --build-dir "$PROJECT_ROOT/build/web"
else
  echo "⊘ Skipping stamp step (--no-stamp)"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✓ DONE — build/web/ is ready to deploy                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  • Firebase Hosting:  firebase deploy --only hosting"
echo "  • GitHub Pages:      copy build/web/* to docs/ (or root) and push"
echo "  • Netlify/Vercel:    set build/web as the publish directory"
echo "  • Local preview:     cd build/web && python3 -m http.server 8000"
