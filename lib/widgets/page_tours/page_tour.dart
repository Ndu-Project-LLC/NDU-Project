import 'package:flutter/material.dart';

/// Hand-written walkthrough copy for one page.
///
/// Keyed by the page id the header passes to the walkthrough (the breadcrumb
/// title, or the page title). The walkthrough engine still discovers the
/// section headings on screen; [sections] supplies the description for each
/// heading by its exact text.
class PageTour {
  const PageTour({
    required this.title,
    required this.intro,
    this.icon = Icons.explore_outlined,
    this.bullets = const [
      'Use Next and Back to move between sections',
      'Press Escape at any time to leave the tour',
    ],
    this.sections = const {},
    this.outro,
  });

  /// Name shown on the opening card.
  final String title;

  /// What this page is for and what the user does on it.
  final String intro;

  final IconData icon;

  /// Short navigation tips shown on the opening card.
  final List<String> bullets;

  /// Section heading text (exactly as it appears on screen) to description.
  final Map<String, String> sections;

  /// Closing card text. Falls back to the generic closer when null.
  final String? outro;
}
