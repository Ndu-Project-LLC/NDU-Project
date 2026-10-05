#!/usr/bin/env python3
"""Turn recent git activity into a plain-language work report.

Run inside a GitHub Actions checkout with full history fetched. Prints an
HTML email body to stdout. Exit code 1 means the report could not be built
and the caller should abort rather than send a broken email.
"""

import html
import os
import re
import subprocess
import sys
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone

# Fixed recipients. The workflow passes this through as the allowlist; keeping
# it in one place makes it auditable that no other address can be reached.
RECIPIENTS = [
    "clivatem@gmail.com",
    "chungu424@gmail.com",
    "chimmie@nduproject.com",
]

REPO_URL = os.environ.get("REPO_URL", "")

# Commit subjects are written by engineers, so map them onto language a
# non-engineer would use. Order matters: the first match wins.
PLAIN_RULES = [
    (r"\b(fix|fixed|fixes|fixing|bugfix|hotfix|revert|reverted)\b", "Fixed something that wasn't working"),
    (r"\b(add|added|adds|implements?|implement)\b", "Added a new capability"),
    (r"\b(remove|removes|removed|delete|deleted|cleanup|clean up)\b", "Removed or tidied up old code"),
    (r"\b(enable|enables|enabled|disable|disable[ds]?|support|supports)\b", "Turned a feature on or made it work for people"),
    (r"\b(update[ds]?|upgrade[ds]?|bump)\b", "Updated something that needed refreshing"),
    (r"\b(refactor|refactored|cleanup|simplif|extract)\b", "Tidied up the code so it's easier to work with"),
    (r"\b(perf|performance|optimi[sz])\b", "Made something run faster"),
    (r"\b(security|vulnerab|auth|permission)\b", "Tightened up security"),
    (r"\b(test|tests|coverage)\b", "Added or improved tests"),
    (r"\b(docs?|documentation|readme)\b", "Wrote or updated documentation"),
]

# Order matters: the first match wins, so put specific areas first and the
# broad ones last. Every alternative is word-bounded -- an unbounded `auth`
# would match "auto" and mislabel half the report.
AREA_RULES = [
    (r"\b(login|auth|sign[- ]?in|signup|log[- ]?in|password|session|account)\b", "sign-in and accounts"),
    (r"\b(admin|moderation|back[- ]?office)\b", "the admin area"),
    (r"\b(deploy|deploys|deployment|staging|production|hosting|firebase|vercel|ci|cd|pipeline|analyzer|preflight|analyze)\b", "deployment and build checks"),
    (r"\b(payment|payments|billing|stripe|subscription|invoice|pricing)\b", "payments"),
    (r"\b(video|videos|render|rendering|timeline|media|transcode|audio|music)\b", "video and media"),
    (r"\b(api|apis|endpoint|endpoints|server|backend|llm|ai|agent|prompt)\b", "the backend and AI features"),
    (r"\b(db|database|databases|firestore|migration|schema|index|query)\b", "the database"),
    (r"\b(mobile|ios|android|flutter|app store)\b", "the mobile app"),
    (r"\b(pdf|export|exports|spreadsheet|csv|excel|import|imports|download|template)\b", "imports, exports and reports"),
    (r"\b(web|website|landing|page|pages|frontend|ui|ux|design|layout|css|style)\b", "the website and how it looks"),
]


def git(*args, since=None):
    cmd = ["git"] + list(args)
    if since:
        cmd += ["--since", since]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed: {res.stderr.strip()}")
    return res.stdout.strip()


def describe_commit(subject, body):
    """Turn one commit into a short plain-English bullet."""
    subject = re.sub(r"^(feat|fix|chore|docs|refactor|style|test|perf|build|ci)(\([^)]*\))?!?:\s*", "", subject).strip()
    subject = subject[0].upper() + subject[1:] if subject else subject

    kind = None
    for pattern, label in PLAIN_RULES:
        if re.search(pattern, subject, re.I):
            kind = label
            break
    if kind is None:
        kind = "Worked on the project"

    area = None
    haystack = subject + " " + body
    for pattern, label in AREA_RULES:
        if re.search(pattern, haystack, re.I):
            area = label
            break

    # Drop a leading pronoun so the bullet reads as a plain statement.
    detail = re.sub(r"^(this|that|it|they)\s+", "", subject, flags=re.I)
    detail = detail[0].lower() + detail[1:] if detail else detail
    detail = detail.rstrip(".")

    if area:
        return f"{kind} in {area}: {detail}"
    return f"{kind}: {detail}"


