/// Engine-agnostic contract every mini-game implements (Flame, Unity, ...).
enum PowerupType { shield, doubleScore, slowMo, extraLife, magnet, streakSaver }

class GameConfig {
  const GameConfig({
    required this.gameId,
    this.difficulty = 1,
    this.loadout = const [],
    this.seed,
    this.storyContext,
  });

  final String gameId;
  final int difficulty;
  final List<PowerupType> loadout;
  final int? seed; // same seed => same run (daily tournaments)
  final Map<String, Object?>? storyContext; // set when launched from Story Mode
}

class GameResult {
  const GameResult({
    required this.gameId,
    required this.score,
    required this.durationMs,
    this.coinsEarned = 0,
    this.xpEarned = 0,
    this.powerupsUsed = const [],
    this.questionsAnswered = 0,
    this.questionsCorrect = 0,
    this.completed = false,
  });

  final String gameId;
  final int score;
  final int durationMs;
  final int coinsEarned;
  final int xpEarned;
  final List<PowerupType> powerupsUsed;
  final int questionsAnswered;
  final int questionsCorrect;
  final bool completed;

  Map<String, Object?> toJson() => {
    'gameId': gameId,
    'score': score,
    'durationMs': durationMs,
    'coinsEarned': coinsEarned,
    'xpEarned': xpEarned,
    'powerupsUsed': powerupsUsed.map((p) => p.name).toList(),
    'questionsAnswered': questionsAnswered,
    'questionsCorrect': questionsCorrect,
    'completed': completed,
  };
}

/// Implemented by each game. The host pauses the game and shows the
/// question overlay in Flutter when [onBoostRequested] fires.
abstract class MiniGame {
  String get id;

  Future<void> init(GameConfig config);
  void start();
  void pause();
  void resume();
  void applyPowerup(PowerupType type);

  /// Game asks the host for a question-for-a-boost moment.
  void Function()? onBoostRequested;

  /// Game finished (win, lose or quit).
  void Function(GameResult result)? onFinished;

  void dispose();
}
