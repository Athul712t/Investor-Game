import 'dart:math';

const candleRounds = 5;
const candleMinWait = 1.2;
const candleMaxWait = 3.5;
const candleFirstDecoyRound = 3;
const candleDecoyLen = 0.12;

/// Points for a reaction time in ms: 250 ms is 800, 500 ms is 300, clamped to 0..1000.
int pointsFor(int ms) => (1000 - (ms - 150) * 2).clamp(0, 1000);

/// A false start (null reaction) scores nothing.
int roundScore(int? ms) => ms == null ? 0 : pointsFor(ms);

int coinsFor(int? ms) => ms == null ? 0 : (ms < 220 ? 2 : (ms < 300 ? 1 : 0));

double nextWait(Random rng) => candleMinWait + rng.nextDouble() * (candleMaxWait - candleMinWait);

/// Start time (s after the wait began) of a decoy, or null. Rounds are 1-based; decoys from round 3.
/// The decoy always ends well before [wait] so it can not be confused with the go moment.
double? planDecoy(Random rng, int round, double wait) {
  if (round < candleFirstDecoyRound) return null;
  const earliest = 0.45;
  final latest = wait - candleDecoyLen - 0.35;
  return latest <= earliest ? earliest : earliest + rng.nextDouble() * (latest - earliest);
}

bool runEnds(int roundsPlayed) => roundsPlayed >= candleRounds;

/// Mean of the valid reactions, null when every round was a false start.
double? averageMs(List<int?> rounds) {
  final v = rounds.whereType<int>().toList();
  return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
}

int? bestMs(List<int?> rounds) {
  final v = rounds.whereType<int>();
  return v.isEmpty ? null : v.reduce(min);
}
