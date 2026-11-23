import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/features/review/review_logic.dart';

Map<String, Object?> e(String id, String due, [int step = 0]) => {'id': id, 'due': due, 'step': step};

void main() {
  const today = '2026-11-23';

  test('due items are due <= today, oldest first, ties in queue order', () {
    final review = [e('c', '2026-11-23'), e('a', '2026-11-20'), e('future', '2026-11-24'), e('b', '2026-11-20')];
    final due = dueSession(review, {'a', 'b', 'c', 'future'}, today);
    expect([for (final r in due) r['id']], ['a', 'b', 'c']);
  });

  test('unknown question ids are dropped', () {
    final review = [e('gone', '2000-01-01'), e('a', '2000-01-01')];
    expect(dueSession(review, {'a'}, today).map((r) => r['id']), ['a']);
    expect(dueCount(review, {'a'}, today), 1);
  });

  test('a session takes at most 8', () {
    final review = [for (var i = 0; i < 12; i++) e('q$i', '2026-11-${10 + i}')];
    final due = dueSession(review, {for (final r in review) r['id']! as String}, today);
    expect(due.length, 8);
    expect(due.first['id'], 'q0');
  });

  test('schedule: 0 to 1 in 3 days, 1 to 2 in 7 days, 2 graduates', () {
    final one = advance(e('a', today), true, today)!;
    expect((one['step'], one['due']), (1, '2026-11-26'));
    final two = advance(one, true, today)!;
    expect((two['step'], two['due']), (2, '2026-11-30'));
    expect(advance(two, true, today), isNull);
  });

  test('a wrong answer resets to step 0 due tomorrow, across a month end', () {
    final r = advance(e('a', '2000-01-01', 2), false, '2026-11-30')!;
    expect((r['step'], r['due']), (0, '2026-12-01'));
    expect(addDays('2026-12-30', 3), '2027-01-02');
  });

  test('applyAnswer updates, resets or removes only that entry', () {
    final q = [e('a', today), e('b', today, 2)];
    expect(applyAnswer(q, 'a', true, today).map((r) => r['step']), [1, 2]);
    expect(applyAnswer(q, 'b', true, today).map((r) => r['id']), ['a']);
    expect(applyAnswer(q, 'b', false, today).last['step'], 0);
  });

  test('upcoming buckets and next due', () {
    final q = [e('a', '2026-11-24'), e('b', '2026-11-26'), e('c', '2026-11-30'), e('d', '2026-12-30'), e('e', today)];
    final ids = {'a', 'b', 'c', 'd', 'e'};
    final u = upcoming(q, ids, today);
    expect((u.tomorrow, u.in3, u.in7), (1, 1, 1));
    expect(nextDue(q, ids, today), '2026-11-24');
    expect(nextDue([e('e', today)], ids, today), isNull);
  });
}
