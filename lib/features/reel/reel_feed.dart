import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/content_repo.dart';
import '../../core/profile.dart';
import '../games/_shared/games_registry.dart';
import 'reel_extra.dart';
import 'reel_item.dart';
import 'reel_sequencer.dart';

/// Produces the endless stream of reel cards.
///
/// Rules (implemented by `ReelSequencer`, tested in test/reel_sequencer_test.dart):
///  - the Reel mode setting sets the share of games (1.0, 0.75, 0.5, 0.25, 0.0);
///  - the first card is a game unless the share is 0; at an even mix never more than 2 games or
///    2 non-games in a row (the side with the larger share may run to 4);
///  - a game never repeats within the last 2 games;
///  - questions and reads follow the lessons in order (a lesson's reads, then its questions);
///  - a wrong answer comes back a few learning cards later, once;
///  - after the last lesson the sequence loops to the first.
abstract class ReelFeed {
  /// The next card. Never null.
  ReelItem next();

  /// Where the learning sequence resumes. Persist it with `profileProvider.notifier.saveReel`.
  ReelCursor get cursor;

  /// The player answered [q] wrong.
  void reportWrong(ReelQuestion q);
}

/// Built from content, the reel's extra content, the saved cursor and the Reel mode setting.
/// Auto-disposed with the reel, so each visit picks up the current setting and resumes from the saved cursor.
final reelFeedProvider = FutureProvider.autoDispose<ReelFeed>((ref) async {
  final content = await ref.watch(contentProvider.future);
  final extra = await ref.watch(reelExtraProvider.future);
  final profile = ref.read(profileProvider);
  final saved = profile.reelCursor;
  return ReelSequencer(
    lessons: content.lessons,
    extra: extra,
    gameIds: games.map((g) => g.id).toList(),
    rng: Random(),
    cursor: saved.isEmpty ? null : ReelCursor.fromJson(saved),
    gameShare: ReelMix.shareOf(profile.reelMix),
  );
});
