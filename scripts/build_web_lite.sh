#!/usr/bin/env bash
# =============================================================================
# NDU Project — Lightweight Web Build
# =============================================================================
# Builds a small, fast-loading production web bundle and reports the final
# size. Use this for quick "run it anytime" builds, previews, and
# size-conscious deployments.
#
# What makes it lightweight vs the standard pipeline (deploy.sh):
#   --release                 minifies + tree-shakes main.dart.js
#   --tree-shake-icons        removes unused Material icon glyphs
#   --pwa-strategy=none       no service worker / offline cache bloat
#   engine pruning            deletes canvaskit payloads a dart2js build can
#                             never download: skwasm*/wimp* (dart2wasm only),
#                             experimental_webparagraph, and *.js.symbols
#   --source-maps (optional)  only included when explicitly requested
#
# Usage:
#   ./scripts/build_web_lite.sh               # build + size report
#   ./scripts/build_web_lite.sh --serve       # build, then serve at :8080
#   ./scripts/build_web_lite.sh --serve 3000  # build, then serve on a port
#   ./scripts/build_web_lite.sh --serve-only  # serve existing build (no rebuild)
#   ./scripts/build_web_lite.sh --no-stamp    # skip build-version stamping
#   ./scripts/build_web_lite.sh --source-maps # keep source maps (larger)
#   ./scripts/build_web_lite.sh --local-ai    # AI runs in code (AI_MODE=local)
#
# Output goes to build/web-lite/. The production pipeline (deploy.sh,
# scripts/deploy_staging.sh) is untouched and keeps using build/web/.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

BUILD_DIR="build/web-lite"
PORT="8080"
STAMP=true
SERVE=false
SKIP_BUILD=false
SOURCE_MAPS=false
LOCAL_AI=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --serve)      SERVE=true; shift ;;
    --serve-only) SERVE=true; SKIP_BUILD=true; shift ;;
    --no-stamp)   STAMP=false; shift ;;
    --source-maps) SOURCE_MAPS=true; shift ;;
    --local-ai)   LOCAL_AI=true; shift ;;
    --help|-h)
      sed -n '3,30p' "$0"
      exit 0
      ;;
    [0-9]*)
      PORT="$1"
      shift
      ;;
    *)
      echo "Unknown arg: $1" >&2
      echo "Usage: ./scripts/build_web_lite.sh [--serve [port]] [--no-stamp] [--source-maps]" >&2
      exit 2
      ;;
  esac
done

if ! command -v flutter &> /dev/null; then
  echo "✗ Flutter is not installed or not on PATH." >&2
  exit 1
fi

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  NDU Project — Lightweight Web Build                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Build dir:   $BUILD_DIR"
echo "Port:        $PORT"
echo "Stamp:       $STAMP"
echo "Source maps: $SOURCE_MAPS"
echo "Local AI:    $LOCAL_AI"
echo ""

# --serve-only: serve the existing build without rebuilding.
if [[ "$SKIP_BUILD" == "true" ]]; then
  if [ ! -f "$BUILD_DIR/index.html" ]; then
    echo "✗ No existing build at $BUILD_DIR. Run ./scripts/build_web_lite.sh first." >&2
    exit 1
  fi
  echo "⊘ Skipping build (--serve-only) — serving existing $BUILD_DIR"
echo ""
  SERVE_PORT="$PORT"
  "$SCRIPT_DIR/serve_lite.py" "$BUILD_DIR" "$SERVE_PORT"
  exit 0
fi

# 1. Dependencies
echo "▶ flutter pub get"
flutter pub get

# 2. Build (small bundle: release + icon tree-shaking + no service worker)
BUILD_FLAGS=(--release --pwa-strategy=none --tree-shake-icons --no-wasm-dry-run)
if [[ "$SOURCE_MAPS" == "true" ]]; then
  BUILD_FLAGS+=(--source-maps)
fi
# --local-ai compiles the app with AI_MODE=local: every KAZ AI surface is
# served by the in-code generator, so the bundle needs no backend, key, or
# network to produce content.
if [[ "$LOCAL_AI" == "true" ]]; then
  BUILD_FLAGS+=(--dart-define=AI_MODE=local)
