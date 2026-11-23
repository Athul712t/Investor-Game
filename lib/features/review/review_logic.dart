import '../../core/profile.dart' show dayKey;

/// Spaced review rules as pure functions over `profile.review` entries
/// (`{id, due: 'yyyy-mm-dd', step: 0|1|2}`).
const reviewSessionSize = 8;
const reviewSeconds = 120;

/// Days until the next review after a correct answer at step 0 and step 1.
const _gaps = [3, 7];

/// `yyyy-mm-dd` of [day] plus [days], computed on the calendar date so DST never shifts it.
String addDays(String day, int days) {
  final d = DateTime.parse(day);
  return dayKey(DateTime.utc(d.year, d.month, d.day + days));
}

int daysBetween(String from, String to) => DateTime.parse(to).difference(DateTime.parse(from)).inDays;

/// Entries whose question still exists, in queue order.
List<Map<String, Object?>> known(List<Map<String, Object?>> review, Set<String> ids) => [
  for (final r in review)
    if (ids.contains(r['id'])) r,
];

/// Up to [limit] entries due on or before [today], oldest due first (ties keep queue order).
List<Map<String, Object?>> dueSession(
  List<Map<String, Object?>> review,
  Set<String> ids,
  String today, {
  int limit = reviewSessionSize,
}) {
  final due = [
    for (final r in known(review, ids))
      if ((r['due']! as String).compareTo(today) <= 0) r,
  ];
  // List.sort is not stable, so ties are broken by the original position.
  final order = {for (var i = 0; i < due.length; i++) due[i]: i};
  due.sort((a, b) {
    final c = (a['due']! as String).compareTo(b['due']! as String);
    return c != 0 ? c : order[a]!.compareTo(order[b]!);
  });
  return due.take(limit).toList();
}

int dueCount(List<Map<String, Object?>> review, Set<String> ids, String today) =>
    known(review, ids).where((r) => (r['due']! as String).compareTo(today) <= 0).length;

/// What is coming after today: due tomorrow, in 2 to 3 days, in 4 to 7 days.
({int tomorrow, int in3, int in7}) upcoming(List<Map<String, Object?>> review, Set<String> ids, String today) {
  var a = 0, b = 0, c = 0;
  for (final r in known(review, ids)) {
    final n = daysBetween(today, r['due']! as String);
    if (n == 1) {
      a++;
    } else if (n >= 2 && n <= 3) {
      b++;
    } else if (n >= 4 && n <= 7) {
      c++;
    }
  }
  return (tomorrow: a, in3: b, in7: c);
}

/// The entry after an answer: null when graduated (correct at step 2).
Map<String, Object?>? advance(Map<String, Object?> entry, bool correct, String today) {
  final step = (entry['step'] ?? 0) as int;
  if (!correct) return {'id': entry['id'], 'due': addDays(today, 1), 'step': 0};
  if (step >= 2) return null;
  return {'id': entry['id'], 'due': addDays(today, _gaps[step]), 'step': step + 1};
}

/// The queue after answering question [id]: its entry advanced, reset or removed.
List<Map<String, Object?>> applyAnswer(List<Map<String, Object?>> review, String id, bool correct, String today) => [
  for (final r in review)
    if (r['id'] != id) r else ?advance(r, correct, today),
];

/// The earliest due date after today among known entries, or null.
String? nextDue(List<Map<String, Object?>> review, Set<String> ids, String today) {
  final later = [
    for (final r in known(review, ids))
      if ((r['due']! as String).compareTo(today) > 0) r['due']! as String,
  ]..sort();
  return later.firstOrNull;
}
