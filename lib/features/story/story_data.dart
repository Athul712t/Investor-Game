// Story Mode data, loaded from assets/content/story.json.
//
// Shape:
// {"chapters": [{
//    "id": "salary-day", "title": "...", "subtitle": "...", "emoji": "💸", "color": "amber",
//    "nodes": [ every node has "type" and a short "title" for the step list, plus:
//      dialogue: "lines": [{"speaker": "asha" | "kabir" | "you" | "narrator", "text": "... {name} ..."}]
//      lesson:   "lessonId": "mf-basics-1"
//      game:     "gameId": "runner", "target": 150, "intro": "goal blurb"
//      scenario: "question": a content Question with "type": "scenario"
//      reward:   "xp": 60, "coins": 40   (title is the badge title; every chapter ends with one)
//    ]
// }]}
//
// Progress lives in Profile.storyDone as "chapterId/index" strings.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/entities/question.dart';

enum NodeType { dialogue, lesson, game, scenario, reward }

class DialogueLine {
  const DialogueLine(this.speaker, this.text);
  final String speaker, text;
}

class StoryNode {
  const StoryNode({
    required this.type,
    required this.title,
    this.lines = const [],
    this.lessonId,
    this.gameId,
    this.target = 0,
    this.intro = '',
    this.question,
    this.xp = 0,
    this.coins = 0,
  });
  final NodeType type;
  final String title;
  final List<DialogueLine> lines;
  final String? lessonId, gameId;
  final int target;
  final String intro;
  final Question? question;
  final int xp, coins;

  factory StoryNode.fromJson(Map<String, Object?> j) => StoryNode(
    type: NodeType.values.byName(j['type']! as String),
    title: j['title']! as String,
    lines: [
      for (final l in (j['lines'] ?? const []) as List)
        DialogueLine((l as Map)['speaker']! as String, l['text']! as String),
    ],
    lessonId: j['lessonId'] as String?,
    gameId: j['gameId'] as String?,
    target: (j['target'] ?? 0) as int,
    intro: (j['intro'] ?? '') as String,
    question: j['question'] == null ? null : Question.fromJson(Map<String, Object?>.from(j['question']! as Map)),
    xp: (j['xp'] ?? 0) as int,
    coins: (j['coins'] ?? 0) as int,
  );
}

class Chapter {
  const Chapter({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.color,
    required this.nodes,
  });
  final String id, title, subtitle, emoji;
  final Color color;
  final List<StoryNode> nodes;

  String nodeId(int i) => '$id/$i';

  int doneCount(Set<String> done) => [for (var i = 0; i < nodes.length; i++) nodeId(i)].where(done.contains).length;

  bool isComplete(Set<String> done) => doneCount(done) == nodes.length;

  /// First node not yet done, or nodes.length when the chapter is complete.
  int currentIndex(Set<String> done) {
    for (var i = 0; i < nodes.length; i++) {
      if (!done.contains(nodeId(i))) return i;
    }
    return nodes.length;
  }

  factory Chapter.fromJson(Map<String, Object?> j) => Chapter(
    id: j['id']! as String,
    title: j['title']! as String,
    subtitle: (j['subtitle'] ?? '') as String,
    emoji: (j['emoji'] ?? '📖') as String,
    color: AppColors.named(j['color'] as String?),
    nodes: [for (final n in j['nodes']! as List) StoryNode.fromJson(Map<String, Object?>.from(n as Map))],
  );
}

class Story {
  Story(this.chapters);
  final List<Chapter> chapters;

  /// A chapter unlocks when every node of the previous chapter is done.
  bool isUnlocked(int chapter, Set<String> done) => chapter == 0 || chapters[chapter - 1].isComplete(done);

  factory Story.fromJson(String source) => Story([
    for (final c in (jsonDecode(source) as Map)['chapters'] as List)
      Chapter.fromJson(Map<String, Object?>.from(c as Map)),
  ]);
}

final storyProvider = FutureProvider<Story>(
  (ref) async => Story.fromJson(await rootBundle.loadString('assets/content/story.json')),
);

/// The cast. Unknown speakers fall back to the narrator.
class Speaker {
  const Speaker(this.name, this.emoji, this.color);
  final String name, emoji;
  final Color color;

  static const cast = {
    'asha': Speaker('Asha', '👩🏽‍💼', AppColors.violet),
    'kabir': Speaker('Kabir', '😎', AppColors.coral),
    'you': Speaker('You', '🙂', AppColors.mint),
    'narrator': Speaker('', '📖', AppColors.sky),
  };
  static Speaker of(String id) => cast[id] ?? cast['narrator']!;
}