fi

echo ""
echo "▶ flutter build web ${BUILD_FLAGS[*]} --output=$BUILD_DIR"
flutter build web "${BUILD_FLAGS[@]}" --output="$BUILD_DIR"

# 3. Prune engine payloads a dart2js build can never download.
#    (Keeps canvaskit/ + chromium/ — the two renderer variants actually used.)
CK="$BUILD_DIR/canvaskit"
PRUNED=0
if [ -d "$CK" ]; then
  for item in skwasm.js skwasm.wasm \
              skwasm_heavy.js skwasm_heavy.wasm \
              wimp.js wimp.wasm \
              experimental_webparagraph; do
    if [ -e "$CK/$item" ]; then
      rm -rf "$CK/$item"
      PRUNED=$((PRUNED + 1))
    fi
  done
  # Debug symbol maps — never fetched by browsers.
  while IFS= read -r sym; do
    rm -f "$sym"
    PRUNED=$((PRUNED + 1))
  done < <(find "$CK" -name '*.js.symbols' -type f 2>/dev/null)
fi

# 4. Stamp build version (same cache-busting pipeline as production)
if [[ "$STAMP" == "true" ]] && [ -f scripts/stamp_build_version.py ]; then
  echo ""
  echo "▶ Stamping build version..."
  python3 scripts/stamp_build_version.py --build-dir "$BUILD_DIR" 2>/dev/null || true
fi

# 5. Size report — on-disk size and gzipped wire size of the main payload
# fmt_mb <value> <unit>   unit is "kb" (du -sk output) or "bytes"
fmt_mb() {
  if [[ "$2" == "kb" ]]; then
    awk -v v="$1" 'BEGIN { printf "%.1f MB", v / 1024 }'
  else
    awk -v v="$1" 'BEGIN { printf "%.1f MB", v / 1024 / 1024 }'
  fi
}
dir_size() {
  du -sk "$1" 2>/dev/null | cut -f1
}
gz_size() {
  gzip -c "$1" 2>/dev/null | wc -c | tr -d ' '
}
human() {
  ls -lh "$1" 2>/dev/null | awk '{print $5}'
}

echo ""
echo "── Size report ────────────────────────────────────────────────"
if [ -f "$BUILD_DIR/main.dart.js" ]; then
  MAIN="$BUILD_DIR/main.dart.js"
  printf "  %-28s %10s  (gzipped %s)\n" "main.dart.js" "$(human "$MAIN")" "$(fmt_mb "$(gz_size "$MAIN")" bytes)"
fi
if [ -f "$CK/canvaskit.wasm" ]; then
  printf "  %-28s %10s  (gzipped %s)\n" "canvaskit.wasm" "$(human "$CK/canvaskit.wasm")" "$(fmt_mb "$(gz_size "$CK/canvaskit.wasm")" bytes)"
fi
printf "  %-28s %10s\n" "Total bundle ($BUILD_DIR)" "$(fmt_mb "$(dir_size "$BUILD_DIR")" kb)"
echo "  Note: a browser downloads main.dart.js + ONE canvaskit"
echo "  variant (canvaskit/ or chromium/), not the whole bundle."
echo "───────────────────────────────────────────────────────────────"
echo "  Engine payloads pruned: $PRUNED item(s) (skwasm/wimp/symbols)"
echo "───────────────────────────────────────────────────────────────"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✓ DONE — $BUILD_DIR is ready                                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Run it anytime:"
echo "  ./scripts/build_web_lite.sh --serve           # http://localhost:$PORT"
echo "  ./scripts/build_web_lite.sh --serve 3000      # custom port"
echo ""

# 6. Serve
if [[ "$SERVE" == "true" ]]; then
  # SPA fallback + correct mime types require python3 (wasm needs
  # application/wasm for streaming compilation).
  if ! command -v python3 &> /dev/null; then
    echo "✗ python3 is required for --serve (correct .wasm mime type)." >&2
    exit 1
  fi

  echo "▶ Serving $BUILD_DIR at http://localhost:$PORT  (Ctrl+C to stop)"
  exec "$SCRIPT_DIR/serve_lite.py" "$BUILD_DIR" "$PORT"
fi
