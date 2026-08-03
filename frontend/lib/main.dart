import 'package:flutter/material.dart';

import 'app/di.dart';
import 'app/router.dart';
import 'app/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDi(Environment.dev);
  runApp(const AiAtsApp());
}

class AiAtsApp extends StatelessWidget {
  const AiAtsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AI ATS',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: appRouter,
    );
  }
}
