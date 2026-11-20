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
///  - the first card is a game; never more than 2 games in a row; never 3 non-games in a row;
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

/// Built from content, the reel's extra content and the saved cursor.
final reelFeedProvider = FutureProvider<ReelFeed>((ref) async {
  final content = await ref.watch(contentProvider.future);
  final extra = await ref.watch(reelExtraProvider.future);
  final saved = ref.read(profileProvider).reelCursor;
  return ReelSequencer(
    lessons: content.lessons,
    extra: extra,
    gameIds: games.map((g) => g.id).toList(),
    rng: Random(),
    cursor: saved.isEmpty ? null : ReelCursor.fromJson(saved),
  );
});
