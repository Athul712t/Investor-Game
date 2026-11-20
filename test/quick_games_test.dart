import 'package:flutter_test/flutter_test.dart';
import 'package:investor_game/features/games/_shared/quick_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late QuickGameData data;

  setUpAll(() async {
    data = await QuickGameData.load();
  });

  test('quick_games.json loads and is not the built-in fallback', () {
    expect(data.sortDecks.length, greaterThan(QuickGameData.fallback.sortDecks.length));
    expect(data.sortDecks.length, greaterThan(8), reason: 'fell back to the built-in set');
  });

  test('there are at least 10 sort decks', () {
    expect(data.sortDecks.length, greaterThanOrEqualTo(10));
  });

  test('every sort deck has 20 to 24 items, both sides at least 8, short text and labels', () {
    for (final deck in data.sortDecks) {
      final label = '${deck.leftLabel} / ${deck.rightLabel}';
      expect(deck.items.length, inInclusiveRange(20, 24), reason: label);
      expect(deck.leftLabel.length, lessThanOrEqualTo(14), reason: label);
      expect(deck.rightLabel.length, lessThanOrEqualTo(14), reason: label);
      final left = deck.items.where((i) => i.left).length;
      final right = deck.items.length - left;
      expect(left, greaterThanOrEqualTo(8), reason: '$label left side');
      expect(right, greaterThanOrEqualTo(8), reason: '$label right side');
      for (final item in deck.items) {
        expect(item.text.length, lessThanOrEqualTo(40), reason: '$label: ${item.text}');
      }
    }
  });

  test('scam whack has 60 real and 60 scam labels, short, unique, no overlap', () {
    expect(data.realOffers.length, 60);
    expect(data.scams.length, 60);
    for (final label in [...data.realOffers, ...data.scams]) {
      expect(label.length, lessThanOrEqualTo(24), reason: label);
    }
    expect(data.realOffers.toSet().length, data.realOffers.length, reason: 'duplicate real label');
    expect(data.scams.toSet().length, data.scams.length, reason: 'duplicate scam label');
    expect(data.realOffers.toSet().intersection(data.scams.toSet()), isEmpty);
  });
}
