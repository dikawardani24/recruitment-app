import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_controller.dart';

const _apiKeyPrefix = 'api_key_';

/// Supported chat providers. The `default` provider is the backend's primary
/// endpoint (e.g. Gemini); `openrouter` is the model router.
enum ApiKeyProvider {
  gemini('default', 'Gemini (Default)', 'AIza…'),
  openrouter('openrouter', 'OpenRouter', 'sk-or-…');

  const ApiKeyProvider(this.id, this.label, this.hint);

  /// Provider id used by the backend model list and stored pref keys.
  final String id;
  final String label;
  final String hint;

  static ApiKeyProvider fromId(String? id) => ApiKeyProvider.values.firstWhere(
        (p) => p.id == id,
        orElse: () => ApiKeyProvider.gemini,
      );
}

/// Manages API key storage per chat provider via SharedPreferences.
/// Keys are stored as `api_key_<provider>` e.g. `api_key_openrouter`.
class ApiKeyController extends Notifier<Map<String, String?>> {
  @override
  Map<String, String?> build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return {
      for (final provider in ApiKeyProvider.values)
        provider.id: _normalizeKey(prefs?.getString(_apiKeyKey(provider.id))),
    };
  }

  static String _apiKeyKey(String provider) => '$_apiKeyPrefix$provider';

  /// Normalize API key: treat empty strings as null.
  static String? _normalizeKey(String? key) => key?.isNotEmpty == true ? key : null;

  /// The key saved for [provider], or null when none is set.
  String? keyFor(ApiKeyProvider provider) => state[provider.id];

  /// Saves the [apiKey] for the given [provider] and updates state.
  Future<void> setApiKey(ApiKeyProvider provider, String apiKey) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (apiKey.isNotEmpty) {
      await prefs?.setString(_apiKeyKey(provider.id), apiKey);
      state = {...state, provider.id: apiKey};
    } else {
      await prefs?.remove(_apiKeyKey(provider.id));
      state = {...state, provider.id: null};
    }
  }

  /// Clears the API key for [provider] and saves empty state.
  Future<void> clearApiKey(ApiKeyProvider provider) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.remove(_apiKeyKey(provider.id));
    state = {...state, provider.id: null};
  }
}

final apiKeyProvider =
    NotifierProvider<ApiKeyController, Map<String, String?>>(ApiKeyController.new);

/// The saved API key for [provider], or null when not set.
final apiKeyForProvider =
    Provider.family<String?, ApiKeyProvider>((ref, provider) {
  return ref.watch(apiKeyProvider)[provider.id];
});
