import 'package:flutter/material.dart';

import 'package:ndu_project/widgets/page_tours/page_tour.dart';

/// Bespoke walkthrough copy for closeout, risk tracking and related pages.
final Map<String, PageTour> closeoutPageTours = {
  'Benefits Realization': const PageTour(
    title: 'Benefits Realization',
    icon: Icons.trending_up_outlined,
    intro:
        'Track whether the benefits the project promised are actually being '
        'achieved, measure by measure, and who is accountable for each.',
    outro:
        'Benefits are realised after go-live. Keep this page open well beyond '
        'closeout.',
  ),
  'Finalize Project': const PageTour(
    title: 'Finalize Project',
    icon: Icons.task_alt_outlined,
    intro:
        'Work through the final steps to close the project: confirm deliverables, '
        'sign-offs and open items before the project is formally finished.',
    outro:
        'Do not finalise with open items unless each one has an owner and a '
        'follow-up date.',
  ),
  'Financial Closeout': const PageTour(
    title: 'Financial Closeout',
    icon: Icons.account_balance_wallet_outlined,
    intro:
        'Reconcile the project finances: final costs against budget, outstanding '
        'invoices and the variance explanations.',
    sections: {
      'Finalize all financial activities':
          'The goal of this page in one line: finish every financial activity '
          'and reconcile project costs with accounting before closeout.',
      'Financial Closeout Snapshot':
          'A live read-out of the project finances as you close: budget used, '
          'spend pace and the split by solution. The numbers come straight '
          'from Cost Analysis and the Cost Estimate — nothing to re-enter.',
      'Financial Summary':
          'Finalise the financial summary: approved budget, actual cost, '
          'variance, forecast accuracy, final cost performance, CPI and the '
          'cost breakdown by solution and category.',
      'Accounting Reconciliation':
          'Reconcile the books: invoice status, purchase orders, '
          'capitalisation, expense reconciliation, GL coding, accounting '
          'approval and the audit package. Every line should tie back to a '
          'source document.',
      'Financial Analysis':
          'The final analysis: earned value summary, ROI, cash flow summary, '
          'budget utilisation and the financial lessons learned to carry into '
          'the next project.',
      'Notes':
          'Anything the numbers cannot say: context for variances, agreements '
          'with finance, or reminders for the audit. Notes save '
          'automatically.',
    },
    outro:
        'Every variance should have a recorded reason. Close the books only when '
        'the totals reconcile.',
  ),
  'Hypercare & Warranty Support': const PageTour(
    title: 'Hypercare & Warranty Support',
    icon: Icons.support_agent_outlined,
    intro:
        'Plan the support period after go-live: the hypercare team, the escalation '
        'route and the warranty terms that apply.',
    outro:
        'Hypercare ends on a date. Agree what moves to business-as-usual support '
        'when it does.',
  ),
  'Launch Readiness Assessment': const PageTour(
    title: 'Launch Readiness Assessment',
    icon: Icons.checklist_rtl_outlined,
    intro:
        'Assess whether the project is ready to launch: the criteria, the status '
        'of each and the go or no-go decision it supports.',
    outro:
        'Any criterion not met needs an explicit decision to accept the risk.',
  ),
  'Project Activities Log': const PageTour(
    title: 'Project Activities Log',
    icon: Icons.history_outlined,
    intro:
        'See the record of activity across the project: what changed, when and by '
        'whom.',
    outro:
        'The log is the audit trail. Use it to answer “what happened” questions.',
  ),
  'Project Closeout': const PageTour(
    title: 'Project Closeout',
    icon: Icons.flag_circle_outlined,
    intro:
        'Close the project out formally: confirm the deliverables are accepted, '
        'record the lessons and release the resources.',
    outro:
        'Closeout is complete when the sponsor has accepted the project in writing.',
  ),
  'Risk Tracking': const PageTour(
    title: 'Risk Tracking',
    icon: Icons.track_changes_outlined,
    intro:
        'Track each risk over time: its current rating, the actions taken and '
        'whether the trend is improving.',
    outro:
        'Review high-rated risks first. A risk that never changes may need a '
        'different response.',
  ),
  'Risk Tracking Workspace': const PageTour(
    title: 'Risk Tracking Workspace',
    icon: Icons.dashboard_customize_outlined,
    intro:
        'Work through the risks in one place: update ratings, add actions and '
        'record decisions as they are made.',
    outro:
        'Keep the workspace current so the risk register reflects the real position.',
  ),
  'SSHER Hub': const PageTour(
    title: 'SSHER Hub',
    icon: Icons.health_and_safety_outlined,
    intro:
        'Manage safety, security, health, environment and risk topics from one '
        'hub. Open each area to review its status and actions.',
    outro:
        'Safety items take priority. Escalate any open issue that could cause harm.',
  ),
  'Salvage and Disposal Team': const PageTour(
    title: 'Salvage and Disposal Team',
    icon: Icons.recycling_outlined,
    intro:
        'Plan the team that will salvage, sell or dispose of project assets at the '
        'end of the work, with the roles and responsibilities for each.',
    outro:
        'Confirm disposal routes and approvals before the assets are released.',
  ),
  'Vendor & Contract Closeout': const PageTour(
    title: 'Vendor & Contract Closeout',
    icon: Icons.handshake_outlined,
    intro:
        'Close out each vendor contract: confirm delivery, settle final payments '
        'and record any claims still open.',
    outro:
        'Do not release a contract until deliverables, payments and claims are '
        'all resolved.',
  ),
  'Vendor Account Close Out': const PageTour(
    title: 'Vendor Account Close Out',
    icon: Icons.account_box_outlined,
    intro:
        'Close the account with each vendor: final invoices, outstanding balances '
        'and the records to keep.',
    outro:
        'Keep the final statements on file. They are what an audit will ask for.',
  ),
};
