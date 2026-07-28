@echo off
REM Flutter Web Run Script with HTML Renderer
REM This script runs Flutter web with HTML renderer to avoid CDN timeout errors

echo Starting Flutter web app with HTML renderer...
echo This avoids canvaskit CDN dependency and prevents timeout errors.

flutter run -d chrome --dart-define=FLUTTER_WEB_USE_SKIA=false

pause
