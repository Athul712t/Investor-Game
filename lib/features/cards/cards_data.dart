import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cards_logic.dart';

/// Parses cards.json. A broken file never throws; broken entries are skipped.
List<CardDef> parseCards(String source) {
  try {
    final list = (jsonDecode(source) as Map)['cards'] as List;
    return [for (final j in list) ?CardDef.tryParse(j)];
  } catch (_) {
    return const [];
  }
}

final cardsProvider = FutureProvider<List<CardDef>>((ref) async {
  try {
    return parseCards(await rootBundle.loadString('assets/content/cards.json'));
  } catch (_) {
    return const [];
  }
});
