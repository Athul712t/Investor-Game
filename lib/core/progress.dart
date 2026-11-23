/// Today's counters, used by daily quests. They reset when the day changes.
class DayStats {
  const DayStats({
    this.day = '',
    this.games = 0,
    this.lessons = 0,
    this.correct = 0,
    this.wrong = 0,
    this.bests = 0,
    this.reelCards = 0,
    this.reviews = 0,
    this.gameIds = const {},
  });

  final String day; // yyyy-mm-dd
  final int games; // game runs finished
  final int lessons; // lessons completed
  final int correct, wrong; // questions answered, anywhere in the app
  final int bests; // new personal bests set
  final int reelCards; // reel cards finished
  final int reviews; // review questions answered
  final Set<String> gameIds; // distinct games played

  DayStats copyWith({
    int? games,
    int? lessons,
    int? correct,
    int? wrong,
    int? bests,
    int? reelCards,
    int? reviews,
    Set<String>? gameIds,
  }) => DayStats(
    day: day,
    games: games ?? this.games,
    lessons: lessons ?? this.lessons,
    correct: correct ?? this.correct,
    wrong: wrong ?? this.wrong,
    bests: bests ?? this.bests,
    reelCards: reelCards ?? this.reelCards,
    reviews: reviews ?? this.reviews,
    gameIds: gameIds ?? this.gameIds,
  );

  Map<String, Object?> toJson() => {
    'day': day,
    'games': games,
    'lessons': lessons,
    'correct': correct,
    'wrong': wrong,
    'bests': bests,
    'reelCards': reelCards,
    'reviews': reviews,
    'gameIds': gameIds.toList(),
  };

  factory DayStats.fromJson(Map<String, Object?> j) => DayStats(
    day: (j['day'] ?? '') as String,
    games: (j['games'] ?? 0) as int,
    lessons: (j['lessons'] ?? 0) as int,
    correct: (j['correct'] ?? 0) as int,
    wrong: (j['wrong'] ?? 0) as int,
    bests: (j['bests'] ?? 0) as int,
    reelCards: (j['reelCards'] ?? 0) as int,
    reviews: (j['reviews'] ?? 0) as int,
    gameIds: {...?(j['gameIds'] as List?)?.cast<String>()},
  );

  /// The saved counters if they are from [today], otherwise fresh zeros for [today].
  static DayStats of(Map<String, Object?> raw, String today) {
    final s = DayStats.fromJson(raw);
    return s.day == today ? s : DayStats(day: today);
  }
}

/// Question ids are `<lessonId>-q<n>` (lesson questions) or `<lessonId>-x<n>` (reel extras).
/// Returns the lesson id, or '' when the id has another shape.
String lessonIdOfQuestion(String questionId) {
  final m = RegExp(r'^(.*)-[qx]\d+$').firstMatch(questionId);
  return m?.group(1) ?? '';
}
