from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import landscape, letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


OUTPUT_PATH = Path(
    "/Volumes/External Drive/Source Code/Ndu_Project/docs/"
    "proposed_internal_rbac_account_portfolios.pdf"
)


def build_styles():
    styles = getSampleStyleSheet()
    styles.add(
        ParagraphStyle(
            name="BodySmall",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=9,
            leading=12,
            textColor=colors.HexColor("#1F2937"),
            alignment=TA_LEFT,
        )
    )
    styles.add(
        ParagraphStyle(
            name="SectionTitle",
            parent=styles["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=15,
            leading=18,
            spaceAfter=8,
            textColor=colors.HexColor("#0F172A"),
        )
    )
    styles.add(
        ParagraphStyle(
            name="DocumentTitle",
            parent=styles["Title"],
            fontName="Helvetica-Bold",
            fontSize=22,
            leading=26,
            textColor=colors.HexColor("#0B1220"),
        )
    )
    styles.add(
        ParagraphStyle(
            name="Callout",
            parent=styles["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=10,
            leading=13,
            textColor=colors.HexColor("#7C2D12"),
            backColor=colors.HexColor("#FFF7ED"),
            borderPadding=8,
            borderColor=colors.HexColor("#FDBA74"),
            borderWidth=0.75,
            borderRadius=4,
        )
    )
    return styles


def p(text, style):
    return Paragraph(text, style)


def add_bullets(story, items, styles):
    for item in items:
        story.append(p(f"• {item}", styles["BodySmall"]))
        story.append(Spacer(1, 0.06 * inch))


def role_table(styles):
    rows = [
        [
            p("<b>Internal Account Portfolio</b>", styles["BodySmall"]),
            p("<b>Primary Purpose</b>", styles["BodySmall"]),
            p("<b>Typical Holders</b>", styles["BodySmall"]),
            p("<b>Scope</b>", styles["BodySmall"]),
            p("<b>Default Risk Level</b>", styles["BodySmall"]),
        ],
        [
            p("<b>1. Platform Super Admin</b>", styles["BodySmall"]),
            p(
                "Own platform-wide identity, emergency administration, and final approval for sensitive changes.",
                styles["BodySmall"],
            ),
            p("Founder, CTO, designated platform owner", styles["BodySmall"]),
            p("Global", styles["BodySmall"]),
            p("Critical", styles["BodySmall"]),
        ],
        [
            p("<b>2. Platform Operations Admin</b>", styles["BodySmall"]),
            p(
                "Run day-to-day tenant operations across users, projects, programs, and portfolios without owning revenue policy.",
                styles["BodySmall"],
            ),
            p("Operations lead, trusted internal admin", styles["BodySmall"]),
            p("Global", styles["BodySmall"]),
            p("High", styles["BodySmall"]),
        ],
        [
            p("<b>3. Revenue & Billing Admin</b>", styles["BodySmall"]),
            p(
                "Manage subscriptions, invoices, coupon policy, manual remediation, and revenue support workflows.",
                styles["BodySmall"],
            ),
            p("Finance ops, billing specialist", styles["BodySmall"]),
            p("Global for commercial records", styles["BodySmall"]),
            p("High", styles["BodySmall"]),
        ],
        [
            p("<b>4. Customer Success / Support Admin</b>", styles["BodySmall"]),
            p(
                "Investigate customer issues, review account state, and help recover access without broad write control.",
                styles["BodySmall"],
            ),
            p("Support lead, customer success", styles["BodySmall"]),
            p("Read global, write limited support actions", styles["BodySmall"]),
            p("Medium", styles["BodySmall"]),
        ],
        [
            p("<b>5. Content & Configuration Admin</b>", styles["BodySmall"]),
            p(
                "Manage editable app content, labels, guidance, and approved platform configuration that is non-financial.",
                styles["BodySmall"],
            ),
            p("Content manager, product ops", styles["BodySmall"]),
            p("Global for approved content domains", styles["BodySmall"]),
            p("Medium", styles["BodySmall"]),
        ],
        [
            p("<b>6. Audit & Compliance Reviewer</b>", styles["BodySmall"]),
            p(
                "Inspect user, billing, and governance state for review, reporting, and incident reconstruction without mutation.",
                styles["BodySmall"],
            ),
            p("Auditor, security reviewer, external assessor", styles["BodySmall"]),
            p("Global read-only", styles["BodySmall"]),
            p("Low", styles["BodySmall"]),
        ],
    ]

    table = Table(
        rows,
        colWidths=[1.85 * inch, 3.3 * inch, 1.6 * inch, 1.65 * inch, 1.0 * inch],
        repeatRows=1,
    )
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#0F172A")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("ALIGN", (3, 1), (4, -1), "CENTER"),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#CBD5E1")),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F8FAFC")]),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, -1), 6),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
            ]
        )
    )
    return table


