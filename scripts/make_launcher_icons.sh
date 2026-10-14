#!/usr/bin/env bash
# Installs the app's icon artwork and regenerates every launcher icon from it.
#
# Why a script: the two files flutter_launcher_icons reads are not both
# hand-drawn. `assets/icons/app_icon.png` is the finished artwork, but
# `assets/icons/app_icon_background.png` is *derived* from it — the art scaled
# to the 68% that `adaptive_icon_foreground_inset: 16` leaves visible, with its
# outermost row and column replicated outward. That matters: the artwork is
# opaque and its edge is glowy rather than flat black (up to 25/255 on the top
# edge), so a plain black plate stops the glow at the artwork's frame and the
# seam shows as a faint warm square inside the adaptive icon. Extending the
# artwork's own edge continues the glow, so the plate and the foreground meet at
# the same colour by construction.
#
# Usage:
#   scripts/make_launcher_icons.sh                          # rebuild from the current artwork
#   scripts/make_launcher_icons.sh path/to/new-artwork.png  # install new artwork, then rebuild
#
# Requires ImageMagick (`magick`) and Flutter's `dart` on PATH. Run from
# anywhere; paths are resolved against the repo root.
set -euo pipefail

cd "$(dirname "$0")/.."

ICON=assets/icons/app_icon.png
PLATE=assets/icons/app_icon_background.png
# Must match adaptive_icon_foreground_inset in pubspec.yaml: the plate has to
# place the art exactly where the inset puts the foreground, or the two layers
# no longer line up.
INSET_PERCENT=16
SIZE=1024

command -v magick >/dev/null || { echo "ImageMagick (magick) is required" >&2; exit 1; }

if [ "$#" -gt 0 ]; then
  SRC="$1"
  [ -f "$SRC" ] || { echo "no such artwork: $SRC" >&2; exit 1; }
  echo "=== Installing artwork: $SRC -> $ICON"
  magick "$SRC" -filter Lanczos -resize "${SIZE}x${SIZE}" \
    -alpha off -colorspace sRGB -strip -define png:compression-level=9 \
    "PNG24:$ICON"
fi

[ -f "$ICON" ] || { echo "missing $ICON (pass artwork as the first argument)" >&2; exit 1; }

# The visible share of the canvas, and the margin the plate extends across.
KEEP=$((SIZE * (100 - 2 * INSET_PERCENT) / 100))
MARGIN=$(((SIZE - KEEP) / 2))

echo "=== Deriving the adaptive plate: art at ${KEEP}px, edges extended to ${SIZE}px"
magick "$ICON" -filter Lanczos -resize "${KEEP}x${KEEP}" -alpha off \
  -virtual-pixel edge \
  -set option:distort:viewport "${SIZE}x${SIZE}-${MARGIN}-${MARGIN}" \
  -distort SRT 0 +repage -alpha off -colorspace sRGB -strip \
  -define png:compression-level=9 "PNG24:$PLATE"

echo "=== Generating launcher icons from pubspec.yaml"
dart run flutter_launcher_icons

echo "=== Sizes"
for f in "$ICON" "$PLATE"; do
  magick identify -format '%f: %wx%h, channels=%[channels]\n' "$f"
done
echo "Android mipmaps:"
magick identify -format '  %d/%f %wx%h\n' android/app/src/main/res/mipmap-*/ic_launcher.png | sort
echo "Android adaptive layers (foreground must be the full canvas, 16% is applied by"
echo "mipmap-anydpi-v26/ic_launcher.xml, not baked into the PNG):"
magick identify -format '  %d/%f %wx%h\n' android/app/src/main/res/drawable-xxxhdpi/ic_launcher_*.png | sort
