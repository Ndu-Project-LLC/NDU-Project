#!/usr/bin/env python3
"""Score a document with an AI-detection API and list the sentences it flags.

The point of this script is to turn "the detector says 100%" into a list of
specific sentences, so edits can be aimed at something real instead of rewriting
the whole document and hoping.

Usage:
    export GPTZERO_API_KEY=...
    python3 scripts/ai_detector_check.py docs/canonical_submission.txt
    python3 scripts/ai_detector_check.py docs/canonical_submission.md --min 0.4
    python3 scripts/ai_detector_check.py docs/canonical_submission.txt --json /tmp/report.json

Notes:
  * Only GPTZero is wired up, because that is the only provider whose request
    shape is confirmed (POST /v2/predict/text, `x-api-key` header, body
    {"document": "..."}). Sapling, Winston, Copyleft and Originality all need
    keys too; add them to PROVIDERS after checking their current docs rather
    than guessing the payload.
  * The key is read from the environment and never written to disk or echoed.
  * Answers-only input is cleaner than a whole document: the question prompts
    belong to the employer, not the candidate, and scoring them tells you
    nothing useful.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request

GPTZERO_URL = "https://api.gptzero.me/v2/predict/text"
GPTZERO_KEY_ENV = "GPTZERO_API_KEY"

# Cloudflare fronts api.gptzero.me and rejects the default "Python-urllib/x.y"
# signature with 1010 Access denied before the request is ever authenticated.
# A descriptive client identity gets through and the call then fails or succeeds
# on the API key alone, which is what we want.
CLIENT_ID = "ai-detector-check/1.0 (local scoring script)"


def strip_markdown(text: str) -> str:
    """Reduce a Markdown source to the prose a detector should actually see."""
    if text.startswith("---"):
        parts = text.split("---", 2)
        if len(parts) == 3:
            text = parts[2]
    # Bold question lines are the employer's text: keep them out of the sample.
    text = re.sub(r"^\*\*.+?\*\*\s*$", "", text, flags=re.M)
    text = re.sub(r"^#+\s*", "", text, flags=re.M)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def load_document(path: str) -> str:
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    if path.endswith((".md", ".markdown")):
        text = strip_markdown(text)
    return text


def gptzero(text: str, timeout: int = 120) -> dict:
    key = os.environ.get(GPTZERO_KEY_ENV)
    if not key:
        sys.exit(f"{GPTZERO_KEY_ENV} is not set. Export your key, then re-run.")
    request = urllib.request.Request(
        GPTZERO_URL,
        data=json.dumps({"document": text}).encode("utf-8"),
        method="POST",
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": CLIENT_ID,
            "x-api-key": key,
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")[:500]
        sys.exit(f"GPTZero returned HTTP {error.code}: {detail}")


PROVIDERS = {"gptzero": gptzero}


def sentence_rows(payload: dict) -> list[tuple[float, str]]:
    rows: list[tuple[float, str]] = []
    for item in payload.get("documents") or [payload]:
        for sentence in item.get("sentences") or []:
            text = (sentence.get("sentence") or "").strip()
            probability = sentence.get("generated_prob")
            if probability is None:
                probability = sentence.get("completely_generated_prob")
            if text and probability is not None:
                rows.append((float(probability), text))
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", help="file to score (.txt, .md or .docx-derived text)")
    parser.add_argument("--provider", default="gptzero", choices=sorted(PROVIDERS))
    parser.add_argument("--min", type=float, default=0.5,
                        help="report sentences at or above this probability (default 0.5)")
    parser.add_argument("--top", type=int, default=0, help="show only the N worst sentences")
    parser.add_argument("--json", dest="json_path", help="also write the raw response here")
    args = parser.parse_args()

    text = load_document(args.path)
    if not text:
        sys.exit(f"{args.path} produced no text to score.")

    payload = PROVIDERS[args.provider](text)

    classification = payload.get("document_classification", "?")
    probabilities = payload.get("class_probabilities") or {}
    ai_share = probabilities.get("ai")
    confidence = payload.get("confidence_category", "?")
    word_count = len(text.split())

    print(f"file            {args.path} ({word_count} words, {args.provider})")
    if ai_share is not None:
        print(f"document score  {ai_share:.1%} AI  [{classification}, confidence {confidence}]")
    else:
        print(f"document score  [{classification}, confidence {confidence}]")

    rows = sorted(sentence_rows(payload), key=lambda pair: -pair[0])
    flagged = [row for row in rows if row[0] >= args.min]
    if args.top:
        flagged = flagged[: args.top]

    print(f"sentences       {len(rows)} scored, {len(flagged)} at or above {args.min:.0%}\n")
    for probability, sentence in flagged:
        print(f"  {probability:5.1%}  {sentence}")

    if args.json_path:
        with open(args.json_path, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2)
        print(f"\nraw response written to {args.json_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
