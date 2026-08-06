import 'package:flutter_test/flutter_test.dart';

import 'package:ai_ats/screens/job_list_screen.dart';

void main() {
  test('formatCreatedAt renders dd MMM yyyy h:mm am/pm', () {
    final formatted = formatCreatedAt('2026-08-06T14:05:00');
    expect(formatted, '06 Aug 2026 2:05 pm');
  });

  test('formatCreatedAt uses am for morning times', () {
    final formatted = formatCreatedAt('2026-01-01T09:30:00');
    expect(formatted, '01 Jan 2026 9:30 am');
  });

  test('formatCreatedAt handles noon and midnight', () {
    expect(formatCreatedAt('2026-03-15T12:00:00'), contains('12:00 pm'));
    expect(formatCreatedAt('2026-03-15T00:00:00'), contains('12:00 am'));
  });

  test('formatCreatedAt returns empty for missing input', () {
    expect(formatCreatedAt(null), '');
    expect(formatCreatedAt('not-a-date'), '');
  });
}
