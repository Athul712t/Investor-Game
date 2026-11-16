/// Pure slice maths for Sky Stack. Positions are block centres, widths are full widths, any unit.
class SliceResult {
  const SliceResult.miss() : this._(miss: true);
  const SliceResult._({
    this.miss = false,
    this.perfect = false,
    this.center = 0,
    this.width = 0,
    this.cutCenter = 0,
    this.cutWidth = 0,
  });

  final bool miss;
  final bool perfect;

  /// The block that stays on the tower.
  final double center, width;

  /// The overhang that falls away (width 0 when perfect).
  final double cutCenter, cutWidth;
}

/// Drops a block of [width] centred on [center] onto a tower top of [prevWidth] centred on [prevCenter].
SliceResult sliceBlock({
  required double prevCenter,
  required double prevWidth,
  required double center,
  required double width,
  double tolerance = 0,
}) {
  final left = center - width / 2, right = center + width / 2;
  final pl = prevCenter - prevWidth / 2, pr = prevCenter + prevWidth / 2;
  final l = left > pl ? left : pl, r = right < pr ? right : pr;
  if (r - l <= 0) return const SliceResult.miss();
  if ((center - prevCenter).abs() <= tolerance) {
    final w = width < prevWidth ? width : prevWidth;
    return SliceResult._(perfect: true, center: prevCenter, width: w);
  }
  // The overhang is whichever side of the moving block sticks out past the tower.
  final cutLeft = left < pl;
  final cutW = width - (r - l);
  return SliceResult._(
    center: (l + r) / 2,
    width: r - l,
    cutCenter: cutLeft ? left + cutW / 2 : right - cutW / 2,
    cutWidth: cutW,
  );
}
