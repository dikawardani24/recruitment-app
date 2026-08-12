import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_controller.dart';

const _introSeenKey = 'intro_seen';

/// SharedPreferences key flagging that the first-run intro was completed.
const String introSeenPrefsKey = _introSeenKey;

/// Tracks whether the first-run intro has been seen so it only shows once.
/// The flag is persisted in [SharedPreferences] across restarts.
class IntroController extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs?.getBool(_introSeenKey) ?? false;
  }

  /// Marks the intro as seen and persists it so it never shows again.
  Future<void> complete() async {
    await ref.read(sharedPreferencesProvider)?.setBool(_introSeenKey, true);
    state = true;
  }
}

final introControllerProvider = NotifierProvider<IntroController, bool>(
  IntroController.new,
);
