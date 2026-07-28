#!/usr/bin/env python3
"""
NDU Project — Build Version Stamper
====================================

Stamps a unique build version (epoch seconds) into every deployment file that
references `NDU_BUILD_STAMP`. Run this AFTER `flutter build web` completes,
BEFORE deploying the build output.

What it does
------------
1. Computes a build stamp = current epoch seconds (e.g. "1781195800").
2. Walks the build/web/ directory (or a custom path) and replaces every
   literal occurrence of `NDU_BUILD_STAMP` with the stamp in:
     - index.html           (cache-busting ?v= param, redirect logic)
     - env-config.js        (window.__NDU_ENV.BUILD_STAMP)
     - flutter_service_worker.js  (CACHE_NAME = 'ndu-flutter-app-v<stamp>')
3. Also stamps the source `web/env-config.js` BUILD_STAMP so the next
   `flutter run` reflects the last deployed version.
4. Prints a summary of every file touched.

Usage
-----
    # Standard: stamp the latest `flutter build web` output
    python scripts/stamp_build_version.py

    # Custom build output path
    python scripts/stamp_build_version.py --build-dir path/to/build/web

    # Use a custom stamp instead of epoch seconds (e.g. a git SHA)
    python scripts/stamp_build_version.py --stamp abc123def

    # Dry run — show what would change without writing
    python scripts/stamp_build_version.py --dry-run

Why
---
Flutter's default web build pipeline produces files with no cache-busting
version. Browsers and CDNs happily serve stale main.dart.js for hours or
days after a new deploy, breaking the app for existing users. Stamping a
unique version into (a) every asset URL via ?v=<stamp>, (b) the service
worker's CACHE_NAME, and (c) the redirect logic in index.html guarantees
that every new deploy is picked up instantly.
"""

from __future__ import annotations

import argparse
import os
import sys
import time
from pathlib import Path

# Files (relative to build dir) that may contain NDU_BUILD_STAMP and should
# be stamped. We skip binary assets (.png, .wasm, .otf, etc.) — only text
# files need stamping.
STAMPABLE_EXTENSIONS = {
    ".html", ".js", ".json", ".css", ".txt", ".xml", ".svg",
}

# The placeholder we replace. Must match what's in index.html,
# flutter_service_worker.js, and env-config.js.
PLACEHOLDER = "NDU_BUILD_STAMP"


def compute_stamp(custom: str | None) -> str:
    """Return the build stamp to use."""
    if custom:
        return custom
    return str(int(time.time()))


def find_stampable_files(root: Path) -> list[Path]:
    """Walk `root` and return every text file that may contain the placeholder."""
    if not root.exists():
        return []
    out: list[Path] = []
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix.lower() not in STAMPABLE_EXTENSIONS:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        if PLACEHOLDER in text:
            out.append(path)
    return out


def stamp_file(path: Path, stamp: str, dry_run: bool) -> bool:
    """Replace PLACEHOLDER with `stamp` in `path`. Returns True if changed."""
    try:
        text = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError) as e:
        print(f"  ✗ {path} (read error: {e})")
        return False

    if PLACEHOLDER not in text:
        return False

    new_text = text.replace(PLACEHOLDER, stamp)
    count = text.count(PLACEHOLDER)

    if dry_run:
        print(f"  · {path} (would replace {count} occurrence(s))")
    else:
        path.write_text(new_text, encoding="utf-8")
        print(f"  ✓ {path} ({count} replacement(s))")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Stamp NDU_BUILD_STAMP into Flutter web build output.",
    )
    parser.add_argument(
        "--build-dir",
        default="build/web",
        help="Path to the flutter build web output directory (default: build/web).",
    )
    parser.add_argument(
        "--stamp",
        default=None,
        help="Custom build stamp (default: current epoch seconds).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would change without writing files.",
    )
    parser.add_argument(
        "--also-stamp-source-env",
        action="store_true",
        default=True,
        help="Also stamp web/env-config.js in source (default: True).",
    )
    args = parser.parse_args()

    stamp = compute_stamp(args.stamp)
    print(f"\nNDU Build Version Stamper")
    print(f"=========================")
    print(f"Stamp:     {stamp}")
    print(f"Build dir: {args.build_dir}")
    print(f"Dry run:   {args.dry_run}")
    print()

    # 1. Stamp the build output.
    build_root = Path(args.build_dir).resolve()
    if not build_root.exists():
        print(f"✗ Build directory not found: {build_root}")
        print(f"  Run `flutter build web` first, then re-run this script.")
        return 1

    files = find_stampable_files(build_root)
    if not files:
        print(f"✗ No files containing {PLACEHOLDER!r} found in {build_root}")
        return 1

    print(f"Stamping {len(files)} file(s) in {build_root}:")
    changed = 0
    for f in files:
        if stamp_file(f, stamp, args.dry_run):
            changed += 1
    print()

    # 2. Also stamp the source web/env-config.js so the BUILD_STAMP persists
    #    for the next `flutter run` session (purely cosmetic — helps with
    #    "what version am I running?" diagnostics).
    if args.also_stamp_source_env:
        source_env = Path("web/env-config.js").resolve()
        if source_env.exists():
            print(f"Also stamping source: {source_env}")
            stamp_file(source_env, stamp, args.dry_run)
            print()

    print(f"Done. {changed} file(s) {'would be ' if args.dry_run else ''}stamped with build version {stamp}.")
    if not args.dry_run:
        print(f"\nNext steps:")
        print(f"  1. Deploy the contents of {build_root} to your hosting provider.")
        print(f"  2. Verify the deploy by visiting the site — the URL should")
        print(f"     automatically get ?_ndu={stamp} appended on first load.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
