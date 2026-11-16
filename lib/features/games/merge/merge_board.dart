import 'dart:math';

enum MergeDir { up, down, left, right }

class Slide {
  const Slide(this.from, this.to, this.value);
  final int from, to, value;
}

class MoveResult {
  const MoveResult({this.slides = const [], this.merges = const {}, this.spawnCell = -1, this.spawnValue = 0});

  /// Every tile that existed before the move, with where it ends up.
  final List<Slide> slides;

  /// Cell -> new value for each merge.
  final Map<int, int> merges;
  final int spawnCell, spawnValue;

  bool get changed => slides.isNotEmpty;
  int get gained => merges.values.fold(0, (a, b) => a + b);
}

/// Pure 4x4 board logic. Cells hold the rupee value (0 = empty), row-major.
class MergeBoard {
  MergeBoard({Random? rng, List<int>? cells}) : rng = rng ?? Random(), cells = cells ?? List.filled(size * size, 0);

  static const size = 4;
  final Random rng;
  final List<int> cells;

  static int tierOf(int value) => value <= 0 ? 0 : value.bitLength;

  List<int> _line(MergeDir d, int i) => switch (d) {
    MergeDir.left => [for (var k = 0; k < size; k++) i * size + k],
    MergeDir.right => [for (var k = size - 1; k >= 0; k--) i * size + k],
    MergeDir.up => [for (var k = 0; k < size; k++) k * size + i],
    MergeDir.down => [for (var k = size - 1; k >= 0; k--) k * size + i],
  };

  /// Slides and merges without spawning. A tile merges at most once per move.
  MoveResult slide(MergeDir d) {
    final next = List.filled(cells.length, 0);
    final slides = <Slide>[];
    final merges = <int, int>{};
    for (var i = 0; i < size; i++) {
      final line = _line(d, i);
      var out = 0;
      var lastMergeable = false;
      for (final from in line) {
        final v = cells[from];
        if (v == 0) continue;
        if (lastMergeable && next[line[out - 1]] == v) {
          final to = line[out - 1];
          next[to] = v * 2;
          merges[to] = v * 2;
          lastMergeable = false;
          slides.add(Slide(from, to, v));
        } else {
          final to = line[out++];
          next[to] = v;
          lastMergeable = true;
          slides.add(Slide(from, to, v));
        }
      }
    }
    final changed = slides.any((s) => s.from != s.to) || merges.isNotEmpty;
    if (!changed) return const MoveResult();
    cells.setAll(0, next);
    return MoveResult(slides: slides, merges: merges);
  }

  /// Slide, then spawn a tile (mostly ₹1, sometimes ₹2) if anything changed.
  MoveResult move(MergeDir d) {
    final r = slide(d);
    if (!r.changed) return r;
    final empty = [
      for (var i = 0; i < cells.length; i++)
        if (cells[i] == 0) i,
    ];
    if (empty.isEmpty) return r;
    final cell = empty[rng.nextInt(empty.length)];
    final value = rng.nextDouble() < 0.85 ? 1 : 2;
    cells[cell] = value;
    return MoveResult(slides: r.slides, merges: r.merges, spawnCell: cell, spawnValue: value);
  }

  int spawn() {
    final empty = [
      for (var i = 0; i < cells.length; i++)
        if (cells[i] == 0) i,
    ];
    if (empty.isEmpty) return -1;
    final cell = empty[rng.nextInt(empty.length)];
    cells[cell] = rng.nextDouble() < 0.85 ? 1 : 2;
    return cell;
  }

  bool get canMove {
    for (var i = 0; i < cells.length; i++) {
      if (cells[i] == 0) return true;
      final r = i ~/ size, c = i % size;
      if (c < size - 1 && cells[i + 1] == cells[i]) return true;
      if (r < size - 1 && cells[i + size] == cells[i]) return true;
    }
    return false;
  }

  int get highest => cells.fold(0, max);

  /// Indices of the [n] lowest-value tiles (empty cells ignored).
  List<int> lowest(int n) {
    final used = [
      for (var i = 0; i < cells.length; i++)
        if (cells[i] > 0) i,
    ]..sort((a, b) => cells[a].compareTo(cells[b]));
    return used.take(n).toList();
  }

  List<int> removeLowest(int n) {
    final gone = lowest(n);
    for (final i in gone) {
      cells[i] = 0;
    }
    return gone;
  }

  /// Raises the lowest tile by [tiers] tiers. Returns its cell or -1.
  int upgradeLowest(int tiers) {
    final low = lowest(1);
    if (low.isEmpty) return -1;
    cells[low.first] <<= tiers;
    return low.first;
  }
}