def permissions_table(styles):
    rows = [
        [
            p("<b>Permission Family</b>", styles["BodySmall"]),
            p("<b>Super Admin</b>", styles["BodySmall"]),
            p("<b>Platform Ops</b>", styles["BodySmall"]),
            p("<b>Revenue & Billing</b>", styles["BodySmall"]),
            p("<b>Customer Support</b>", styles["BodySmall"]),
            p("<b>Content & Config</b>", styles["BodySmall"]),
            p("<b>Audit Reviewer</b>", styles["BodySmall"]),
        ],
        [p("Roles and role assignment", styles["BodySmall"]), "Full", "None", "None", "None", "None", "View"],
        [p("User activation / deactivation", styles["BodySmall"]), "Full", "Full", "None", "Limited", "None", "View"],
        [p("Admin console user management", styles["BodySmall"]), "Full", "Full", "View", "View", "View", "View"],
        [p("Project / program / portfolio oversight", styles["BodySmall"]), "Full", "Full", "View", "View", "None", "View"],
        [p("Subscription lookup", styles["BodySmall"]), "Full", "View", "Full", "View", "None", "View"],
        [p("Billing remediation / cancellation / override", styles["BodySmall"]), "Full", "None", "Full", "None", "None", "View"],
        [p("Coupon management", styles["BodySmall"]), "Full", "None", "Full", "None", "None", "View"],
        [p("Editable app content", styles["BodySmall"]), "Full", "View", "None", "None", "Full", "View"],
        [p("System-wide exports / audit reports", styles["BodySmall"]), "Full", "View", "View", "View", "View", "Full"],
        [p("Emergency break-glass actions", styles["BodySmall"]), "Full", "None", "None", "None", "None", "None"],
    ]

    table = Table(
        rows,
        colWidths=[2.55 * inch, 0.85 * inch, 0.85 * inch, 1.0 * inch, 0.95 * inch, 0.95 * inch, 0.95 * inch],
        repeatRows=1,
    )
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1D4ED8")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("ALIGN", (1, 1), (-1, -1), "CENTER"),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#CBD5E1")),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#EFF6FF")]),
                ("LEFTPADDING", (0, 0), (-1, -1), 5),
                ("RIGHTPADDING", (0, 0), (-1, -1), 5),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    return table


def scope_table(styles):
    rows = [
        [
            p("<b>Concept</b>", styles["BodySmall"]),
            p("<b>Meaning</b>", styles["BodySmall"]),
            p("<b>Recommendation</b>", styles["BodySmall"]),
        ],
        [
            p("Commercial tier", styles["BodySmall"]),
            p("Customer subscription level already present in the codebase", styles["BodySmall"]),
            p("Keep `project`, `program`, and `portfolio` as commercial access tiers only.", styles["BodySmall"]),
        ],
        [
            p("Internal role portfolio", styles["BodySmall"]),
            p("Bundle of admin permissions for staff users", styles["BodySmall"]),
            p("Store as named roles such as `platform_super_admin` and `revenue_billing_admin`.", styles["BodySmall"]),
        ],
        [
            p("Operational scope", styles["BodySmall"]),
            p("Where a role is valid", styles["BodySmall"]),
            p("Support `global`, `project`, `program`, and `portfolio` scopes so future delegated admins can be constrained.", styles["BodySmall"]),
        ],
        [
            p("Permission atom", styles["BodySmall"]),
            p("Single grantable capability", styles["BodySmall"]),
            p("Use granular keys such as `users.write`, `subscriptions.read`, `coupons.manage`, `content.publish`.", styles["BodySmall"]),
        ],
    ]

    table = Table(rows, colWidths=[1.5 * inch, 2.7 * inch, 4.8 * inch], repeatRows=1)
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#111827")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#D1D5DB")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F9FAFB")]),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, -1), 6),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
            ]
        )
    )
    return table