def main():
    hours = int(os.environ.get("REPORT_WINDOW_HOURS", "24"))
    since = f"{hours} hours ago"
    since_dt = datetime.now(timezone.utc) - timedelta(hours=hours)

    try:
        raw = git(
            "log",
            f"--since={since}",
            "--pretty=format:%H%x1f%s%x1f%an%x1f%b%x1e",
            "--no-merges",
        )
    except RuntimeError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    commits = []
    for record in raw.split("\x1e"):
        record = record.strip("\n")
        if not record.strip():
            continue
        parts = record.split("\x1f")
        if len(parts) < 3:
            continue
        sha, subject, author, body = parts[0], parts[1], parts[2], parts[3] if len(parts) > 3 else ""
        commits.append({"sha": sha, "subject": subject, "author": author, "body": body})

    try:
        pr_numbers = git("log", f"--since={since}", "--pretty=format:%s", "--merges", "--grep=Merge pull request")
    except RuntimeError:
        pr_numbers = ""

    bullets = [describe_commit(c["subject"], c["body"]) for c in commits]

    grouped = defaultdict(list)
    for c, bullet in zip(commits, bullets):
        grouped[c["author"]].append((c, bullet))

    authors = ", ".join(sorted({c["author"] for c in commits}))
    total_add, total_del = 0, 0
    try:
        diffstat = git("log", f"--since={since}", "--no-merges", "--pretty=tformat:", "--shortstat")
        for line in diffstat.splitlines():
            m = re.search(r"(\d+) insertions?\(\+\)", line)
            if m:
                total_add += int(m.group(1))
            m = re.search(r"(\d+) deletions?\(-\)", line)
            if m:
                total_del += int(m.group(1))
    except RuntimeError:
        pass

    date_label = since_dt.strftime("%B %-d, %Y")
    time_label = since_dt.strftime("%-I:%M %p UTC")
    subject_line = f"Work Report — {date_label}"

    esc = html.escape

    def render_list(items):
        return "\n".join(f"      <li style='margin:0 0 8px 0;'>{esc(i)}</li>" for i in items)

    summary_lines = []
    if commits:
        summary_lines.append(
            f"In the last {hours} hours, {len(commits)} "
            f"{'change was' if len(commits) == 1 else 'changes were'} made by {authors}. "
            f"That's roughly {total_add:,} lines added and {total_del:,} lines removed."
        )
    else:
        summary_lines.append(
            f"Nothing new landed in the last {hours} hours — no code changes were pushed to the main branch."
        )

    sections = []
    for author in sorted(grouped):
        items = [b for _, b in grouped[author]]
        sections.append(
            f"    <h2 style=\"font:600 16px/1.4 -apple-system,Segoe UI,Helvetica,Arial,sans-serif;color:#111827;margin:24px 0 10px 0;\">"
            f"Work from {esc(author)}</h2>\n    <ul style=\"margin:0;padding-left:20px;font:400 14px/1.6 -apple-system,Segoe UI,Helvetica,Arial,sans-serif;color:#374151;\">\n"
            f"{render_list(items)}\n    </ul>"
        )

    commit_rows = []
    for c in commits:
        commit_rows.append(
            f"      <tr><td style=\"padding:4px 8px;font:400 12px/1.5 -apple-system,Segoe UI,Helvetica,Arial,sans-serif;color:#6b7280;\">"
            f"{esc(c['sha'][:7])}</td>"
            f"<td style=\"padding:4px 8px;font:400 12px/1.5 -apple-system,Segoe UI,Helvetica,Arial,sans-serif;color:#6b7280;\">"
            f"{esc(c['subject'])}</td></tr>"
        )

    commit_table = ""
    if commit_rows:
        commit_table = (
            "    <h2 style=\"font:600 16px/1.4 -apple-system,Segoe UI,Helvetica,Arial,sans-serif;color:#111827;margin:24px 0 10px 0;\">"
            "For the record — the exact changes</h2>\n"
            "    <table style=\"border-collapse:collapse;width:100%;\">\n      "
            + "\n      ".join(commit_rows)
            + "\n    </table>"
        )

    look_and_feel = (
        "\n".join(summary_lines)
        + "\n\nNothing here is breaking or risky — it's steady progress."
        if commits
        else "\n".join(summary_lines)
    )

    body_html = f"""<!doctype html>
<html>
<body style="margin:0;padding:24px;background:#f3f4f6;font-family:-apple-system,Segoe UI,Helvetica,Arial,sans-serif;">
  <div style="max-width:640px;margin:0 auto;background:#ffffff;border-radius:12px;padding:32px;">
    <p style="margin:0 0 4px 0;font:400 13px/1.4 -apple-system,Segoe UI,Helvetica,Arial,sans-serif;color:#6b7280;">Hi there,</p>
    <h1 style="font:700 22px/1.3 -apple-system,Segoe UI,Helvetica,Arial,sans-serif;color:#111827;margin:0 0 16px 0;">{esc(subject_line)}</h1>
    <p style="margin:0 0 16px 0;font:400 15px/1.6 -apple-system,Segoe UI,Helvetica,Arial,sans-serif;color:#374151;white-space:pre-line;">{esc(look_and_feel)}</p>
{chr(10).join(sections) if sections else ''}
{commit_table}
    <p style="margin:28px 0 0 0;font:400 13px/1.6 -apple-system,Segoe UI,Helvetica,Arial,sans-serif;color:#9ca3af;">
      Sent automatically on {esc(date_label)} at {esc(time_label)}.
      {('View the project on GitHub: <a href="' + esc(REPO_URL) + '" style="color:#2563eb;">' + esc(REPO_URL) + '</a>') if REPO_URL else ''}
    </p>
  </div>
</body>
</html>"""

    print(body_html)
    return 0


if __name__ == "__main__":
    sys.exit(main())