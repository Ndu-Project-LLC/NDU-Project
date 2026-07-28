#!/usr/bin/env bash

# Exit on error
set -e

echo "🚀 Starting Render Build Process..."

# 1. Download Flutter SDK
if [ ! -d "flutter" ]; then
  echo "📥 Cloning Flutter stable branch..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
else
  echo "✅ Flutter already exists, skipping clone."
fi

# 2. Add Flutter to PATH
export PATH="$PATH:$(pwd)/flutter/bin"

# 3. Check and update Flutter
echo "🔍 Checking Flutter status..."
flutter --version

# 4. Enable Web
echo "🌐 Enabling Web support..."
flutter config --enable-web

# 5. Get dependencies
echo "📦 Getting project dependencies..."
flutter pub get

# 6. Build the web app
echo "🏗️ Building Web App (User interface)..."
# Using the same target as in your deploy.sh
flutter build web --target=lib/main.dart --release --pwa-strategy=none

echo "✅ Build completed successfully!"
