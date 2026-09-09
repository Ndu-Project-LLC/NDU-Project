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


def write_version_json(build_root: Path, stamp: str, sha: str | None, dry_run: bool) -> bool:
    """Write build/web/version.json with the current build stamp + git SHA.

    The version.json file is fetched by the cache-bust script in index.html
    on every page load (cache-busted via a random query param, so it always
    bypasses HTTP cache). This lets the script detect when the user's
    browser-cached index.html is stale (i.e. when a new deploy happened
    but the user's HTTP cache for index.html hasn't expired yet —
    max-age=600 on GitHub Pages).

    Without this check, users with browser-cached OLD index.html will
    continue to see the OLD app for up to 10 minutes after each deploy
    because the OLD index.html's NDU_BUILD stamp is stale and the
    existing redirect logic only redirects to the OLD stamp.

    With this check, the script fetches version.json, gets the LATEST
    stamp, compares to the embedded NDU_BUILD, and if different,
    redirects to `?_ndu=<latest_stamp>` — forcing a fresh fetch of
    everything (index.html, flutter_bootstrap.js, main.dart.js).
    """
    import datetime
    version_path = build_root / "version.json"
    payload = {
        "build": stamp,
        "sha": sha or "",
        "deployed_at": datetime.datetime.now(datetime.timezone.utc)
        .strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    import json
    content = json.dumps(payload, indent=2, separators=(",", ": ")) + "\n"
    if dry_run:
        print(f"  · {version_path.name} (would write: {content.strip()})")
    else:
        version_path.write_text(content, encoding="utf-8")
        print(f"  ✓ {version_path.name} ({content.strip()})")
    return True


def get_git_sha() -> str | None:
    """Return the current git HEAD SHA (short), or None if not in a git repo."""
    import subprocess
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except (subprocess.SubprocessError, FileNotFoundError, OSError):
        pass
    return None


def patch_flutter_bootstrap_main_js_path(build_root: Path, stamp: str, dry_run: bool) -> bool:
    """Patch flutter_bootstrap.js so main.dart.js is loaded with ?v=<stamp>.

    Without this patch, flutter_bootstrap.js calls `_flutter.loader.load()`
    which uses `e.mainJsPath` (hardcoded as "main.dart.js") to create a
    <script src="main.dart.js"> tag. The browser fetches main.dart.js with
    NO query string, so GitHub Pages' `cache-control: max-age=600` causes
    the browser to serve a STALE cached main.dart.js for up to 10 minutes
    after each deploy — even when index.html has been refreshed.

    Fix: rewrite `"mainJsPath":"main.dart.js"` to `"mainJsPath":"main.dart.js?v=<stamp>"`
    in flutter_bootstrap.js. This makes the browser fetch a fresh main.dart.js
    on every deploy because the URL changes.
    """
    bootstrap_path = build_root / "flutter_bootstrap.js"
    if not bootstrap_path.exists():
        print(f"  · flutter_bootstrap.js not found at {bootstrap_path} — skipping mainJsPath patch.")
        return False

    try:
        text = bootstrap_path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError) as e:
        print(f"  ✗ flutter_bootstrap.js (read error: {e})")
        return False

    # The buildConfig JSON contains: "mainJsPath":"main.dart.js"
    # Rewrite to: "mainJsPath":"main.dart.js?v=<stamp>"
    # Only patch the EXACT un-stamped form (idempotent — safe to run multiple times).
    old = '"mainJsPath":"main.dart.js"'
    new = f'"mainJsPath":"main.dart.js?v={stamp}"'

    if old not in text:
        if new in text:
            print(f"  · flutter_bootstrap.js (mainJsPath already stamped to ?v={stamp})")
        else:
            print(f"  · flutter_bootstrap.js (no mainJsPath:\"main.dart.js\" found — skipping)")
        return False

    if dry_run:
        print(f"  · {bootstrap_path.name} (would patch mainJsPath → main.dart.js?v={stamp})")
    else:
        new_text = text.replace(old, new)
        bootstrap_path.write_text(new_text, encoding="utf-8")
        print(f"  ✓ {bootstrap_path.name} (mainJsPath → main.dart.js?v={stamp})")
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

    # 1b. Patch flutter_bootstrap.js so main.dart.js is loaded with ?v=<stamp>.
    #     This is critical for cache-busting main.dart.js on GitHub Pages, which
    #     serves all static files with cache-control: max-age=600. Without this
    #     patch, the browser would serve a stale cached main.dart.js for up to
    #     10 minutes after each deploy, even when index.html has been refreshed.
    print(f"Patching flutter_bootstrap.js mainJsPath:")
    patch_flutter_bootstrap_main_js_path(build_root, stamp, args.dry_run)
    print()

    # 1c. Write build/web/version.json — a small JSON file containing the
    #     current build stamp + git SHA + ISO timestamp. The index.html
    #     cache-bust script fetches this on every load (cache-busted via
    #     a random query param) to detect when the browser-cached
    #     index.html is stale. If the fetched stamp differs from the
    #     embedded NDU_BUILD, the script redirects to the new stamp,
    #     forcing a fresh fetch of all assets.
    print(f"Writing version.json:")
    write_version_json(build_root, stamp, get_git_sha(), args.dry_run)
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
