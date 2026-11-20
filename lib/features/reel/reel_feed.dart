import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reel_item.dart';

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
/// TODO(reel-sequencer): replaced by the real provider in reel_sequencer.dart.
final reelFeedProvider = FutureProvider<ReelFeed>((ref) async {
  throw UnimplementedError('reelFeedProvider is provided by reel_sequencer.dart');
});
