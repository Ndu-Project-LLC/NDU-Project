#!/usr/bin/env python3
"""Turn recent git activity into a plain-language work report.

Run inside a GitHub Actions checkout with full history fetched. Prints an
HTML email body to stdout. Exit code 1 means the report could not be built
and the caller should abort rather than send a broken email.

The report is written for readers with no engineering background: changes
are grouped by topic, every technical word is explained, and the raw commit
list is kept at the bottom for anyone who wants the detail.
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

# Commit subjects are written by engineers, so map them onto plain verbs.
# Order matters: the first match wins.
PLAIN_RULES = [
    (r"\b(fix|fixes|fixed|fixing|bugfix|hotfix)\b", "Fixed"),
    (r"\b(revert|reverted)\b", "Undid an earlier change to"),
    (r"\b(add|adds|added|implements?|implemented)\b", "Added"),
    (r"\b(remove|removes|removed|delete|deletes|deleted|cleanup|clean up)\b", "Removed"),
    (r"\b(enable|enables|enabled)\b", "Turned on"),
    (r"\b(disable|disables|disabled)\b", "Turned off"),
    (r"\b(support|supports|supported)\b", "Added support for"),
    (r"\b(update|updates|updated|upgrade|upgrades|upgraded|bump|bumped)\b", "Updated"),
    (r"\b(refactor|refactored|simplif\w*|extract|extracted)\b", "Tidied up"),
    (r"\b(perf|performance|optimi[sz]\w*)\b", "Made faster:"),
    (r"\b(security|vulnerab\w*|auth|permission)\b", "Improved security:"),
    (r"\b(tests?|coverage)\b", "Added tests for"),
    (r"\b(docs?|documentation|readme)\b", "Wrote documentation for"),
]

# Order matters: the first match wins, so put specific areas first and the
# broad ones last. Every alternative is word-bounded -- an unbounded `auth`
# would match "auto" and mislabel half the report.
TOPIC_RULES = [
    (r"\b(login|auth|sign[- ]?in|signup|log[- ]?in|password|session|account)\b", "Sign-in and accounts"),
    (r"\b(admin|moderation|back[- ]?office)\b", "The admin area"),
    (r"\b(deploy|deploys|deployment|staging|production|hosting|firebase|vercel|ci|cd|pipeline|analyzer|preflight|analyze)\b", "Website releases and quality checks"),
    (r"\b(payment|payments|billing|stripe|subscription|invoice|pricing)\b", "Payments"),
    (r"\b(video|videos|render|rendering|timeline|media|transcode|audio|music)\b", "Video and media"),
    (r"\b(api|apis|endpoint|endpoints|server|backend|llm|ai|agent|prompt)\b", "Backend and AI features"),
    (r"\b(db|database|databases|firestore|migration|schema|index|query)\b", "The database"),
    (r"\b(mobile|ios|android|flutter|app store)\b", "The mobile app"),
    (r"\b(pdf|export|exports|spreadsheet|csv|excel|import|imports|download|template)\b", "Imports, exports and reports"),
    (r"\b(web|website|landing|page|pages|frontend|ui|ux|design|layout|css|style)\b", "The website and how it looks"),
]
GENERAL_TOPIC = "Other project work"

GLOSSARY = [
    ("Change", "one saved update to the project. A single change can touch many files."),
    ("Lines added / removed", "how much code was written or taken out. More lines is not automatically better."),
    ("Staging", "the test copy of the website (staging.nduproject.com). Work is checked there before it goes live."),
    ("Deployment", "copying the latest work onto a website so people can see it."),
]

ESC = html.escape

# Shared inline styles. Email clients ignore <style> blocks, so everything is inline.
FONT = "-apple-system,Segoe UI,Helvetica,Arial,sans-serif"
H2 = f"font:600 17px/1.4 {FONT};color:#111827;margin:28px 0 10px 0;"
H3 = f"font:600 15px/1.4 {FONT};color:#111827;margin:18px 0 6px 0;"
P = f"font:400 15px/1.6 {FONT};color:#374151;margin:0 0 12px 0;"
LI = f"margin:0 0 8px 0;"
SMALL = f"font:400 13px/1.6 {FONT};color:#6b7280;"


def git(*args, since=None):
    cmd = ["git"] + list(args)
    if since:
        cmd += ["--since", since]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed: {res.stderr.strip()}")
    return res.stdout.strip()


def classify(subject, body):
    """Split one commit into (topic, plain-English sentence)."""
    subject = re.sub(r"^(feat|fix|chore|docs|refactor|style|test|perf|build|ci)(\([^)]*\))?!?:\s*", "", subject).strip()

    topic = GENERAL_TOPIC
    haystack = subject + " " + body
    for pattern, label in TOPIC_RULES:
        if re.search(pattern, haystack, re.I):
            topic = label
            break

    # Turn "Fix the login redirect" into "Fixed the login redirect". If the
    # verb is not at the start of the subject, keep the subject as written,
    # since it already reads as a plain sentence.
    for pattern, verb in PLAIN_RULES:
        m = re.match(r"\s*" + pattern, subject, re.I)
        if m:
            detail = subject[m.end():].strip(" :-—")
            if detail:
                detail = detail[0].lower() + detail[1:]
                sentence = f"{verb} {detail}"
            else:
                sentence = verb
            break
    else:
        # No verb we recognise: the subject already reads as a plain sentence.
        sentence = subject or "Worked on the project"

    sentence = sentence.rstrip(".")
    sentence = sentence[0].upper() + sentence[1:] if sentence else sentence
    return topic, sentence


def main():
    hours = int(os.environ.get("REPORT_WINDOW_HOURS", "24"))
    now = datetime.now(timezone.utc)
    since_dt = now - timedelta(hours=hours)
    since = f"{hours} hours ago"

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
        topic, sentence = classify(subject, body)
        commits.append({
            "sha": sha,
            "subject": subject,
            "author": author,
            "topic": topic,
            "sentence": sentence,
        })

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

    period_start = since_dt.strftime("%B %-d, %Y at %-I:%M %p UTC")
    period_end = now.strftime("%B %-d, %Y at %-I:%M %p UTC")
    title = "What the team did in the last " + (f"{hours} hours" if hours != 24 else "24 hours")
    subject_line = f"Work Report — {now.strftime('%B %-d, %Y')}"

    by_topic = defaultdict(list)
    for c in commits:
        by_topic[c["topic"]].append(c)
    # Biggest topics first; the catch-all "Other project work" always goes last.
    topic_order = sorted(
        by_topic,
        key=lambda t: (t == GENERAL_TOPIC, -len(by_topic[t]), t),
    )
    author_counts = Counter(c["author"] for c in commits)
    people_count = len(author_counts)

    # ── Short summary, written as plain sentences ──
    if commits:
        n = len(commits)
        people_phrase = (
            f"{people_count} person" if people_count == 1 else f"{people_count} people"
        )
        short_summary = (
            f"{n} {'change was' if n == 1 else 'changes were'} saved to the project "
            f"by {people_phrase}. Together they added about {total_add:,} lines of code "
            f"and removed about {total_del:,}. The work is listed below, grouped by topic, "
            f"so you can see at a glance which parts of the project moved forward."
        )
    else:
        short_summary = (
            f"Nothing new was saved to the project in the last {hours} {'hour' if hours == 1 else 'hours'}, "
            f"so there is no new work to report for this period."
        )

    def stat_card(number, label):
        return (
            f"<td style=\"background:#f9fafb;border-radius:8px;padding:12px;text-align:center;\">"
            f"<div style=\"font:700 22px/1.2 {FONT};color:#111827;\">{number}</div>"
            f"<div style=\"{SMALL}\">{ESC(label)}</div></td>"
        )

    stats_html = ""
    if commits:
        stats_html = (
            "<table role=\"presentation\" style=\"border-collapse:separate;border-spacing:8px 0;margin:0 -8px 8px -8px;width:calc(100% + 16px);\"><tr>"
            + stat_card(f"{len(commits):,}", "changes saved")
            + stat_card(f"{people_count:,}", "people involved")
            + stat_card(f"+{total_add:,}", "lines added")
            + stat_card(f"−{total_del:,}", "lines removed")
            + "</tr></table>"
        )

    topic_sections = []
    for topic in topic_order:
        items = by_topic[topic]
        bullets = "\n".join(
            f"      <li style=\"{LI}\">{ESC(c['sentence'])}.</li>" for c in items
        )
        topic_sections.append(
            f"    <h3 style=\"{H3}\">{ESC(topic)} <span style=\"font-weight:400;color:#6b7280;\">({len(items)})</span></h3>\n"
            f"    <ul style=\"margin:0;padding-left:20px;font:400 15px/1.6 {FONT};color:#374151;\">\n"
            f"{bullets}\n    </ul>"
        )

    who_html = ""
    if author_counts:
        who_items = "\n".join(
            f"      <li style=\"{LI}\">{ESC(name)}: {count} {'change' if count == 1 else 'changes'}</li>"
            for name, count in author_counts.most_common()
        )
        who_html = (
            f"    <h2 style=\"{H2}\">Who did the work</h2>\n"
            f"    <ul style=\"margin:0;padding-left:20px;font:400 15px/1.6 {FONT};color:#374151;\">\n"
            f"{who_items}\n    </ul>"
        )

    glossary_items = "\n".join(
        f"      <li style=\"{LI}\"><strong>{ESC(term)}</strong>: {ESC(meaning)}</li>"
        for term, meaning in GLOSSARY
    )
    glossary_html = (
        f"    <h2 style=\"{H2}\">New to these reports? Key words</h2>\n"
        f"    <ul style=\"margin:0;padding-left:20px;font:400 14px/1.6 {FONT};color:#374151;\">\n"
        f"{glossary_items}\n    </ul>"
    )

    technical_html = ""
    if commits:
        rows = "\n".join(
            f"      <tr><td style=\"padding:4px 8px 4px 0;{SMALL}white-space:nowrap;\">{ESC(c['sha'][:7])}</td>"
            f"<td style=\"padding:4px 0;{SMALL}\">{ESC(c['subject'])}</td></tr>"
            for c in commits
        )
        technical_html = (
            f"    <h2 style=\"{H2}\">Technical log (optional)</h2>\n"
            f"    <p style=\"{SMALL}margin:0 0 8px 0;\">Each row is one saved change: a short ID, then the developer's original note. "
            f"You can skip this section if you only want the summary.</p>\n"
            f"    <table style=\"border-collapse:collapse;width:100%;\">\n{rows}\n    </table>"
        )

    body_html = f"""<!doctype html>
