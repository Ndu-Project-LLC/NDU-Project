#!/usr/bin/env python3
"""Build the NDU Project Change Management module report as a PPTX deck.

Reuses the "Day One Report Template.pptx" layout verbatim (title bar, status
legend, Overall Update / Activities / Recent / Planned columns, 8 status dots)
and produces one slide per report section. Only slide text and dot status
colors are changed; shapes, positions, fonts and the legend are preserved.
"""

import os
import re
import shutil
import sys
import zipfile
import xml.sax.saxutils as sax

TPL = "/Applications/Ndu_Project-main/functions/Day One Report Template.pptx"
OUT_DIR = "/Applications/Ndu_Project-main/reports"
OUT = os.path.join(OUT_DIR, "ndu_change_management_module_report.pptx")
WORK = "/tmp/cm_pptx_build"

DOT_GREEN = "00B050"
DOT_YELLOW = "FFFF00"
DOT_RED = "FF0000"
DOT_BLUE = "0070C0"
COLORS = {"G": DOT_GREEN, "Y": DOT_YELLOW, "R": DOT_RED, "B": DOT_BLUE}

# (position of dot on the template slide) -> slot index 0..7
DOT_SLOTS = [
    ((7016779, 990710), 0),
    ((7856498, 990710), 1),
    ((8647598, 990710), 2),
    ((9481060, 990710), 3),
    ((7016779, 1358470), 4),
    ((7856498, 1350791), 5),
    ((8641341, 1358470), 6),
    ((9481060, 1340157), 7),
]

# ---------------------------------------------------------------------------
# Slide content — mirrors the sections of the HTML/PDF report.
# ---------------------------------------------------------------------------
SLIDES = [
    {
        "title": "Change Management Module — DONE",
        "overall": [
            "Entire Change Management module is DONE",
            "All 8 workspace tabs delivered and live",
            "Firestore persistence wired end-to-end",
            "0 analyze errors • 164/164 tests passing",
            "Module ready for approval review",
        ],
        "activities": [
            "Change Register: 15 change types, 10 statuses, emergency lane",
            "Impact assessment: 15 dimensions + weighted composite score",
            "Approval workflow: 10 roles, 7 decisions, workflow builder",
            "Audit trail with filters + CSV export",
            "Apply-to-baseline with rollback + baseline history",
        ],
        "recent": [
            "8-tab Change Management module completed",
            "Firestore read + write sync secured by rules",
            "CRs auto-populated from real project constraints",
        ],
        "planned": [
            "RBAC enforcement across approval roles",
            "Client demo / approval review session",
        ],
        "issues": ["None — module shipped clean (0 errors, 164 tests)"],
        "dots": ["G", "G", "G", "G", "G", "G", "G", "Y"],
    },
    {
        "title": "Change Register & Lifecycle",
        "overall": [
            "Register live with real Firestore data",
            "CR numbers auto-generated (CR-2026-XXX)",
            "Filters: status, priority, search",
            "Composite-impact badges on every row",
            "Detail panel shows the approval workflow",
        ],
        "activities": [
            "Lifecycle: Draft → Submitted → Review → Approval",
            "Approved → Implemented → Closed",
            "Emergency lane for urgent changes",
            "Rejected / Returned for Revision paths",
            "Agile routine refinement vs controlled baseline change",
        ],
        "recent": [
            "CRs auto-seeded from risk register + execution change requests",
            "No phantom or demo data in the register",
            "Cost and schedule impact columns per row",
        ],
        "planned": ["Approval-role RBAC to govern who can act"],
        "issues": ["None — register behavior verified against Firestore"],
        "dots": ["G", "G", "G", "G", "G", "G", "G", "G"],
    },
    {
        "title": "Impact Assessment & Approvals",
        "overall": [
            "15-dimension impact grid, scored 0–5 each",
            "Composite score weights Scope/Schedule/Cost ×2",
            "Cost + schedule impact totals per CR",
            "Re-baseline triggered by any cost/schedule impact",
            "10 approval roles across the workflow",
        ],
        "activities": [
            "Workflow builder: add steps, assign roles, set due dates",
            "Decisions: approve, reject, request info, return, delegate, escalate",
            "Contingency ($500K) and reserve ($1M) drawdown on approval",
            "Average approval cycle time tracked per quarter",
            "Emergency CRs auto-fast-track to PM + Sponsor",
        ],
        "recent": [
            "Impact Detail tab with live score recompute",
            "Horizontal bar chart of dimension impact",
        ],
        "planned": ["Role-based approval gates once RBAC lands"],
        "issues": ["None"],
        "dots": ["G", "G", "G", "G", "G", "G", "G", "Y"],
    },
    {
        "title": "Baseline, Data & Security",
        "overall": [
            "Apply-to-baseline creates a revision record",
            "BAC, scope hash, finish date updated",
            "Rollback restores the previous baseline",
            "Audit trail: every action logged with actor",
            "CSV export of the full audit trail",
        ],
        "activities": [
            "Firestore: users/{uid}/changeManagement/* collections",
            "Real-time listeners on CRs, audit, baseline",
            "Rules: owner-scoped reads/writes + project-level scope",
            "Writes are fire-and-forget with error logging",
            "State recomputed from persisted data on reload",
        ],
        "recent": [
            "Write path wired into all mutation funnels",
            "Rollback deletes the exact revision document",
        ],
        "planned": ["Cross-workspace sharing for the register"],
        "issues": ["None"],
        "dots": ["G", "G", "G", "G", "G", "G", "G", "G"],
    },
    {
        "title": "Verification & Approval",
        "overall": [
            "flutter analyze: 0 errors on staging",
            "164/164 tests passing",
            "74 commits across Project Controls history",
            "726 total commits on staging branch",
            "Ready for approval — no open module work",
        ],
        "activities": [
            "Recommended: approve module as delivered",
            "6-item scope: register, impact, workflow, audit, baseline, persistence",
            "Follow-on: RBAC enforcement per role recommendation report",
        ],
        "recent": [
            "Persistence wiring verified with analyze + tests",
            "Report generated in Day One Report format",
        ],
        "planned": ["Client demo session"],
        "issues": ["None"],
        "dots": ["G", "G", "G", "G", "G", "G", "Y", "Y"],
    },
]


