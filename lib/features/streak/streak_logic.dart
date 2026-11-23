import '../../core/profile.dart';

/// Streak milestones (days) and the chest each one grants, one time each.
const streakMilestones = {3: 'wood', 7: 'silver', 14: 'silver', 30: 'gold'};

/// Whole calendar days from day key [a] to [b] (yyyy-mm-dd). Negative when [b] is earlier.
int daysBetween(String a, String b) {
  DateTime utc(String k) =>
      DateTime.utc(int.parse(k.substring(0, 4)), int.parse(k.substring(5, 7)), int.parse(k.substring(8, 10)));
  return utc(b).difference(utc(a)).inDays;
}

/// A broken streak can be repaired on the day it broke and the day after.
bool repairOpen(Profile p, String today) {
  if (p.lostStreak <= 0 || p.lostDay.isEmpty) return false;
  final d = daysBetween(p.lostDay, today);
  return d >= 0 && d <= 1;
}

/// The next milestone above [streak] that is not yet rewarded, or null when none is left.
int? nextMilestone(int streak, Set<int> done) {
  for (final m in streakMilestones.keys) {
    if (m > streak && !done.contains(m)) return m;
  }
  return null;
}

/// [p] with the chest for its current streak granted, if that streak is a milestone not paid before.
Profile grantMilestone(Profile p) {
  final chest = streakMilestones[p.streak];
  if (chest == null || p.milestonesDone.contains(p.streak)) return p;
  return p.copyWith(milestonesDone: {...p.milestonesDone, p.streak}, chests: [...p.chests, chest]);
}
