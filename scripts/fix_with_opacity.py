#!/usr/bin/env python3
"""Replace deprecated `Color.withOpacity(x)` with `Color.withValues(alpha: x)`.

`withOpacity` is deprecated since Flutter 3.27 and goes through a deprecated
allocation path; `withValues(alpha:)` is the modern, allocation-friendly
replacement with identical semantics for 0..1 alpha values.
"""
import re
import sys
from pathlib import Path

PATTERN = re.compile(r"\.withOpacity\(([0-9a-zA-Z_.]*)\)")

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"

changed_files = []
total = 0
for path in sorted(LIB.rglob("*.dart")):
    original = path.read_text(encoding="utf-8")
    updated, count = PATTERN.subn(r".withValues(alpha: \1)", original)
    if count:
        path.write_text(updated, encoding="utf-8")
        changed_files.append((str(path.relative_to(ROOT)), count))
        total += count

for rel, count in changed_files:
    print(f"{count:3d}  {rel}")
print(f"\nTotal replacements: {total} across {len(changed_files)} files")
sys.exit(1 if not changed_files else 0)