import 'dart:convert';

import 'package:flutter/services.dart';

class SortItem {
  const SortItem(this.text, {required this.left});
  final String text;

  /// True when it belongs in the left bin.
  final bool left;
}

class SortDeck {
  const SortDeck(this.leftLabel, this.rightLabel, this.items);
  final String leftLabel, rightLabel;
  final List<SortItem> items;
}

/// Word lists for Sort Rush and Scam Whack (assets/content/quick_games.json).
class QuickGameData {
  const QuickGameData({required this.sortDecks, required this.realOffers, required this.scams});

  final List<SortDeck> sortDecks;

  /// Short labels (about 24 characters) for the good tiles in Scam Whack.
  final List<String> realOffers;

  /// Short labels for the scam tiles in Scam Whack.
  final List<String> scams;

  static const fallback = QuickGameData(
    sortDecks: [
      SortDeck('Need', 'Want', [
        SortItem('Rent', left: true),
        SortItem('Latest phone upgrade', left: false),
        SortItem('Groceries', left: true),
        SortItem('Shopping spree', left: false),
      ]),
    ],
    realOffers: ['Check the riskometer', 'Start a small SIP'],
    scams: ['100% returns!', 'Guaranteed profit'],
  );

  static Future<QuickGameData>? _loading;

  /// Loaded once; falls back to a tiny built-in set if the asset is missing or broken.
  static Future<QuickGameData> load() => _loading ??= _read();

  static Future<QuickGameData> _read() async {
    try {
      final j = jsonDecode(await rootBundle.loadString('assets/content/quick_games.json')) as Map;
      final decks = [
        for (final d in (j['sort']! as Map)['decks'] as List)
          SortDeck((d as Map)['left']! as String, d['right']! as String, [
            for (final i in d['items'] as List) SortItem((i as Map)['text']! as String, left: i['side'] == 'left'),
          ]),
      ];
      final scam = j['scam']! as Map;
      final data = QuickGameData(
        sortDecks: decks,
        realOffers: [...(scam['real']! as List).cast<String>()],
        scams: [...(scam['scam']! as List).cast<String>()],
      );
      return data.sortDecks.isEmpty || data.realOffers.isEmpty || data.scams.isEmpty ? fallback : data;
    } catch (_) {
      return fallback;
    }
  }
}