def build_pdf():
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    styles = build_styles()

    doc = SimpleDocTemplate(
        str(OUTPUT_PATH),
        pagesize=landscape(letter),
        leftMargin=0.55 * inch,
        rightMargin=0.55 * inch,
        topMargin=0.5 * inch,
        bottomMargin=0.45 * inch,
        title="Proposed Internal RBAC for Account Portfolios",
        author="Codex",
        subject="Internal RBAC proposal grounded in the NDU Project codebase",
    )

    story = []
    story.append(p("Proposed Internal RBAC for Account Portfolios", styles["DocumentTitle"]))
    story.append(Spacer(1, 0.08 * inch))
    story.append(
        p(
            "Prepared for NDU Project on 8 April 2026. This proposal separates commercial subscription tiers from internal staff permissions and replaces the current broad admin flag with role-based control.",
            styles["BodySmall"],
        )
    )
    story.append(Spacer(1, 0.12 * inch))
    story.append(
        p(
            "Observed current state in the codebase: customer subscriptions already use <b>project</b>, <b>program</b>, and <b>portfolio</b> tiers; internal access is still mostly controlled by a single <b>users.isAdmin</b> boolean used by Firestore rules and the admin dashboard.",
            styles["Callout"],
        )
    )
    story.append(Spacer(1, 0.18 * inch))

    story.append(p("1. Design Position", styles["SectionTitle"]))
    add_bullets(
        story,
        [
            "Treat customer tier and internal role as different concerns. A staff user may support many customer tiers without inheriting full platform admin rights.",
            "Use least privilege by default. Most internal users should not receive role-assignment, coupon management, or break-glass access.",
            "Protect the current admin surfaces independently: user management, project oversight, subscription lookup, coupon management, and editable content.",
            "Make every high-risk action auditable and assignable to a named portfolio instead of a generic admin flag.",
        ],
        styles,
    )

    story.append(Spacer(1, 0.08 * inch))
    story.append(p("2. Proposed Internal Account Portfolios", styles["SectionTitle"]))
    story.append(role_table(styles))
    story.append(Spacer(1, 0.18 * inch))

    story.append(p("3. Recommended Permission Matrix", styles["SectionTitle"]))
    story.append(permissions_table(styles))

    story.append(PageBreak())
    story.append(p("4. Scope Model", styles["SectionTitle"]))
    story.append(scope_table(styles))
    story.append(Spacer(1, 0.18 * inch))

    story.append(p("5. Recommended Implementation Shape", styles["SectionTitle"]))
    add_bullets(
        story,
        [
            "Replace `users.isAdmin` with `roleIds: []`, `permissionOverrides`, and `accessScopes` on the user record.",
            "Refactor Firestore helper rules from `isAdmin()` to permission checks such as `hasPermission('users.write')` and `hasScope('global')`.",
            "Map existing admin screens to explicit permissions: `users.read`, `users.write`, `projects.read_all`, `subscriptions.read`, `subscriptions.manage`, `coupons.manage`, `content.manage`.",
            "Keep `platform_super_admin` rare and require dual control for creating or assigning that role.",
            "Introduce immutable audit logging for role assignment, coupon changes, subscription overrides, and user deactivation.",
        ],
        styles,
    )

    story.append(Spacer(1, 0.08 * inch))
    story.append(p("6. Migration Path", styles["SectionTitle"]))
    add_bullets(
        story,
        [
            "Phase 1: Preserve current behavior by mapping every existing `isAdmin == true` user to `platform_super_admin` temporarily.",
            "Phase 2: Split existing admins into the narrower portfolios above based on actual job function.",
            "Phase 3: Update admin UI visibility so users only see modules their role portfolio allows.",
            "Phase 4: Tighten Firestore rules after the UI and services stop depending on the legacy boolean.",
        ],
        styles,
    )

    story.append(Spacer(1, 0.08 * inch))
    story.append(p("7. Final Recommendation", styles["SectionTitle"]))
    story.append(
        p(
            "Internally, NDU Project should operate with six account portfolios: <b>Platform Super Admin</b>, <b>Platform Operations Admin</b>, <b>Revenue & Billing Admin</b>, <b>Customer Success / Support Admin</b>, <b>Content & Configuration Admin</b>, and <b>Audit & Compliance Reviewer</b>. Customer-facing <b>project</b>, <b>program</b>, and <b>portfolio</b> remain commercial account tiers and should not be used as internal security roles.",
            styles["BodySmall"],
        )
    )

    doc.build(story)
    return OUTPUT_PATH


if __name__ == "__main__":
    path = build_pdf()
    print(path)
