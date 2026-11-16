enum PowerupType { shield, doubleScore, slowMo, extraLife, magnet }

extension PowerupInfo on PowerupType {
  String get label => switch (this) {
    PowerupType.shield => 'Shield',
    PowerupType.doubleScore => '2x Score',
    PowerupType.slowMo => 'Slow-mo',
    PowerupType.extraLife => 'Extra life',
    PowerupType.magnet => 'Coin magnet',
  };
  String get emoji => switch (this) {
    PowerupType.shield => '🛡️',
    PowerupType.doubleScore => '✖️',
    PowerupType.slowMo => '🐢',
    PowerupType.extraLife => '❤️',
    PowerupType.magnet => '🧲',
  };
}

class GameConfig {
  const GameConfig({this.difficulty = 1, this.seed});
  final int difficulty; // 1..5
  final int? seed; // same seed gives the same run (daily challenge)
}

class GameResult {
  const GameResult({
    required this.gameId,
    required this.score,
    required this.durationMs,
    this.coinsEarned = 0,
    this.xpEarned = 0,
    this.questionsAnswered = 0,
    this.questionsCorrect = 0,
  });

  final String gameId;
  final int score;
  final int durationMs;
  final int coinsEarned;
  final int xpEarned;
  final int questionsAnswered;
  final int questionsCorrect;
}
