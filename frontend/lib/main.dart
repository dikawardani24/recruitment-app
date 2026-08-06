import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'providers.dart';
import 'router.dart';

void main() {
  final router = AppRouter.create();
  runApp(
    ProviderScope(
      overrides: [goRouterProvider.overrideWithValue(router)],
      child: AtsApp(router: router),
    ),
  );
}

class AtsApp extends StatelessWidget {
  final GoRouter router;

  const AtsApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AI ATS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5)),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
