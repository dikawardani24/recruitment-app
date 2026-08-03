import 'package:flutter_test/flutter_test.dart';
import 'package:ai_ats/app/theme/app_theme.dart';

void main() {
  test('theme seeds a Material 3 color scheme', () {
    final theme = AppTheme.light();
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, isNotNull);
  });
}
