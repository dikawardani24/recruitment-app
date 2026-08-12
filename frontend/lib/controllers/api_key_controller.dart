import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_controller.dart';

const _apiKeyPrefix = 'api_key_';

/// Manages API key storage per model provider via SharedPreferences.
/// Keys are stored as `api_key_<provider>` e.g. `api_key_openrouter`.
class ApiKeyController extends Notifier<String?> {
  @override
  String? build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs?.getString(_apiKeyKey('openrouter'));
  }

  static String _apiKeyKey(String provider) => '$_apiKeyPrefix$provider';

  /// Saves the [apiKey] for the given [provider] and updates state.
  Future<void> setApiKey(String provider, String apiKey) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.setString(_apiKeyKey(provider), apiKey);
    state = apiKey.isNotEmpty ? apiKey : null;
  }

  /// Clears the API key for the current provider and saves empty state.
  void clearApiKey() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.remove(_apiKeyKey('openrouter'));
    state = null;
  }
}

final apiKeyProvider =
    NotifierProvider<ApiKeyController, String?>(ApiKeyController.new);