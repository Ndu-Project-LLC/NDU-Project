#!/bin/bash
set -e

export PATH="/tmp/flutter-sdk/bin:$PATH"
cd /home/z/my-project

echo "=== Starting Flutter Web Build ==="
flutter --version

echo "=== Installing dependencies ==="
flutter pub get

echo "=== Building for web (release) ==="
flutter build web --release --no-tree-shake-icons --pwa-strategy=none

echo "=== Build complete! ==="
ls -la build/web/ | head -30
