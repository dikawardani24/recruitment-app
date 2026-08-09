import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's [SharedPreferences] instance, used to persist user preferences
/// like the selected theme. Null until `main()` overrides it; widget tests
/// override it with `SharedPreferences.setMockInitialValues`.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

const _themeModeKey = 'theme_mode';

/// Holds the user's [ThemeMode] choice and persists it across restarts.
/// Defaults to [ThemeMode.system] until the user picks something else.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final saved = ref
        .watch(sharedPreferencesProvider)
        ?.getString(_themeModeKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  /// Applies [mode] immediately and saves it for the next launch.
  void setMode(ThemeMode mode) {
    state = mode;
    ref.read(sharedPreferencesProvider)?.setString(_themeModeKey, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
