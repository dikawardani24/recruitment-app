import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_ats/di.dart';
import 'package:ai_ats/help/data/help_content.dart';
import 'package:ai_ats/help/ui/help_page.dart';
import 'package:ai_ats/main.dart';
import 'package:ai_ats/providers.dart';
import 'package:ai_ats/router.dart';
import 'package:ai_ats/theme/theme_controller.dart';

class _FakeJobListNotifier extends JobListNotifier {
  @override
  Future<JobListState> build() async {
    return JobListState(jobs: const [], page: 1, hasMore: false);
  }
}

void main() {
  setupDependencies();

  Future<SharedPreferences> mockPrefs(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    late SharedPreferences prefs;
    await tester.runAsync(() async {
      prefs = await SharedPreferences.getInstance();
    });
    return prefs;
  }

  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    SharedPreferences? prefs,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final effective = prefs ?? await mockPrefs(tester);
    final router = AppRouter.create();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          sharedPreferencesProvider.overrideWithValue(effective),
          jobsProvider.overrideWith(() => _FakeJobListNotifier()),
          ...overrides,
        ],
        child: AtsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> openHelp(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Help & Guidance'));
    await tester.pumpAndSettle();
  }

  testWidgets('settings shows a Help & Guidance entry that opens the help page', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Help & Guidance'), findsOneWidget);

    await tester.tap(find.text('Help & Guidance'));
    await tester.pumpAndSettle();

    expect(find.byType(HelpPage), findsOneWidget);
  });

  testWidgets('help home lists every guidance category', (tester) async {
    await pumpApp(tester);
    await openHelp(tester);

    expect(find.byType(HelpPage), findsOneWidget);
    for (final category in helpCategories) {
      expect(find.text(category.title), findsOneWidget);
    }
  });

  testWidgets('tapping a category expands its guidance content in place', (
    tester,
  ) async {
    await pumpApp(tester);
    await openHelp(tester);

    // Content is hidden until the category is expanded.
    expect(find.text('Candidate status'), findsNothing);

    await tester.tap(find.text('Candidate Ranking'));
    await tester.pumpAndSettle();

    expect(find.text('Candidate status'), findsOneWidget);
    expect(
      find.textContaining('MET \u2014 the candidate sufficiently matches'),
      findsOneWidget,
    );
    expect(find.byType(HelpPage), findsOneWidget);
  });

  testWidgets('FAQ items expand to reveal the answer', (tester) async {
    await pumpApp(tester);
    await openHelp(tester);

    await tester.tap(find.text('Candidate Ranking'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Why does an unrelated CV receive a score of 0?'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(HelpPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Why does an unrelated CV receive a score of 0?'));
    await tester.pumpAndSettle();

    expect(find.textContaining('normal ranking criteria'), findsOneWidget);
  });

  testWidgets('search filters categories and FAQ entries', (tester) async {
    await pumpApp(tester);
    await openHelp(tester);

    await tester.enterText(find.byType(TextField), 'NOT_MET');
    await tester.pumpAndSettle();

    expect(find.text('Search results'), findsOneWidget);
    expect(find.text('Candidate Ranking'), findsWidgets);
    expect(find.text('What does NOT_MET mean?'), findsOneWidget);

    await tester.tap(find.text('What does NOT_MET mean?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not sufficiently meet'), findsOneWidget);
  });

  testWidgets('search with no matches shows an empty state', (tester) async {
    await pumpApp(tester);
    await openHelp(tester);

    await tester.enterText(find.byType(TextField), 'zzz-no-match-zzz');
    await tester.pumpAndSettle();

    expect(find.textContaining('No results for'), findsOneWidget);
  });
}