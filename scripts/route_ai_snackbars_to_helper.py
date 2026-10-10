#!/usr/bin/env python3
"""Route AI-failure snackbars/toasts through aiErrorMessage().

Scans lib/**/*.dart for UI error messages of the form
  'KAZ AI failed: $e' / 'AI generation failed: ${e.toString()}' / ...
and replaces the raw error interpolation so the user sees the friendly,
actionable message from lib/utils/ai_error_message.dart instead of the raw
OpenAI exception payload.

Rules:
- Only UI strings are touched (SnackBar/content/toast/info messages).
  debugPrint/print lines are left alone so logs keep the full raw error.
- If the message is exactly "<AI phrase>: <raw error>" the whole literal is
  replaced with aiErrorMessage(e). If it carries extra context (e.g.
  'AI generation failed for $section: ...') only the raw-error tail is
  replaced.
- Adds the ai_error_message import to every file it edits (sorted among the
  package:ndu_project/ imports, skipped if already present).

Usage: python3 scripts/route_ai_snackbars_to_helper.py
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"

IMPORT_LINE = "import 'package:ndu_project/utils/ai_error_message.dart';"

# Substrings (lower-cased) that identify an AI-failure message literal.
PHRASES = [
    "kaz ai failed",
    "kaz ai generation failed",
    "kaz ai regeneration failed",
    "kaz ai request failed",
    "kaz ai suggestion failed",
    "kaz ai error",
    "kaz ai model generation failed",
    "kaz ai field generation failed",
    "kaz ai integration generation failed",
    "ai generation failed",
    "ai regeneration failed",
    "ai autofill failed",
    "ai assist failed",
]

# Matches ": $e'", ": ${e}'", ": ${e.toString()}'" (and double-quoted).
TAIL_RE = re.compile(
    r":\s*(\$\{e\.toString\(\)\}|\$\{e\}|\$e)(['\"])"
)

def _transform_line(line: str) -> str:
    if "debugPrint" in line or "print(" in line:
        return line
    if "$e" not in line and "${e.toString()}" not in line and "${e}" not in line:
        return line

    changed = False
    out = line
    for m in reversed(list(TAIL_RE.finditer(line))):
        quote = m.group(2)
        open_idx = line.rfind(quote, 0, m.start())
        if open_idx < 0:
            continue
        prefix = line[open_idx + 1: m.start()].strip()
        if not any(p in prefix.lower() for p in PHRASES):
            continue
        if "$" in prefix:
            # Keep extra context (e.g. '... for $section: ...'), swap the tail.
            replacement = f": ${{aiErrorMessage(e)}}{quote}"
        else:
            # Pure "<phrase>: <raw>" -> drop the literal, use the helper.
            replacement = f"aiErrorMessage(e){quote}"
        out = out[: m.start()] + replacement + out[m.end():]
        changed = True
    return out if changed else line


def _add_import(text: str) -> str:
    if IMPORT_LINE in text:
        return text
    lines = text.split("\n")
    ndu_imports = [
        (i, ln) for i, ln in enumerate(lines)
        if ln.startswith("import 'package:ndu_project/")
    ]
    if not ndu_imports:
        return text
    insert_at = len(lines)
    for i, ln in ndu_imports:
        if ln.strip() >= IMPORT_LINE:
            insert_at = i
            break
    lines.insert(insert_at, IMPORT_LINE)
    return "\n".join(lines)


def main() -> int:
    total = 0
    changed_files = []
    for path in sorted(LIB.rglob("*.dart")):
        text = path.read_text()
        new_lines = []
        file_hits = 0
        for line in text.split("\n"):
            fixed = _transform_line(line)
            if fixed != line:
                file_hits += 1
            new_lines.append(fixed)
        if file_hits == 0:
            continue
        new_text = _add_import("\n".join(new_lines))
        path.write_text(new_text)
        total += file_hits
        changed_files.append((str(path.relative_to(ROOT)), file_hits))
        print(f"{file_hits:3d}  {path.relative_to(ROOT)}")

    print(f"\n{total} message(s) routed in {len(changed_files)} file(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())