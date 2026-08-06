import 'package:flutter/foundation.dart';
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
      builder: (context, child) {
        if (_isDesktop && MediaQuery.sizeOf(context).width < kMinAppWidth) {
          return const _NarrowWindowMessage();
        }
        return child!;
      },
      routerConfig: router,
    );
  }
}

bool get _isDesktop {
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
      return true;
    default:
      return false;
  }
}

const double kMinAppWidth = 320;

class _NarrowWindowMessage extends StatelessWidget {
  const _NarrowWindowMessage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.settings_overscan,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Window too small',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please resize the window wider to continue using the app.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
