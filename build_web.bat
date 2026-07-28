@echo off
REM Flutter Web Build Script with HTML Renderer
REM This script builds Flutter web with HTML renderer to avoid CDN timeout errors

echo Building Flutter web app with HTML renderer...
echo This avoids canvaskit CDN dependency and prevents timeout errors.

flutter build web --no-tree-shake-icons --dart-define=FLUTTER_WEB_USE_SKIA=false

echo.
echo Build complete! Files are in build/web/
pause