def esc(t):
    return sax.escape(t, {"'": "&apos;"})


def set_para_text(para_xml, text):
    """Replace the text of the first run in a paragraph, drop extra runs."""
    m = re.search(r"(<a:t>).*?(</a:t>)", para_xml, re.S)
    if not m:
        return para_xml
    head, tail = m.span(2)
    # Keep everything before the first <a:t>, swap content, keep the rest.
    pre = para_xml[: m.start(1)]
    post = para_xml[tail:]
    return pre + "<a:t>" + esc(text) + "</a:t>" + post


def clone_paragraphs(slide_xml, shape_idx):
    """Return (header, bullet, spacer) paragraph templates from a shape."""
    shapes = re.findall(r"<p:sp>.*?</p:sp>", slide_xml, re.S)
    body = re.search(r"<p:txBody>.*?</p:txBody>", shapes[shape_idx], re.S).group(0)
    paras = re.findall(r"<a:p>.*?</a:p>", body, re.S)
    header = paras[0]
    bullet = next((p for p in paras[1:] if re.search(r"<a:t>[^<]+</a:t>", p)), paras[1])
    # Spacer = the first paragraph with no text (template uses tiny empty rows).
    spacer = next((p for p in paras[1:] if not re.search(r"<a:t>[^<]*\S[^<]*</a:t>", p)), None)
    if spacer is None:
        spacer = re.sub(r"<a:t>.*?</a:t>", "<a:t></a:t>", bullet, count=1)
    return header, bullet, spacer


def build_txbody(slide_xml, shape_idx, sections):
    """Rebuild a text box's paragraphs: one header + bullets per section."""
    shapes = re.findall(r"<p:sp>.*?</p:sp>", slide_xml, re.S)
    sp = shapes[shape_idx]
    m = re.search(
        r"(<p:txBody>.*?</a:bodyPr>)(\s*<a:lstStyle>.*?</a:lstStyle>)?(.*?)(</p:txBody>)",
        sp, re.S)
    if not m:
        return slide_xml
    head_tpl, bullet_tpl, spacer_tpl = clone_paragraphs(slide_xml, shape_idx)
    parts = []
    for i, (header, bullets) in enumerate(sections):
        if i > 0:
            parts.append(spacer_tpl)
        parts.append(set_para_text(head_tpl, header))
        for b in bullets:
            parts.append(set_para_text(bullet_tpl, b))
    new_sp = sp[: m.start(3)] + "".join(parts) + sp[m.end(3):]
    shapes[shape_idx] = new_sp
    return _swap_shapes(slide_xml, shapes)


