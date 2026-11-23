import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/core/notifications.dart';

void main() {
  group('usualHour', () {
    test('picks the busiest hour', () {
      final h = List.filled(24, 0);
      h[8] = 3;
      h[21] = 7;
      expect(usualHour(h), 21);
    });
    test('ties go to the later hour', () {
      final h = List.filled(24, 0);
      h[7] = 2;
      h[20] = 2;
      expect(usualHour(h), 20);
    });
    test('empty and all zeros default to 19', () {
      expect(usualHour(const []), 19);
      expect(usualHour(List.filled(24, 0)), 19);
    });
  });

  group('nextReminder', () {
    final now = DateTime(2026, 3, 10, 12, 0);
    test('inactive today and hour ahead gives today', () {
      expect(nextReminder(now, 19, '2026-03-09'), DateTime(2026, 3, 10, 19));
      expect(nextReminder(now, 19, ''), DateTime(2026, 3, 10, 19));
    });
    test('active today gives tomorrow', () => expect(nextReminder(now, 19, '2026-03-10'), DateTime(2026, 3, 11, 19)));
    test(
      'hour already past gives tomorrow',
      () => expect(nextReminder(now, 9, '2026-03-09'), DateTime(2026, 3, 11, 9)),
    );
    test('within 10 minutes gives tomorrow', () {
      expect(nextReminder(now, 12, ''), DateTime(2026, 3, 11, 12));
      expect(nextReminder(DateTime(2026, 3, 10, 11, 55), 12, ''), DateTime(2026, 3, 11, 12));
      expect(nextReminder(DateTime(2026, 3, 10, 11, 49), 12, ''), DateTime(2026, 3, 10, 12));
    });
    test(
      'crosses month end',
      () => expect(nextReminder(DateTime(2026, 1, 31, 23, 55), 0, ''), DateTime(2026, 2, 2, 0)),
    );
  });

  test('copy', () {
    expect(reminderBody(5), 'A minute of play keeps your 5 day streak going.');
    expect(reminderBody(0), 'Start a streak today. A minute is enough.');
    expect([hourLabel(0), hourLabel(12), hourLabel(19)], ['12 am', '12 pm', '7 pm']);
  });
}
