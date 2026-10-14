#!/usr/bin/env python3
"""Removes unused/duplicate import lines flagged by `flutter analyze lib`.

Run with:  python3 scripts/cleanup_dead_imports.py
Only exact lines reported by the analyzer are touched; anything that does not
match a simple `import ...;` statement is skipped and reported. Iterates to a
fixpoint because deleting one import can surface another.
"""
import re
import subprocess
import sys
from collections import defaultdict

ROUNDS = 4


def flagged_imports():
    """Return {path: [(lineno, rule, msg)]} from `flutter analyze lib`."""
    out = subprocess.run(
        ["flutter", "analyze", "lib"],
        capture_output=True,
        text=True,
    ).stdout
    pat = re.compile(
        r"\s*warning\s*•\s*(.*?)\s*•\s*(\S+):(\d+):(\d+)\s*•\s*(unused_import|duplicate_import)\s*$"
    )
    found = defaultdict(list)
    for line in out.splitlines():
        m = pat.match(line.rstrip())
        if m:
            msg, path, ln, col, rule = m.groups()
            found[path].append((int(ln), rule, msg))
    return found


def remove_line(path, lineno):
    with open(path, encoding="utf-8") as f:
        lines = f.readlines()
    if lineno - 1 >= len(lines):
        return False, "line out of range"
    line = lines[lineno - 1]
    stripped = line.strip()
    if not re.match(r"^import\s+", stripped):
        return False, f"not an import: {stripped[:60]!r}"
    del lines[lineno - 1]
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(lines)
    return True, line.rstrip("\n")


def main():
    total_removed = 0
    skipped = []
    for rnd in range(1, ROUNDS + 1):
        flagged = flagged_imports()
        count = sum(len(v) for v in flagged.values())
        if count == 0:
            print(f"round {rnd}: no unused/duplicate imports remain")
            break
        print(f"round {rnd}: {count} flagged import(s)")
        for path in sorted(flagged):
            # Remove in descending line order so earlier line numbers stay valid.
            for lineno, rule, _msg in sorted(flagged[path], reverse=True):
                ok, info = remove_line(path, lineno)
                if ok:
                    total_removed += 1
                else:
                    skipped.append((path, lineno, rule, info))
    print(f"removed: {total_removed}")
    if skipped:
        print(f"skipped ({len(skipped)}):")
        for path, ln, rule, info in skipped:
            print(f"  {path}:{ln} [{rule}] {info}")
    sys.exit(1 if skipped else 0)


if __name__ == "__main__":
    main()