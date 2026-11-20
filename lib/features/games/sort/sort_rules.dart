import 'dart:math';

import '../_shared/quick_data.dart';

const sortRunSeconds = 30.0;
const sortWrongPenalty = 2.0;
const sortBoltEvery = 10;
const sortCommitFraction = 0.4;
const sortFlickSpeed = 900.0;

/// Points multiplier for a streak of correct sorts: x2 from 5, x3 from 10, x4 from 15.
int sortMultiplier(int streak) => 1 + min(3, streak ~/ 5);

/// -1 (left), 1 (right) or 0 (spring back) for a drag released [dx] px from the rest spot.
/// [span] is the distance from the rest spot to the bin. A drag past 40 percent commits;
/// so does a fast flick that has moved a little in the same direction.
int sortCommitSide(double dx, double vx, double span) {
  if (span <= 0) return 0;
  if (dx.abs() >= span * sortCommitFraction) return dx < 0 ? -1 : 1;
  if (vx.abs() >= sortFlickSpeed && dx.abs() >= span * 0.08 && dx.sign == vx.sign) return dx < 0 ? -1 : 1;
  return 0;
}

class SortOutcome {
  const SortOutcome({
    required this.correct,
    this.points = 0,
    this.comboStep = false,
    this.coin = false,
    this.boost = false,
    this.multiplier = 1,
  });
  final bool correct, comboStep, coin, boost;
  final int points, multiplier;
}

/// Pure state of one Sort Rush run.
class SortRules {
  SortRules(this.deck, this.rng) {
    _refill();
    _advance();
  }

  final SortDeck deck;
  final Random rng;

  double time = sortRunSeconds;
  double freeze = 0;
  int doubleLeft = 0;
  int score = 0, streak = 0, correctCount = 0, reshuffles = 0;
  late SortItem current;
  bool bolt = false;
  bool _boltNext = false;
  final _order = <SortItem>[];
  int _i = 0;

  bool get ended => time <= 0;
  int get multiplier => sortMultiplier(streak);

  void _refill() {
    final last = _order.isEmpty ? null : _order.last;
    _order
      ..clear()
      ..addAll(deck.items)
      ..shuffle(rng);
    if (_order.length > 1 && identical(_order.first, last)) {
      final j = 1 + rng.nextInt(_order.length - 1);
      final t = _order[0];
      _order[0] = _order[j];
      _order[j] = t;
    }
    _i = 0;
  }

  void _advance() {
    if (_i >= _order.length) {
      reshuffles++;
      _refill();
    }
    current = _order[_i++];
    bolt = _boltNext;
    _boltNext = false;
  }

  void tick(double dt) {
    if (freeze > 0) {
      freeze = max(0, freeze - dt);
    } else {
      time = max(0, time - dt);
    }
  }

  void addTime(double s) => time += s;

  SortOutcome sort(bool left) {
    final ok = left == current.left;
    final wasBolt = bolt;
    if (!ok) {
      streak = 0;
      time = max(0, time - sortWrongPenalty);
      _advance();
      return const SortOutcome(correct: false);
    }
    final mult = multiplier;
    final pts = mult * (doubleLeft > 0 ? 2 : 1);
    if (doubleLeft > 0) doubleLeft--;
    streak++;
    correctCount++;
    score += pts;
    if (correctCount % sortBoltEvery == 0) _boltNext = true;
    _advance();
    return SortOutcome(
      correct: true,
      points: pts,
      multiplier: mult,
      comboStep: streak % 5 == 0,
      coin: correctCount % 5 == 0,
      boost: wasBolt,
    );
  }
}
