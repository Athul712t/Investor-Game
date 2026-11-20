import 'dart:math';

import '../../domain/entities/content.dart';
import 'reel_extra.dart';
import 'reel_feed.dart';
import 'reel_item.dart';

/// Reel mode stops, 0 (games only) to 4 (learning only), as set in Profile.
abstract final class ReelMix {
  static const labels = ['Games only', 'Mostly games', 'Even mix', 'Mostly learning', 'Learning only'];
  static const captions = [
    'Games only. No lessons.',
    'Mostly games, with some learning.',
    'An even mix of games and learning.',
    'Mostly learning, with a few games.',
    'Learning only. No games.',
  ];

  /// The share of cards that are games at [stop].
  static double shareOf(int stop) => const [1.0, 0.75, 0.5, 0.25, 0.0][stop.clamp(0, 4)];
}

/// Decides the next reel card: a game or the next learning item, with guard rails.
class ReelSequencer implements ReelFeed {
  ReelSequencer({
    required List<Lesson> lessons,
    required ReelExtra extra,
    required List<String> gameIds,
    required Random rng,
    ReelCursor? cursor,
    double gameShare = 0.5,
  }) : _gameIds = gameIds,
       _rng = rng,
       _share = gameShare.clamp(0.0, 1.0),
       _maxGames = gameShare <= 0.5 ? 2 : 4,
       _maxLearn = gameShare >= 0.5 ? 2 : 4 {
    _gameChance = _chanceFor(_share, _maxGames, _maxLearn);
    for (final l in lessons) {
      final reads = [...l.cards, ...?extra.reads[l.id]];
      final qs = [...l.questions, ...?extra.questions[l.id]];
      _scripts.add([
        for (var i = 0; i < reads.length; i++) ReelRead(reads[i], l.id, i),
        for (final q in qs) ReelQuestion(q, l.id),
      ]);
      for (final q in qs) {
        _questions[q.id] = ReelQuestion(q, l.id, retry: true);
      }
    }
    _hasLearning = _scripts.any((s) => s.isNotEmpty);
    if (cursor != null && _scripts.isNotEmpty) {
      _lesson = cursor.lesson.clamp(0, _scripts.length - 1);
      _step = max(0, cursor.step);
      for (final id in cursor.retry) {
        if (_questions.containsKey(id) && !_retry.contains(id)) {
          _retry.add(id);
          _wait.add(_retryDelay);
        }
      }
    }
    _normalize();
  }

  static const _retryDelay = 3;

  /// The per-draw game chance whose long-run game fraction equals [share] once the run caps bite.
  /// Runs alternate, so the fraction is E[game run] / (E[game run] + E[learning run]); it rises with
  /// the chance, so bisect. Drawing at [share] itself would land about 6 points short at 0.25 and 0.75.
  static double _chanceFor(double share, int maxGames, int maxLearn) {
    double run(double p, int cap) => [for (var k = 0; k < cap; k++) pow(p, k).toDouble()].reduce((a, b) => a + b);
    var lo = 0.0, hi = 1.0;
    for (var i = 0; i < 40; i++) {
      final p = (lo + hi) / 2, g = run(p, maxGames);
      if (g / (g + run(1 - p, maxLearn)) < share) {
        lo = p;
      } else {
        hi = p;
      }
    }
    return (lo + hi) / 2;
  }

  final double _share;
  final int _maxGames, _maxLearn;
  late final double _gameChance;

  final List<String> _gameIds;
  final Random _rng;
  final _scripts = <List<ReelItem>>[];
  final _questions = <String, ReelQuestion>{}; // retry versions by question id
  late final bool _hasLearning;

  int _lesson = 0, _step = 0;
  final _retry = <String>[];
  final _wait = <int>[]; // learning items still to pass before each queued retry is due

  int _serial = 0, _gameRun = 0, _learnRun = 0;
  final _recentGames = <String>[];

  /// Points (_lesson, _step) at a real script item, skipping empty lessons and wrapping.
  void _normalize() {
    if (!_hasLearning) return;
    while (_step >= _scripts[_lesson].length) {
      _step = 0;
      _lesson = (_lesson + 1) % _scripts.length;
    }
  }

  @override
  ReelCursor get cursor => ReelCursor(lesson: _lesson, step: _step, retry: [..._retry]);

  @override
  void reportWrong(ReelQuestion q) {
    if (_questions.containsKey(q.question.id) && !_retry.contains(q.question.id)) {
      _retry.add(q.question.id);
      _wait.add(_retryDelay);
    }
  }

  @override
  ReelItem next() {
    final bool game;
    if (!_hasLearning || _share >= 1) {
      game = true; // with no learning content even "learning only" falls back to games: next() never fails
    } else if (_share <= 0) {
      game = false;
    } else if (_serial == 0) {
      game = true;
    } else if (_gameRun >= _maxGames) {
      game = false;
    } else if (_learnRun >= _maxLearn) {
      game = true;
    } else {
      game = _rng.nextDouble() < _gameChance;
    }
    return game ? _game() : _learning();
  }

  ReelItem _game() {
    _gameRun++;
    _learnRun = 0;
    if (_gameIds.isEmpty) return ReelGame('', _serial++);
    // With fewer than 3 games, only the last (n - 1) can be excluded.
    final pool = _gameIds.where((g) => !_recentGames.contains(g)).toList();
    final id = pool[_rng.nextInt(pool.length)];
    _recentGames.add(id);
    if (_recentGames.length > min(2, _gameIds.length - 1)) _recentGames.removeAt(0);
    return ReelGame(id, _serial++);
  }

  ReelItem _learning() {
    _learnRun++;
    _gameRun = 0;
    final due = _wait.indexWhere((w) => w <= 0);
    if (due >= 0) {
      final item = _questions[_retry[due]]!;
      _retry.removeAt(due);
      _wait.removeAt(due);
      return item;
    }
    final item = _scripts[_lesson][_step++];
    _normalize();
    for (var i = 0; i < _wait.length; i++) {
      _wait[i]--;
    }
    return item;
  }
}
