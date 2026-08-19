import 'package:flutter/material.dart';

/// Content models for the Help & Guidance feature.
///
/// Content lives in `data/help_content.dart`; these classes describe its shape.
/// Keeping content separate from the widgets means the help text can change
/// without touching any UI code.

/// A content block rendered inside a [HelpSection].
sealed class HelpBlock {
  const HelpBlock();
}

/// A paragraph of text.
class HelpParagraph extends HelpBlock {
  final String text;

  const HelpParagraph(this.text);
}

/// A bulleted list of short items.
class HelpBulletList extends HelpBlock {
  final List<String> items;

  const HelpBulletList(this.items);
}

/// A numbered sequence of steps.
class HelpSteps extends HelpBlock {
  final List<String> steps;

  const HelpSteps(this.steps);
}

/// A highlighted note, rendered as a call-out box.
class HelpCallout extends HelpBlock {
  final String text;

  const HelpCallout(this.text);
}

/// A labeled example (e.g. `Job: Flutter Developer`), rendered as a fixed
/// layout block. Map order is preserved.
class HelpExample extends HelpBlock {
  final Map<String, String> rows;

  const HelpExample(this.rows);
}

/// One expandable question/answer pair.
class FaqEntry {
  final String question;
  final String answer;

  const FaqEntry({required this.question, required this.answer});
}

/// A group of [FaqEntry] items sharing a heading (e.g. "General", "Ranking").
class FaqGroup {
  final String title;
  final List<FaqEntry> items;

  const FaqGroup({required this.title, required this.items});
}

/// A titled run of [HelpBlock] content inside a [HelpCategory].
class HelpSection {
  final String title;
  final List<HelpBlock> body;

  const HelpSection({required this.title, required this.body});
}

/// A top-level Help & Guidance category shown as a card on the help home.
class HelpCategory {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<HelpSection> sections;
  final List<FaqGroup> faqGroups;

  const HelpCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.sections = const [],
    this.faqGroups = const [],
  });
}

/// A search hit for an FAQ entry: which category it belongs to and the entry.
class HelpSearchHit {
  final HelpCategory category;
  final FaqEntry entry;

  const HelpSearchHit({required this.category, required this.entry});
}

/// Result of searching the static help content.
class HelpSearchResults {
  final List<HelpCategory> categories;
  final List<HelpSearchHit> faqHits;

  const HelpSearchResults({
    this.categories = const [],
    this.faqHits = const [],
  });

  bool get isEmpty => categories.isEmpty && faqHits.isEmpty;
}