import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/question.dart';
import '../domain/game/game_types.dart';
import '../features/streak/streak_logic.dart';
import 'progress.dart';

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
    int reelMix = 2,
    this.dayStats = const {},
    this.quests = const {},
    this.chests = const [],
    this.streakFreezes = 0,
    this.lostStreak = 0,
    this.lostDay = '',
    this.milestonesDone = const {},
    this.review = const [],
    this.credits = const {},
    this.masteryClaimed = const {},
    this.headStarts = 0,
    this.owned = const {},
    this.townDecor = const {},
    this.pawn = '',
    this.notify = false,
    this.playHours = const [],
  }) : _reelMix = reelMix;

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
  final int _reelMix;

  // ---- v1.5 loop state ----
  final Map<String, Object?> dayStats; // DayStats.toJson(), today's counters
  final Map<String, Object?> quests; // {day, ids: [..], claimed: [..], chestGiven: bool}
  final List<String> chests; // unopened chests: 'wood' | 'silver' | 'gold'
  final int streakFreezes; // held freezes (max 1)
  final int lostStreak; // the streak that just broke, offered for repair
  final String lostDay; // day it broke (yyyy-mm-dd)
  final Set<int> milestonesDone; // streak milestones already rewarded (3, 7, 14, 30)
  final List<Map<String, Object?>> review; // [{id, due: yyyy-mm-dd, step: 0..2}] wrong answers to revisit
  final Map<String, int> credits; // lessonId -> mastery credits (correct answers and study boosts)
  final Set<String> masteryClaimed; // 'gameId:level' (level 1..3) rewards already paid
  final int headStarts; // owned head-start tokens
  final Set<String> owned; // shop items bought
  final Set<String> townDecor; // equipped town decorations (subset of owned)
  final String pawn; // equipped story pawn id ('' = default)
  final bool notify; // opted in to the daily reminder
  final List<int> playHours; // 24 counters, activity per hour of day (empty = none yet)

  /// Today's counters (zeros if the saved ones are from another day).
  DayStats statsFor(String today) => DayStats.of(dayStats, today);

  /// 24 hourly activity counters, never empty.
  List<int> get hours => playHours.length == 24 ? playHours : List.filled(24, 0);

  /// Reel mode stop, 0 (games only) to 4 (learning only). Clamped on read so a bad save cannot break the reel.
  int get reelMix => _reelMix.clamp(0, 4);

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
    int? reelMix,
    Map<String, Object?>? dayStats,
    Map<String, Object?>? quests,
    List<String>? chests,
    int? streakFreezes,
    int? lostStreak,
    String? lostDay,
    Set<int>? milestonesDone,
    List<Map<String, Object?>>? review,
    Map<String, int>? credits,
    Set<String>? masteryClaimed,
    int? headStarts,
    Set<String>? owned,
    Set<String>? townDecor,
    String? pawn,
    bool? notify,
    List<int>? playHours,
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
    reelMix: reelMix ?? this.reelMix,
    dayStats: dayStats ?? this.dayStats,
    quests: quests ?? this.quests,
    chests: chests ?? this.chests,
    streakFreezes: streakFreezes ?? this.streakFreezes,
    lostStreak: lostStreak ?? this.lostStreak,
    lostDay: lostDay ?? this.lostDay,
    milestonesDone: milestonesDone ?? this.milestonesDone,
    review: review ?? this.review,
    credits: credits ?? this.credits,
    masteryClaimed: masteryClaimed ?? this.masteryClaimed,
    headStarts: headStarts ?? this.headStarts,
    owned: owned ?? this.owned,
    townDecor: townDecor ?? this.townDecor,
    pawn: pawn ?? this.pawn,
    notify: notify ?? this.notify,
    playHours: playHours ?? this.playHours,
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
    'reelMix': reelMix,
    'dayStats': dayStats,
    'quests': quests,
    'chests': chests,
    'streakFreezes': streakFreezes,
    'lostStreak': lostStreak,
    'lostDay': lostDay,
    'milestonesDone': milestonesDone.toList(),
    'review': review,
    'credits': credits,
    'masteryClaimed': masteryClaimed.toList(),
    'headStarts': headStarts,
    'owned': owned.toList(),
    'townDecor': townDecor.toList(),
    'pawn': pawn,
    'notify': notify,
    'playHours': playHours,
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
    reelMix: (j['reelMix'] ?? 2) as int,
    dayStats: Map<String, Object?>.from((j['dayStats'] as Map?) ?? const {}),
    quests: Map<String, Object?>.from((j['quests'] as Map?) ?? const {}),
    chests: [...?(j['chests'] as List?)?.cast<String>()],
    streakFreezes: (j['streakFreezes'] ?? 0) as int,
    lostStreak: (j['lostStreak'] ?? 0) as int,
    lostDay: (j['lostDay'] ?? '') as String,
    milestonesDone: {...?(j['milestonesDone'] as List?)?.cast<int>()},
    review: [for (final r in (j['review'] as List?) ?? const []) Map<String, Object?>.from(r as Map)],
    credits: {...?(j['credits'] as Map?)?.cast<String, int>()},
    masteryClaimed: {...?(j['masteryClaimed'] as List?)?.cast<String>()},
    headStarts: (j['headStarts'] ?? 0) as int,
    owned: {...?(j['owned'] as List?)?.cast<String>()},
    townDecor: {...?(j['townDecor'] as List?)?.cast<String>()},
    pawn: (j['pawn'] ?? '') as String,
    notify: (j['notify'] ?? false) as bool,
    playHours: [...?(j['playHours'] as List?)?.cast<int>()],
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

  /// Call on any meaningful activity. Extends the daily streak; a held freeze forgives one missed day, a longer
  /// gap breaks it (a streak of 2+ is then offered for repair, see [repairStreak]).
  void touchStreak([DateTime? now]) {
    final key = dayKey(now ?? DateTime.now());
    final s = state;
    final first = s.lastActiveDay.isEmpty;
    final gap = first ? 0 : daysBetween(s.lastActiveDay, key);
    if (!first && gap <= 0) return; // same day, or the clock went back
    // An offer whose window has closed is cleared here.
    var p = repairOpen(s, key) ? s : s.copyWith(lostStreak: 0, lostDay: '');
    if (first) {
      p = p.copyWith(streak: 1);
    } else if (gap == 1 || (gap == 2 && s.streakFreezes > 0)) {
      p = p.copyWith(streak: s.streak + 1, streakFreezes: gap == 2 ? 0 : s.streakFreezes);
    } else if (s.streak >= 2) {
      p = p.copyWith(streak: 1, lostStreak: s.streak, lostDay: key);
    } else {
      p = p.copyWith(streak: 1);
    }
    _set(grantMilestone(p.copyWith(lastActiveDay: key)));
  }

  /// Restores the lost streak plus today while the repair window is open. Returns false when it is closed.
  bool repairStreak([DateTime? now]) {
    final key = dayKey(now ?? DateTime.now());
    final s = state;
    if (!repairOpen(s, key)) return false;
    final restored = s.lostStreak + 1;
    final p = s.copyWith(
      streak: restored > s.streak ? restored : s.streak,
      lastActiveDay: key,
      lostStreak: 0,
      lostDay: '',
    );
    _set(grantMilestone(p));
    return true;
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
    _note((s) => s.copyWith(lessons: s.lessons + 1));
    return first;
  }

  /// Stores rewards from a run. Returns true on a new high score.
  bool recordGame(GameResult r) {
    final best = state.highScores[r.gameId] ?? 0;
    final isBest = r.score > best;
    if (isBest) _set(state.copyWith(highScores: {...state.highScores, r.gameId: r.score}));
    reward(xp: r.xpEarned, coins: r.coinsEarned);
    _note((s) => s.copyWith(games: s.games + 1, bests: s.bests + (isBest ? 1 : 0), gameIds: {...s.gameIds, r.gameId}));
    return isBest;
  }

  /// Updates today's counters (they reset on a new day) and the hour-of-day activity histogram.
  void _note(DayStats Function(DayStats) f, [DateTime? now]) {
    final at = now ?? DateTime.now();
    final hours = [...state.hours];
    hours[at.hour]++;
    _set(state.copyWith(dayStats: f(DayStats.of(state.dayStats, dayKey(at))).toJson(), playHours: hours));
  }

  /// Call once per answered question, wherever it was answered (lesson, reel, daily, game chip, review).
  /// Counts it for daily quests, credits the question's lesson on a correct answer (mastery) and queues a
  /// wrong answer for spaced review (due tomorrow). Pass [fromReview] from the review session, which
  /// manages its own queue.
  void noteAnswer(Question q, bool correct, {bool fromReview = false, DateTime? now}) {
    final at = now ?? DateTime.now();
    final lesson = lessonIdOfQuestion(q.id);
    var credits = state.credits;
    if (correct && lesson.isNotEmpty) credits = {...credits, lesson: (credits[lesson] ?? 0) + 1};
    var review = state.review;
    if (!correct && !fromReview) {
      final due = dayKey(at.add(const Duration(days: 1)));
      review = [
        for (final r in review)
          if (r['id'] != q.id) r,
        {'id': q.id, 'due': due, 'step': 0},
      ];
    }
    _set(state.copyWith(credits: credits, review: review));
    _note(
      (s) => s.copyWith(
        correct: s.correct + (correct ? 1 : 0),
        wrong: s.wrong + (correct ? 0 : 1),
        reviews: s.reviews + (fromReview ? 1 : 0),
      ),
      at,
    );
  }

  /// A reel card was finished.
  void noteReelCard() => _note((s) => s.copyWith(reelCards: s.reelCards + 1));

  /// Adds an unopened chest ('wood', 'silver' or 'gold').
  void grantChest(String type) => _set(state.copyWith(chests: [...state.chests, type]));

  /// Applies [change] to the profile and saves. For features that own their own slice of the profile.
  void mutate(Profile Function(Profile) change) => _set(change(state));

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

  /// Saves the Reel mode stop (0 games only .. 4 learning only).
  void saveReelMix(int stop) => _set(state.copyWith(reelMix: stop.clamp(0, 4)));

  void markDailyDone() => _set(state.copyWith(dailyDoneDay: dayKey(DateTime.now())));
}
