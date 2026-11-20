import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/game/game_types.dart';

/// Everything the player owns. Stored locally as one JSON blob; cloud sync mirrors it.
class Profile {
  const Profile({
    this.name = 'Investor',
    this.xp = 0,
    this.coins = 0,
    this.streak = 0,
    this.lastActiveDay = '',
    this.completedLessons = const {},
    this.highScores = const {},
    this.powerups = const {},
    this.storyDone = const {},
    this.dailyDoneDay = '',
    this.reelCursor = const {},
    this.reelBestStreak = 0,
  });

  final String name;
  final int xp, coins, streak;
  final String lastActiveDay; // yyyy-mm-dd
  final Set<String> completedLessons;
  final Map<String, int> highScores; // gameId -> best score
  final Map<String, int> powerups; // PowerupType.name -> count
  final Set<String> storyDone; // completed story node ids ("chapterId/index")
  final String dailyDoneDay;
  final Map<String, Object?> reelCursor; // ReelCursor.toJson(), kept raw so core stays independent of features
  final int reelBestStreak;

  static const xpPerLevel = 100;
  int get level => xp ~/ xpPerLevel + 1;
  double get levelProgress => (xp % xpPerLevel) / xpPerLevel;
  String get title => switch (level) {
    < 3 => 'Saver',
    < 6 => 'SIPper',
    < 10 => 'Portfolio Pro',
    _ => 'Market Sage',
  };

  Profile copyWith({
    String? name,
    int? xp,
    int? coins,
    int? streak,
    String? lastActiveDay,
    Set<String>? completedLessons,
    Map<String, int>? highScores,
    Map<String, int>? powerups,
    Set<String>? storyDone,
    String? dailyDoneDay,
    Map<String, Object?>? reelCursor,
    int? reelBestStreak,
  }) => Profile(
    name: name ?? this.name,
    xp: xp ?? this.xp,
    coins: coins ?? this.coins,
    streak: streak ?? this.streak,
    lastActiveDay: lastActiveDay ?? this.lastActiveDay,
    completedLessons: completedLessons ?? this.completedLessons,
    highScores: highScores ?? this.highScores,
    powerups: powerups ?? this.powerups,
    storyDone: storyDone ?? this.storyDone,
    dailyDoneDay: dailyDoneDay ?? this.dailyDoneDay,
    reelCursor: reelCursor ?? this.reelCursor,
    reelBestStreak: reelBestStreak ?? this.reelBestStreak,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'xp': xp,
    'coins': coins,
    'streak': streak,
    'lastActiveDay': lastActiveDay,
    'completedLessons': completedLessons.toList(),
    'highScores': highScores,
    'powerups': powerups,
    'storyDone': storyDone.toList(),
    'dailyDoneDay': dailyDoneDay,
    'reelCursor': reelCursor,
    'reelBestStreak': reelBestStreak,
  };

  factory Profile.fromJson(Map<String, Object?> j) => Profile(
    name: (j['name'] ?? 'Investor') as String,
    xp: (j['xp'] ?? 0) as int,
    coins: (j['coins'] ?? 0) as int,
    streak: (j['streak'] ?? 0) as int,
    lastActiveDay: (j['lastActiveDay'] ?? '') as String,
    completedLessons: {...?(j['completedLessons'] as List?)?.cast<String>()},
    highScores: {...?(j['highScores'] as Map?)?.cast<String, int>()},
    powerups: {...?(j['powerups'] as Map?)?.cast<String, int>()},
    storyDone: {...?(j['storyDone'] as List?)?.cast<String>()},
    dailyDoneDay: (j['dailyDoneDay'] ?? '') as String,
    reelCursor: Map<String, Object?>.from((j['reelCursor'] as Map?) ?? const {}),
    reelBestStreak: (j['reelBestStreak'] ?? 0) as int,
  );
}

String dayKey(DateTime d) => d.toIso8601String().substring(0, 10);

/// Overridden in main() with the instance loaded before runApp.
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

final profileProvider = NotifierProvider<ProfileController, Profile>(ProfileController.new);

class ProfileController extends Notifier<Profile> {
  static const _key = 'profile_v1';

  @override
  Profile build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return const Profile();
    try {
      return Profile.fromJson(Map<String, Object?>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return const Profile(); // corrupt save: start fresh rather than crash
    }
  }

  void _set(Profile p) {
    state = p;
    ref.read(prefsProvider).setString(_key, jsonEncode(p.toJson()));
  }

  /// Replace local state with a cloud copy.
  void restore(Profile p) => _set(p);

  void rename(String name) => _set(state.copyWith(name: name.trim().isEmpty ? state.name : name.trim()));

  /// Call on any meaningful activity. Extends or resets the daily streak.
  void touchStreak([DateTime? now]) {
    final today = now ?? DateTime.now();
    final key = dayKey(today);
    if (state.lastActiveDay == key) return;
    final yesterday = dayKey(today.subtract(const Duration(days: 1)));
    _set(state.copyWith(streak: state.lastActiveDay == yesterday ? state.streak + 1 : 1, lastActiveDay: key));
  }

  void reward({int xp = 0, int coins = 0}) {
    touchStreak();
    _set(state.copyWith(xp: state.xp + xp, coins: state.coins + coins));
  }

  /// Returns true the first time a lesson is completed.
  bool completeLesson(String lessonId, {int xp = 20}) {
    final first = !state.completedLessons.contains(lessonId);
    _set(state.copyWith(completedLessons: {...state.completedLessons, lessonId}));
    reward(xp: first ? xp : xp ~/ 4);
    return first;
  }

  /// Stores rewards from a run. Returns true on a new high score.
  bool recordGame(GameResult r) {
    final best = state.highScores[r.gameId] ?? 0;
    final isBest = r.score > best;
    if (isBest) _set(state.copyWith(highScores: {...state.highScores, r.gameId: r.score}));
    reward(xp: r.xpEarned, coins: r.coinsEarned);
    return isBest;
  }

  void completeStoryNode(String nodeId) => _set(state.copyWith(storyDone: {...state.storyDone, nodeId}));

  bool spend(int coins) {
    if (state.coins < coins) return false;
    _set(state.copyWith(coins: state.coins - coins));
    return true;
  }

  void addPowerup(PowerupType t, [int n = 1]) =>
      _set(state.copyWith(powerups: {...state.powerups, t.name: (state.powerups[t.name] ?? 0) + n}));

  bool usePowerup(PowerupType t) {
    final have = state.powerups[t.name] ?? 0;
    if (have <= 0) return false;
    _set(state.copyWith(powerups: {...state.powerups, t.name: have - 1}));
    return true;
  }

  /// Saves where the reel's learning sequence resumes and the best streak.
  void saveReel({Map<String, Object?>? cursor, int? bestStreak}) =>
      _set(state.copyWith(reelCursor: cursor, reelBestStreak: bestStreak));

  void markDailyDone() => _set(state.copyWith(dailyDoneDay: dayKey(DateTime.now())));
}
