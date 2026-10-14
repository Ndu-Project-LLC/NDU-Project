#!/usr/bin/env python3
"""Find State classes that declare controller fields but never dispose() them.

A missing dispose() on TextEditingController/ScrollController/TabController/
AnimationController/PageController keeps the controller (and its listeners)
alive until the enclosing State is GC'd — a classic Flutter memory leak on
every navigation into and out of the screen.

Prints file:class for every suspect so they can be fixed by hand.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"

CONTROLLER_TYPES = (
    "TextEditingController",
    "ScrollController",
    "TabController",
    "AnimationController",
    "PageController",
    "RichTextEditingController",
)

# A controller field declaration: `final X _name = ...` or `late final X _name;`
FIELD_RE = re.compile(
    r"(?:final|late final)\s+(\w*Controller)\s+(\w+)\s*[;=]"
)

suspects = []
for path in sorted(LIB.rglob("*.dart")):
    text = path.read_text(encoding="utf-8")
    # Split into top-level class bodies (naive brace counting is fine here
    # because we only need the class that declares the State).
    class_re = re.compile(
        r"class\s+(_?\w+)\s+extends\s+State<[^>]+>\s*\{", re.MULTILINE
    )
    pos = 0
    for m in class_re.finditer(text):
        start = m.end()
        depth = 1
        i = start
        while i < len(text) and depth > 0:
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
            i += 1
        body = text[start : i - 1]
        fields = [
            (t, n)
            for t, n in FIELD_RE.findall(body)
            if t in CONTROLLER_TYPES
        ]
        if not fields:
            continue
        has_dispose = "dispose()" in body
        if not has_dispose:
            suspects.append((str(path.relative_to(ROOT)), m.group(1), fields))

if not suspects:
    print("No undisposed controller fields found.")
    sys.exit(0)

for rel, cls, fields in suspects:
    names = ", ".join(f"{t} {n}" for t, n in fields)
    print(f"{rel} :: {cls} -> {names}")
print(f"\n{len(suspects)} suspect State classes")
sys.exit(1)