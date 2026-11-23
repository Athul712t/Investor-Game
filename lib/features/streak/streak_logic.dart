import '../../core/streak_rules.dart';

// The rules profile.dart applies live in core; this file re-exports them for the streak feature.
export '../../core/streak_rules.dart';

/// The next milestone above [streak] that is not yet rewarded, or null when none is left.
int? nextMilestone(int streak, Set<int> done) {
  for (final m in streakMilestones.keys) {
    if (m > streak && !done.contains(m)) return m;
  }
  return null;
}
