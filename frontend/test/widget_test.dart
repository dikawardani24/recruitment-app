import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:ai_ats/main.dart';
import 'package:ai_ats/router.dart';
import 'package:ai_ats/screens/job_list_screen.dart';

void main() {
  testWidgets('App builds and shows the jobs list screen', (tester) async {
    final router = AppRouter.create();
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [goRouterProvider.overrideWithValue(router)],
          child: AtsApp(router: router),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.byType(JobListScreen), findsOneWidget);
    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('New job'), findsOneWidget);
  });
}