def set_dots(slide_xml, colors):
    shapes = re.findall(r"<p:sp>.*?</p:sp>", slide_xml, re.S)
    for (pos, slot) in DOT_SLOTS:
        for idx, s in enumerate(shapes):
            if re.search(r'<a:off x="%d" y="%d"/>' % pos, s):
                new_fill = '<a:solidFill><a:srgbClr val="%s"/></a:solidFill>' % COLORS[colors[slot]]
                shapes[idx] = re.sub(
                    r"<a:solidFill>\s*<a:srgbClr val=\"[0-9A-Fa-f]{6}\"/>\s*</a:solidFill>",
                    new_fill, s, count=1)
                break
    return _swap_shapes(slide_xml, shapes)


def _swap_shapes(slide_xml, shapes):
    # Replace the whole spTree children with the modified shape list.
    tree = re.search(r"<p:spTree>.*?</p:spTree>", slide_xml, re.S).group(0)
    new_tree = re.sub(r"<p:sp>.*?</p:sp>", lambda _: shapes.pop(0), tree, count=len(shapes))
    return slide_xml.replace(tree, new_tree)


def build_slide(orig_xml, data):
    xml = orig_xml
    # Title (shape 0)
    shapes = re.findall(r"<p:sp>.*?</p:sp>", xml, re.S)
    shapes[0] = set_para_text(shapes[0], data["title"])
    xml = _swap_shapes(xml, shapes)
    # Section text boxes: 1 = Overall Update, 2 = Activities, 19 = Recent/Planned/Issues
    xml = build_txbody(xml, 1, [("Overall Update:", data["overall"])])
    xml = build_txbody(xml, 2, [("Delivery Activities:", data["activities"])])
    xml = build_txbody(xml, 19, [
        ("Recent Accomplishments/Activities:", data["recent"]),
        ("Planned Activities:", data["planned"]),
        ("Issues:", data["issues"]),
    ])
    xml = set_dots(xml, data["dots"])
    return xml


def main():
    if os.path.exists(WORK):
        shutil.rmtree(WORK)
    os.makedirs(WORK)
    with zipfile.ZipFile(TPL) as z:
        z.extractall(WORK)

    slide1_path = os.path.join(WORK, "ppt/slides/slide1.xml")
    with open(slide1_path, encoding="utf-8") as f:
        orig = f.read()

    rels = open(os.path.join(WORK, "ppt/slides/_rels/slide1.xml.rels"), encoding="utf-8").read()

    n = len(SLIDES)
    for i, data in enumerate(SLIDES):
        num = i + 1
        slide_xml = build_slide(orig, data)
        with open(os.path.join(WORK, "ppt/slides/slide%d.xml" % num), "w", encoding="utf-8") as f:
            f.write(slide_xml)
        if num > 1:
            os.makedirs(os.path.join(WORK, "ppt/slides/_rels"), exist_ok=True)
            with open(os.path.join(WORK, "ppt/slides/_rels/slide%d.xml.rels" % num), "w", encoding="utf-8") as f:
                f.write(rels.replace("slide1.xml", "slide%d.xml" % num))

    # Register the new slides in presentation.xml
    pres = os.path.join(WORK, "ppt/presentation.xml")
    p = open(pres, encoding="utf-8").read()
    extra_ids = "".join(
        '<p:sldId id="%d" r:id="rId%d"/>' % (256 + i, 7 + i) for i in range(1, n)
    )
    p = p.replace("</p:sldIdLst>", extra_ids + "</p:sldIdLst>")
    open(pres, "w", encoding="utf-8").write(p)

    # Add relationships for the new slides
    prs_rels = os.path.join(WORK, "ppt/_rels/presentation.xml.rels")
    r = open(prs_rels, encoding="utf-8").read()
    extra_rels = "".join(
        '<Relationship Id="rId%d" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide%d.xml"/>'
        % (7 + i, i) for i in range(2, n + 1)
    )
    r = r.replace("</Relationships>", extra_rels + "</Relationships>")
    open(prs_rels, "w", encoding="utf-8").write(r)

    # Register the new slides in [Content_Types].xml
    ct = os.path.join(WORK, "[Content_Types].xml")
    c = open(ct, encoding="utf-8").read()
    extra_ct = "".join(
        '<Override PartName="/ppt/slides/slide%d.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>'
        % i for i in range(2, n + 1)
    )
    c = c.replace(
        '<Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>',
        '<Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>' + extra_ct,
    )
    open(ct, "w", encoding="utf-8").write(c)

    # Repack
    if os.path.exists(OUT):
        os.remove(OUT)
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(WORK):
            for fn in files:
                full = os.path.join(root, fn)
                z.write(full, os.path.relpath(full, WORK))

    print("Wrote", OUT, "with", n, "slides")


if __name__ == "__main__":
    main()