import 'package:flutter/material.dart';

import '../models/help_item.dart';

/// Static Help & Guidance content. This file is the single place to edit the
/// help text — the UI never contains guidance strings.
///
/// Strings are plain English, matching the rest of the app (the project does
/// not currently use Flutter's localization/gen-l10n; see the frontend
/// README). To localize later, this file becomes the translation source.
const helpCategories = <HelpCategory>[
  HelpCategory(
    id: 'getting-started',
    title: 'Getting Started',
    subtitle: 'Learn the basics of the app',
    icon: Icons.rocket_launch_outlined,
    sections: [
      HelpSection(
        title: 'The basic workflow',
        body: [
          HelpSteps([
            'Create a Job',
            'Add the Job Description',
            'Upload candidate CVs',
            'Wait for CV processing',
            'Review candidate ranking',
            'Inspect candidate details',
            'Ask the AI Chat questions about the recruitment results',
          ]),
        ],
      ),
      HelpSection(
        title: 'Tips',
        body: [
          HelpParagraph(
            'Start with a job. The more detail you put in the Job Description, '
            'the more meaningful the candidate comparison will be.',
          ),
        ],
      ),
    ],
  ),
  HelpCategory(
    id: 'jobs',
    title: 'Jobs & Job Descriptions',
    subtitle: 'Create and manage job roles',
    icon: Icons.work_outline,
    sections: [
      HelpSection(
        title: 'What is a Job?',
        body: [
          HelpParagraph(
            'A Job represents the position the recruiter is hiring for. It '
            'holds the Job Description, the candidates who applied, and the '
            'results of ranking them against the requirements.',
          ),
        ],
      ),
      HelpSection(
        title: 'What should I include in the Job Description?',
        body: [
          HelpBulletList([
            'Job title',
            'Responsibilities',
            'Required skills',
            'Required experience',
            'Education',
            'Preferred qualifications',
            'Technical requirements',
          ]),
          HelpParagraph(
            'A more detailed Job Description allows the system to perform a '
            'more meaningful comparison of candidates.',
          ),
        ],
      ),
    ],
  ),
  HelpCategory(
    id: 'cv-upload',
    title: 'CV Upload',
    subtitle: 'Upload and process candidates',
    icon: Icons.upload_file_outlined,
    sections: [
      HelpSection(
        title: 'How do I upload CVs?',
        body: [
          HelpParagraph(
            'Open the job and upload candidate CV documents. PDF, DOCX and TXT '
            'files are supported, and you can select several files at once.',
          ),
        ],
      ),
      HelpSection(
        title: 'What happens after upload?',
        body: [
          HelpSteps([
            'Document extraction',
            'Candidate information extraction',
            'Requirement matching',
            'Candidate ranking',
          ]),
          HelpParagraph(
            'Processing happens in the background. Processing time may '
            'increase when many CVs are uploaded.',
          ),
        ],
      ),
    ],
  ),
  HelpCategory(
    id: 'ranking',
    title: 'Candidate Ranking',
    subtitle: 'Understand scores and results',
    icon: Icons.leaderboard_outlined,
    sections: [
      HelpSection(
        title: 'How candidates are evaluated',
        body: [
          HelpParagraph(
            'Candidates are evaluated against the selected Job Description. '
            'The system considers how relevant their background is to the job, '
            'their skills, their experience, the job requirements, and their '
            'overall profile.',
          ),
        ],
      ),
      HelpSection(
        title: 'Ranking flow',
        body: [
          HelpSteps([
            'Job Description + Candidate CV',
            'Relevance Check',
            'Requirement Matching',
            'Candidate Score',
            'Ranking',
          ]),
        ],
      ),
      HelpSection(
        title: 'What the system considers',
        body: [
          HelpBulletList([
            'Job relevance',
            'Skills',
            'Experience',
            'Requirements',
            'Candidate background',
          ]),
          HelpParagraph(
            'The score is not an absolute measure of candidate quality. Use it '
            'together with the candidate\u2019s classification and profile when '
            'making a decision.',
          ),
        ],
      ),
      HelpSection(
        title: 'Candidate status',
        body: [
          HelpParagraph('Each candidate receives one of three classifications:'),
          HelpBulletList([
            'MET \u2014 the candidate sufficiently matches the Job Description '
                'and its important requirements.',
            'PARTIALLY_MET \u2014 the candidate is relevant to the Job but does '
                'not fully satisfy some requirements.',
            'NOT_MET \u2014 the candidate does not sufficiently meet the Job '
                'Description.',
          ]),
          HelpCallout(
            'A candidate can be marked NOT_MET when their professional '
            'background is fundamentally unrelated to the Job Description.',
          ),
          HelpExample({
            'Job:': 'Flutter Developer',
            'Candidate:': 'Accountant',
            'Result:': 'NOT_MET',
            'Score:': '0',
          }),
          HelpParagraph(
            'Unrelated candidates should not receive a normal ranking score.',
          ),
        ],
      ),
    ],
    faqGroups: [
      FaqGroup(
        title: 'Ranking',
        items: [
          FaqEntry(
            question: 'Why does an unrelated CV receive a score of 0?',
            answer: 'The system first checks whether the candidate\u2019s '
                'professional background is relevant to the Job Description. '
                'If the candidate is fundamentally unrelated to the position, '
                'they are classified as NOT_MET and receive a score of 0 '
                'instead of being compared using normal ranking criteria. This '
                'prevents unrelated candidates from receiving a high ranking '
                'simply because they have many years of experience or generic '
                'skills.',
          ),
          FaqEntry(
            question: 'Does a higher score always mean the candidate is better?',
            answer: 'The score represents how closely the candidate matches the '
                'selected Job Description. Use the score together with the '
                'candidate\u2019s classification, matched requirements, missing '
                'requirements, and overall profile when making a recruitment '
                'decision.',
          ),
          FaqEntry(
            question: 'Can an experienced candidate still be ranked low?',
            answer: 'Yes. A candidate with many years of experience can still '
                'be ranked low when their background is unrelated to the job. '
                'The relevance check runs first: unrelated candidates are '
                'marked NOT_MET with a score of 0 regardless of seniority.',
          ),
        ],
      ),
    ],
  ),
  HelpCategory(
    id: 'ai-chat',
    title: 'AI Chat',
    subtitle: 'Ask questions about candidates',
    icon: Icons.chat_outlined,
    sections: [
      HelpSection(
        title: 'What you can ask',
        body: [
          HelpParagraph('Recruiters can ask the AI about:'),
          HelpBulletList([
            'Job requirements',
            'Candidate profiles',
            'Candidate ranking',
            'Candidate strengths',
            'Missing skills',
            'Why a candidate ranks higher or lower',
            'Comparisons between candidates',
            'Recruitment insights',
          ]),
        ],
      ),
      HelpSection(
        title: 'Example questions',
        body: [
          HelpBulletList([
            'Why is John ranked first?',
            'What skills is Sarah missing?',
            'Why is this candidate marked NOT_MET?',
            'Compare the top three candidates.',
            'Which requirements are most difficult for candidates to satisfy?',
          ]),
        ],
      ),
    ],
    faqGroups: [
      FaqGroup(
        title: 'AI Chat',
        items: [
          FaqEntry(
            question: 'What can I ask the AI?',
            answer: 'You can ask about job requirements, candidate profiles, '
                'ranking results, candidate strengths, missing skills, why a '
                'candidate ranks higher or lower, comparisons between '
                'candidates, and general recruitment insights about your '
                'workspace.',
          ),
          FaqEntry(
            question: 'Can I ask the AI why a candidate received a certain '
                'ranking?',
            answer: 'Yes. The AI can explain a candidate\u2019s ranking, '
                'including which requirements and skills matched and which '
                'ones are missing.',
          ),
        ],
      ),
    ],
  ),
  HelpCategory(
    id: 'faq',
    title: 'FAQ',
    subtitle: 'Common questions and answers',
    icon: Icons.help_outline,
    faqGroups: [
      FaqGroup(
        title: 'General',
        items: [
          FaqEntry(
            question: 'What is this application for?',
            answer: 'It is an AI-powered applicant tracking system (ATS). You '
                'create job postings, upload candidate CVs, and the app '
                'extracts their skills and experience, ranks them against the '
                'job requirements, and gives you a match score, strengths, '
                'weaknesses and a hiring recommendation.',
          ),
          FaqEntry(
            question: 'Who should use this application?',
            answer: 'Recruiters, hiring managers and HR teams who want to '
                'collect candidate CVs, rank them against job descriptions, '
                'and understand the results.',
          ),
          FaqEntry(
            question: 'How does the recruitment workflow work?',
            answer: 'Create a job, add its Job Description, upload candidate '
                'CVs, wait for processing, then review the ranking and inspect '
                'candidate details.',
          ),
        ],
      ),
      FaqGroup(
        title: 'Jobs',
        items: [
          FaqEntry(
            question: 'What makes a good Job Description?',
            answer: 'A clear job title, responsibilities, required skills, '
                'required experience, education and preferred qualifications. '
                'More detail lets the system compare candidates more '
                'meaningfully.',
          ),
          FaqEntry(
            question: 'Can I update a Job Description?',
            answer: 'Yes. You can edit the job and its description at any '
                'time, then rank the candidates against the updated '
                'requirements.',
          ),
        ],
      ),
      FaqGroup(
        title: 'CVs',
        items: [
          FaqEntry(
            question: 'What CV format can I upload?',
            answer: 'PDF, DOCX and TXT files are supported.',
          ),
          FaqEntry(
            question: 'Can I upload multiple CVs?',
            answer: 'Yes. You can select and upload several files at once to '
                'the same job.',
          ),
          FaqEntry(
            question: 'What happens after I upload a CV?',
            answer: 'The document is extracted, candidate information is '
                'pulled out, the CV is matched against the job requirements, '
                'and it is included in the ranking.',
          ),
        ],
      ),
      FaqGroup(
        title: 'Ranking',
        items: [
          FaqEntry(
            question: 'How is the candidate ranking calculated?',
            answer: 'Candidates are scored on how well they match the Job '
                'Description: job relevance, skills, experience, requirements '
                'and overall background. Unrelated candidates are classified '
                'NOT_MET with a score of 0.',
          ),
          FaqEntry(
            question: 'What does MET mean?',
            answer: 'MET means the candidate sufficiently matches the Job '
                'Description and its important requirements.',
          ),
          FaqEntry(
            question: 'What does PARTIALLY_MET mean?',
            answer: 'PARTIALLY_MET means the candidate is relevant to the Job '
                'but does not fully satisfy some requirements.',
          ),
          FaqEntry(
            question: 'What does NOT_MET mean?',
            answer: 'NOT_MET means the candidate does not sufficiently meet '
                'the Job Description.',
          ),
          FaqEntry(
            question: 'Why is an unrelated CV given a score of 0?',
            answer: 'The relevance check runs first. A candidate whose '
                'professional background is fundamentally unrelated to the Job '
                'Description is classified NOT_MET and receives a score of 0 '
                'instead of being compared using normal ranking criteria.',
          ),
          FaqEntry(
            question: 'Can an experienced candidate still be ranked low?',
            answer: 'Yes. Relevance is checked before scoring, so a senior '
                'candidate in an unrelated field is marked NOT_MET with a '
                'score of 0.',
          ),
        ],
      ),
      FaqGroup(
        title: 'AI Chat',
        items: [
          FaqEntry(
            question: 'What can I ask the AI?',
            answer: 'Questions about your workspace: job requirements, '
                'candidate profiles, ranking results, strengths, missing '
                'skills, comparisons between candidates and recruitment '
                'insights.',
          ),
          FaqEntry(
            question: 'Can I ask the AI why a candidate received a certain '
                'ranking?',
            answer: 'Yes. The AI can explain a candidate\u2019s ranking and '
                'the requirements and skills behind it.',
          ),
        ],
      ),
    ],
  ),
];

