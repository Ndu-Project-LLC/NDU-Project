#!/usr/bin/env bash
# Builds the Google Play feature graphic from the app's own brand assets.
#
# Output : store/play/feature_graphic_1024x500.png
# Play spec: JPEG or 24-bit PNG (no transparency), exactly 1024x500, <= 15 MB.
#   -> PNG24 + `-alpha remove` guarantees the "no alpha" half of that spec.
#
# The palette is taken from the app itself, not invented:
#   background #110D16  assets/icons/app_icon_background.png (icon plate)
#   gold       #FFC812  lib/theme.dart lightPrimary ("Brand yellow")
#   muted      #9CA3AF  secondary text used across the screens
# Type is the brand face shipped in assets/fonts (Satoshi).
set -euo pipefail
cd "$(dirname "$0")/../.."

LOGO=assets/images/Logo.png
FONTS=assets/fonts
OUT_DIR=store/play
OUT="$OUT_DIR/feature_graphic_1024x500.png"

BG='#110D16'
GOLD='#FFC812'
MUTED='#9CA3AF'

[ -f "$LOGO" ] || { echo "missing $LOGO" >&2; exit 1; }
command -v magick >/dev/null || { echo "ImageMagick (magick) is required" >&2; exit 1; }

mkdir -p "$OUT_DIR"

magick -size 1024x500 "xc:$BG" \
  \( "$LOGO" -trim +repage -resize x150 \) -gravity north -geometry +0+95 -composite \
  -fill "$GOLD" -draw "rectangle 402,290 622,294" \
  -gravity north -font "$FONTS/Satoshi-Bold.otf" -pointsize 38 -fill "$GOLD" \
    -annotate +0+322 "Navigate. Deliver. Upgrade." \
  -gravity north -font "$FONTS/Satoshi-Medium.otf" -pointsize 24 -fill "$MUTED" \
    -annotate +0+392 "Full-lifecycle project delivery workspace" \
  -alpha remove -alpha off \
  "PNG24:$OUT"

magick identify -format 'wrote %f: %wx%h, channels=%[channels], depth=%z, size=%b\n' "$OUT"
