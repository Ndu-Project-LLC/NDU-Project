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

echo "=== Starting Flutter Web Build ==="
echo "Project root: $PROJECT_ROOT"
flutter --version

echo "=== Installing dependencies ==="
flutter pub get

echo "=== Building for web (release) ==="
flutter build web --release --no-tree-shake-icons --pwa-strategy=none

echo "=== Build complete! ==="
ls -la build/web/ | head -30
