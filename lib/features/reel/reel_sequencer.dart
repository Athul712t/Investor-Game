import 'dart:math';

import '../../domain/entities/content.dart';
import 'reel_extra.dart';
import 'reel_feed.dart';
import 'reel_item.dart';

/// Decides the next reel card: a game or the next learning item, with guard rails.
class ReelSequencer implements ReelFeed {
  ReelSequencer({
    required List<Lesson> lessons,
    required ReelExtra extra,
    required List<String> gameIds,
    required Random rng,
    ReelCursor? cursor,
  }) : _gameIds = gameIds,
       _rng = rng {
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
  static const _gameChance = 0.45;

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
    if (!_hasLearning || _serial == 0) {
      game = true;
    } else if (_gameRun >= 2) {
      game = false;
    } else if (_learnRun >= 2) {
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
