import 'package:flutter/widgets.dart';

import '../../core/theme.dart';

/// Page physics for the reel. Use with `PageView(pageSnapping: false)`: this class does its own snapping.
///
/// The page can rest only on [page], or move to `page + 1` once [open]. While closed it does not accept
/// user drags at all, so a game's own vertical swipes never reach the pager. It never goes back.
class GatedPagePhysics extends ScrollPhysics {
  const GatedPagePhysics({required this.page, required this.open, this.reduceMotion = false, super.parent});

  final int page;
  final bool open;
  final bool reduceMotion;

  /// Release speed (logical px/s) that counts as a flick to the next page.
  static const flick = 300.0;

  @override
  GatedPagePhysics applyTo(ScrollPhysics? ancestor) =>
      GatedPagePhysics(page: page, open: open, reduceMotion: reduceMotion, parent: buildParent(ancestor));

  @override
  bool shouldUpdate(GatedPagePhysics old) =>
      page != old.page || open != old.open || reduceMotion != old.reduceMotion || super.shouldUpdate(old);

  double _lo(ScrollMetrics m) => page * m.viewportDimension;
  double _hi(ScrollMetrics m) => open ? (page + 1) * m.viewportDimension : _lo(m);

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => open;

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final lo = _lo(position), hi = _hi(position);
    if (value < lo) return value - lo;
    if (value > hi) return value - hi;
    return 0;
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final lo = _lo(position), hi = _hi(position);
    final forward = open && (velocity > flick || position.pixels - lo > position.viewportDimension / 2);
    final target = forward ? hi : lo;
    final tolerance = toleranceFor(position);
    if ((position.pixels - target).abs() < tolerance.distance) return null;
    // Critically damped (no overshoot); a near-instant spring when motion is reduced.
    final spring = reduceMotion ? SpringDescription.withDampingRatio(mass: 1, stiffness: 20000) : AppMotion.spring;
    final v = forward ? velocity.clamp(0.0, 4000.0) : 0.0;
    return ScrollSpringSimulation(spring, position.pixels, target, v, tolerance: tolerance);
  }
}
