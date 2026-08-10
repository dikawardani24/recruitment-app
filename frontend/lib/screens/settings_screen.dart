import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../theme/theme_controller.dart';
import '../widgets/deferred_page.dart';
import '../widgets/gradient_header.dart';
import '../widgets/section_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DeferredPage(child: _SettingsContent());
  }
}

class _SettingsContent extends ConsumerWidget {
  const _SettingsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final themeController = ref.read(themeModeProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const GradientHeader(
            icon: Icons.settings,
            title: 'Settings',
            subtitle: 'Customize how the app looks and behaves.',
          ),
          const SizedBox(height: 16),
          const SectionTitle('Appearance'),
          const SizedBox(height: 8),
          SectionCard(
            title: 'Theme',
            crossAxisAlignment: CrossAxisAlignment.stretch,
            clipBehavior: Clip.antiAlias,
            child: RadioGroup<ThemeMode>(
              groupValue: themeMode,
              onChanged: (mode) {
                if (mode != null) themeController.setMode(mode);
              },
              child: const Column(
                children: [
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    title: Text('System'),
                    subtitle: Text('Follow your device setting'),
                    secondary: Icon(Icons.brightness_auto),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    title: Text('Light'),
                    subtitle: Text('Always use the light theme'),
                    secondary: Icon(Icons.light_mode_outlined),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    title: Text('Dark'),
                    subtitle: Text('Always use the dark theme'),
                    secondary: Icon(Icons.dark_mode_outlined),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
