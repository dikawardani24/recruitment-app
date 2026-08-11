import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'di.dart';
import 'providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep the HTTP inspector available in release builds too.
  ChuckerFlutter.showOnRelease = true;
  setupDependencies();
  final prefs = await SharedPreferences.getInstance();
  final router = AppRouter.create();
  runApp(
    ProviderScope(
      overrides: [
        goRouterProvider.overrideWithValue(router),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: AtsApp(router: router),
    ),
  );
}

class AtsApp extends ConsumerWidget {
  final GoRouter router;

  const AtsApp({super.key, required this.router});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'AI ATS',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
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