<html>
<body style="margin:0;padding:24px;background:#f3f4f6;font-family:{FONT};">
  <div style="max-width:640px;margin:0 auto;background:#ffffff;border-radius:12px;padding:32px;">
    <p style="margin:0 0 4px 0;{SMALL}">Work report · {ESC(subject_line)}</p>
    <h1 style="font:700 24px/1.3 {FONT};color:#111827;margin:0 0 6px 0;">{ESC(title)}</h1>
    <p style="margin:0 0 20px 0;{SMALL}">Covers {ESC(period_start)} to {ESC(period_end)}.</p>

    <h2 style="{H2}margin-top:0;">The short version</h2>
    <p style="{P}">{ESC(short_summary)}</p>
{stats_html}
    <h2 style="{H2}">What got done, by topic</h2>
{chr(10).join(topic_sections) if topic_sections else f'    <p style="{P}">No changes to list.</p>'}

{who_html}

{glossary_html}

{technical_html}

    <p style="margin:28px 0 0 0;{SMALL}">
      Sent automatically. You are receiving this because you are on the project's update list.
      {('View the project on GitHub: <a href="' + ESC(REPO_URL) + '" style="color:#2563eb;">' + ESC(REPO_URL) + '</a>') if REPO_URL else ''}
    </p>
  </div>
</body>
</html>"""

    print(body_html)
    return 0


if __name__ == "__main__":
    sys.exit(main())
