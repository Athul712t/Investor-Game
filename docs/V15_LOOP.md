# v1.5 "The Loop": shared spec for all agents

Retention through mastery, collection and streaks. No real money, no paid randomness, odds always shown.

## Foundation already in `main` (do not redo)
- `lib/core/profile.dart`: every v1.5 field exists with save/load tested (`dayStats, quests, chests, streakFreezes, lostStreak, lostDay, milestonesDone, review, credits, masteryClaimed, headStarts, owned, townDecor, pawn, notify, playHours`). **Only the streak agent edits profile.dart (the `touchStreak` method). Everyone else changes the profile through `ref.read(profileProvider.notifier).mutate((p) => p.copyWith(...))`, `reward(xp:, coins:)`, `spend(coins)`, `grantChest(type)`.**
- `lib/core/progress.dart`: `DayStats` (today's counters: games, lessons, correct, wrong, bests, reelCards, reviews, gameIds), `lessonIdOfQuestion(id)`.
- `ProfileController.noteAnswer(question, correct, {fromReview})` is already called wherever a question is answered (lessons, daily, reel, game chips, game second chance). It counts for quests, adds a mastery credit to the question's lesson on a correct answer, and queues a wrong answer into `review` (due tomorrow, step 0). `recordGame`, `completeLesson`, `noteReelCard` already update today's counters.
- Home has a `LoopSection` (lib/features/home_hub/loop_section.dart) laying out: `QuestsCard`, `StreakCard`, and tiles `ChestsTile`, `AlbumTile`, `ReviewTile`, `ShopTile`. Routes `/chests`, `/album`, `/review`, `/shop` exist with placeholder screens. Each piece is a placeholder in its own feature folder: **replace your own placeholders, keep class names and `const` constructors, and do not edit the other agents' files or loop_section.dart.**
- Question ids are `<lessonId>-q<n>` or `<lessonId>-x<n>`. Content: `contentProvider` (lib/core/content_repo.dart, `Content.lessons`, `Content.moduleOf`), extra reel questions: `reelExtraProvider` (lib/features/reel/reel_extra.dart).

## Economy numbers (use exactly these)
- Streak freeze: 60 coins, hold at most 1. Head start: 30 coins each, or 3 for 70 in the shop (`headStarts` tokens, used free at a game's intro).
- Quest rewards: easy 15 coins + 10 XP, medium 25 coins + 15 XP, hard 40 coins + 25 XP; claiming all three grants a **silver** chest.
- Streak milestones (one time each, tracked in `milestonesDone`): 3 days wood chest, 7 silver, 14 silver, 30 gold.
- Chest types: `'wood'`, `'silver'`, `'gold'`. Mastery levels (bronze, silver, gold) grant wood, silver, gold chests plus 25, 50, 100 coins.
- Mastery for cards: a lesson's `credits` count correct answers (+1 each, already recorded) and study boosts (+3 each). Card tiers: **common** = lesson completed; **rare** = lesson completed and credits >= 6; **gold** = lesson completed and credits >= 15.

## Ownership (each agent edits only its own paths)
| Agent | Paths |
|---|---|
| quests | lib/features/quests/, test/quests_*_test.dart |
| chests | lib/features/chests/, test/chests_*_test.dart |
| cards | lib/features/cards/, assets/content/cards.json is written by a data agent (schema below), test/cards_*_test.dart |
| streak | lib/features/streak/, the `touchStreak` method in lib/core/profile.dart, test/streak_*_test.dart |
| review | lib/features/review/, test/review_*_test.dart |
| shop | lib/features/shop/, lib/features/home_hub/town.dart (decorations), the pawn in lib/features/story/story_map_screen.dart, test/shop_*_test.dart |
| games economy | lib/features/games/_shared/game_run.dart, games_registry.dart, lib/features/games/arcade_screen.dart, test/game_*_test.dart, test/arcade_*_test.dart |
| notifications (later) | lib/features/profile/notify_section.dart and build config |

## Cards data (`assets/content/cards.json`)
`{"cards":[{"id":"nav","title":"NAV","emoji":"🏷️","lesson":"mf-basics-3","tier":"common","blurb":"The price of one unit of a fund."}]}` 40 cards: 24 common, 12 rare, 4 gold; every one of the 12 lessons has at least 3 cards; title at most 18 characters; blurb at most 70 characters.

## Rules for everything
- Bazaar Board look (docs/DESIGN.md): solid colours, ink outlines, hard shadows, painted pictograms for chrome (no emoji as icons in chrome; emoji allowed on cards as content), no gradients, no blur, no violet. Respect `context.reduceMotion`.
- Performance (a real slowdown was found earlier): no per-frame allocations in painters beyond reused `Paint`/cached `TextPainter`; no `MaskFilter.blur`, `saveLayer` or `Path.combine` in paint code; animations only while visible.
- Education content stays draft; correctness of finance facts is not the priority yet, keep copy plain and never advice.
- Tests: pure logic in plain Dart files with unit tests; widget tests for the screens; keep test/layout_test.dart pattern (360x640, text scale 1.3) for new screens. `flutter analyze --no-fatal-infos` clean, `dart format lib test`, full `flutter test` green.
- Home screenshots: the shot tool cannot scroll Flutter lists. Copy tool/shot.mjs to your scratchpad and add a step that does `await page.mouse.move(195, 400); await page.mouse.wheel(0, N);`. Seed state by writing localStorage key `flutter.profile_v1` (a JSON string of `Profile.toJson()`, JSON-encoded again as a string) with `page.addInitScript` in your scratch copy; never commit seeding hacks. Keep screenshot rounds to three.
