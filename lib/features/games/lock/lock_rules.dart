import 'dart:math';

/// Pure rules of Pop the Lock. Angles are in degrees, direction is +1 or -1.

const lockRunSeconds = 45.0;
const lockStartLives = 3;
const lockMaxLives = 5;
const minDotGap = 70.0; // the dot always spawns at least this far ahead of the pin
const maxDotGap = 300.0;
const perfectDeg = 4.0;
const boostEvery = 8;
const baseSpeed = 120.0; // deg/s
const maxSpeed = 250.0;
const slowPops = 3;

double wrap360(double a) => (a % 360 + 360) % 360;

/// Degrees from [from] to [to] travelling in [dir], in [0, 360).
double aheadOf(double from, double to, int dir) => wrap360((to - from) * dir);

/// Smallest absolute angle between two angles, in [0, 180].
double angleGap(double a, double b) {
  final d = wrap360(a - b);
  return d > 180 ? 360 - d : d;
}

bool dotHit(double pin, double dot, double halfWidth) => angleGap(pin, dot) <= halfWidth;

bool isPerfect(double pin, double dot) => angleGap(pin, dot) <= perfectDeg;

/// The pin has moved more than [halfWidth] beyond the dot: the dot is "ahead" by a near-full turn, which a fresh
/// dot never is (it spawns at most [maxDotGap] ahead).
bool dotPassed(double pin, double dot, int dir, double halfWidth) {
  final a = aheadOf(pin, dot, dir);
  return a > maxDotGap && a < 360 - halfWidth;
}

/// Random dot angle between [minDotGap] and [maxDotGap] ahead of the pin.
double pickDotAngle(Random rng, double pin, int dir) =>
    wrap360(pin + dir * (minDotGap + rng.nextDouble() * (maxDotGap - minDotGap)));

/// Half width of the dot in degrees: generous at first, shrinks slowly.
double dotHalfWidth(int pops) => max(11.0, 24.0 - pops * 0.45);

/// Pin speed in deg/s: slow for the first pops, then rising up to a cap.
double pinSpeed(int pops) => pops < slowPops ? baseSpeed : min(maxSpeed, baseSpeed + 10 + (pops - slowPops) * 4.5);

/// Score multiplier for a pop made after [combo] consecutive pops.
int comboMult(int combo) => min(5, 1 + combo ~/ 3);

int popPoints({required bool perfect, required int combo, bool doubled = false}) =>
    (perfect ? 2 : 1) * comboMult(combo) * (doubled ? 2 : 1);

/// Every [boostEvery]-th pop spawns a bolt dot.
bool nextIsBolt(int pops) => (pops + 1) % boostEvery == 0;

bool runEnded({required double timeLeft, required int lives}) => timeLeft <= 0 || lives <= 0;