/// Search the static help content by title/description/body text. Returns
/// matched categories (tappable) and matched FAQ entries (expandable).
HelpSearchResults searchHelp(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const HelpSearchResults();

  final categories = <HelpCategory>[];
  final faqHits = <HelpSearchHit>[];
  for (final category in helpCategories) {
    if (_categoryText(category).toLowerCase().contains(q)) {
      categories.add(category);
    }
    for (final group in category.faqGroups) {
      for (final entry in group.items) {
        if (entry.question.toLowerCase().contains(q) ||
            entry.answer.toLowerCase().contains(q)) {
          faqHits.add(HelpSearchHit(category: category, entry: entry));
        }
      }
    }
  }
  return HelpSearchResults(categories: categories, faqHits: faqHits);
}

String _categoryText(HelpCategory category) {
  final buffer = StringBuffer(category.title)
    ..write(' ')
    ..write(category.subtitle);
  for (final section in category.sections) {
    buffer
      ..write(' ')
      ..write(section.title);
    for (final block in section.body) {
      switch (block) {
        case HelpParagraph(:final text):
          buffer..write(' ')..write(text);
        case HelpBulletList(:final items):
          buffer..write(' ')..write(items.join(' '));
        case HelpSteps(:final steps):
          buffer..write(' ')..write(steps.join(' '));
        case HelpCallout(:final text):
          buffer..write(' ')..write(text);
        case HelpExample(:final rows):
          buffer..write(' ')..write(rows.values.join(' '));
      }
    }
  }
  return buffer.toString();
}