import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/content.dart';
import '../domain/entities/question.dart';

class Content {
  Content(this.modules);
  final List<Module> modules;

  late final List<Lesson> lessons = [for (final m in modules) ...m.lessons];
  late final List<Question> quickQuestions = [for (final l in lessons) ...l.questions.where((q) => q.isQuick)];

  Lesson? lesson(String id) => lessons.where((l) => l.id == id).firstOrNull;
  Module? moduleOf(String lessonId) => modules.where((m) => m.lessons.any((l) => l.id == lessonId)).firstOrNull;

  /// Random quick question for an in-game boost.
  Question? randomQuick([Random? rng]) =>
      quickQuestions.isEmpty ? null : quickQuestions[(rng ?? Random()).nextInt(quickQuestions.length)];

  factory Content.fromJson(String source) => Content([
    for (final m in (jsonDecode(source) as Map)['modules'] as List)
      Module.fromJson(Map<String, Object?>.from(m as Map)),
  ]);
}

/// Bundled content. Firestore can override this later without touching callers.
final contentProvider = FutureProvider<Content>(
  (ref) async => Content.fromJson(await rootBundle.loadString('assets/content/modules.json')),
);
