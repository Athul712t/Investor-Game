import '../../core/profile.dart';

/// Correct answers (credits) a lesson needs before its rare or gold card unlocks.
const rareCredits = 6, goldCredits = 15;

class CardDef {
  const CardDef({
    required this.id,
    required this.title,
    required this.emoji,
    required this.lesson,
    required this.tier,
    required this.blurb,
  });
  final String id, title, emoji, lesson, tier, blurb;

  /// Credits needed on top of the completed lesson: 0 for common.
  int get needed => switch (tier) {
    'gold' => goldCredits,
    'rare' => rareCredits,
    _ => 0,
  };

  static CardDef? tryParse(Object? j) {
    if (j is! Map) return null;
    String? s(String k) => j[k] is String ? j[k] as String : null;
    final id = s('id'), title = s('title'), lesson = s('lesson');
    if (id == null || title == null || lesson == null) return null;
    final tier = s('tier');
    return CardDef(
      id: id,
      title: title,
      emoji: s('emoji') ?? '🃏',
      lesson: lesson,
      tier: tier == 'rare' || tier == 'gold' ? tier! : 'common',
      blurb: s('blurb') ?? '',
    );
  }
}

bool isUnlocked(CardDef c, Profile p) =>
    p.completedLessons.contains(c.lesson) && (p.credits[c.lesson] ?? 0) >= c.needed;

/// 0 to 1. Common is 1 once the lesson is completed and 0 before; rare and gold count credits.
double unlockProgress(CardDef c, Profile p) {
  if (c.needed == 0) return p.completedLessons.contains(c.lesson) ? 1 : 0;
  return ((p.credits[c.lesson] ?? 0) / c.needed).clamp(0.0, 1.0);
}

/// How to unlock a locked card, e.g. "Finish NAV and units" or "Needs 6 correct answers in NAV and units (3 of 6)".
String unlockHint(CardDef c, Profile p, String lessonTitle) {
  if (!p.completedLessons.contains(c.lesson)) return 'Finish $lessonTitle';
  final have = (p.credits[c.lesson] ?? 0).clamp(0, c.needed);
  return 'Needs ${c.needed} correct answers in $lessonTitle ($have of ${c.needed})';
}

Set<String> unlockedIds(List<CardDef> cards, Profile p) => {
  for (final c in cards)
    if (isUnlocked(c, p)) c.id,
};
