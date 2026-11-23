import '../../core/progress.dart';

enum QuestTier { easy, medium, hard }

/// Picks the pictogram painted on a quest row.
enum QuestKind { controller, cards, check, lesson, star }

class Quest {
  const Quest(this.id, this.tier, this.kind, this.text, this.target, this._count);
  final String id;
  final QuestTier tier;
  final QuestKind kind;
  final String text;
  final int target;
  final int Function(DayStats) _count;

  int get coins => switch (tier) {
    QuestTier.easy => 15,
    QuestTier.medium => 25,
    QuestTier.hard => 40,
  };

  int get xp => switch (tier) {
    QuestTier.easy => 10,
    QuestTier.medium => 15,
    QuestTier.hard => 25,
  };

  /// Progress from today's counters, capped at the target for display.
  int progress(DayStats s) => _count(s).clamp(0, target);

  bool isComplete(DayStats s) => _count(s) >= target;
}

final List<Quest> questPool = [
  Quest('e-games2', QuestTier.easy, QuestKind.controller, 'Play 2 games', 2, (s) => s.games),
  Quest('e-reel5', QuestTier.easy, QuestKind.cards, 'Finish 5 reel cards', 5, (s) => s.reelCards),
  Quest('e-correct3', QuestTier.easy, QuestKind.check, 'Answer 3 questions correctly', 3, (s) => s.correct),
  Quest('m-diff3', QuestTier.medium, QuestKind.controller, 'Play 3 different games', 3, (s) => s.gameIds.length),
  Quest('m-lesson1', QuestTier.medium, QuestKind.lesson, 'Finish a lesson', 1, (s) => s.lessons),
  Quest('m-correct8', QuestTier.medium, QuestKind.check, 'Answer 8 questions correctly', 8, (s) => s.correct),
  Quest('h-best1', QuestTier.hard, QuestKind.star, 'Beat a personal best', 1, (s) => s.bests),
  Quest('h-reel12', QuestTier.hard, QuestKind.cards, 'Finish 12 reel cards', 12, (s) => s.reelCards),
  Quest('h-games5', QuestTier.hard, QuestKind.controller, 'Play 5 games', 5, (s) => s.games),
];

Quest? questById(String id) {
  for (final q in questPool) {
    if (q.id == id) return q;
  }
  return null;
}

/// Stable across runs and platforms (String.hashCode is not).
int _hash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return h;
}

/// The three quests of [day] (yyyy-mm-dd): one per tier, the same for everyone all day.
List<Quest> questsForDay(String day) {
  Quest pick(QuestTier t) {
    final tier = questPool.where((q) => q.tier == t).toList();
    return tier[_hash('$day/${t.name}') % tier.length];
  }

  return [for (final t in QuestTier.values) pick(t)];
}

Map<String, Object?> freshQuests(String day) => {
  'day': day,
  'ids': [for (final q in questsForDay(day)) q.id],
  'claimed': <String>[],
  'chestGiven': false,
};

/// [raw] as it should read on [day]: unchanged when it is today's and well formed, otherwise a fresh set.
Map<String, Object?> rolledQuests(Map<String, Object?> raw, String day) {
  final ids = raw['ids'];
  if (raw['day'] != day || ids is! List || ids.length != 3 || ids.any((i) => questById('$i') == null)) {
    return freshQuests(day);
  }
  return raw;
}

List<String> claimedOf(Map<String, Object?> state) => [...?(state['claimed'] as List?)?.cast<String>()];

/// The outcome of a claim: the new state, the quest paid, and whether the silver chest is now due.
typedef Claim = ({Map<String, Object?> state, Quest quest, bool chest});

/// Claims quest [id] on [day] if it is today's, complete and not yet claimed; otherwise null.
/// Pays exactly once: the id goes into `claimed`, and the chest only when all three are in and not yet given.
Claim? claimQuest(Map<String, Object?> raw, String id, DayStats stats, String day) {
  final state = rolledQuests(raw, day);
  final quest = questById(id);
  final claimed = claimedOf(state);
  if (quest == null || !(state['ids'] as List).contains(id) || claimed.contains(id) || !quest.isComplete(stats)) {
    return null;
  }
  claimed.add(id);
  final chest = claimed.length == 3 && state['chestGiven'] != true;
  final next = {...state, 'claimed': claimed, 'chestGiven': state['chestGiven'] == true || chest};
  return (state: next, quest: quest, chest: chest);
}

/// "5h", or "42m" in the last hour, until the next local midnight.
String resetsIn(DateTime now) {
  final left = DateTime(now.year, now.month, now.day + 1).difference(now);
  return left.inHours >= 1 ? '${left.inHours}h' : '${(left.inSeconds / 60).ceil().clamp(1, 59)}m';
}
