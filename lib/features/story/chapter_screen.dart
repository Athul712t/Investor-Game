import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/profile.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'dialogue_scene.dart';
import 'node_screens.dart';
import 'reward_scene.dart';
import 'story_data.dart';

/// One chapter as a vertical step list. Pops with true when the chapter's reward was claimed just now.
class ChapterScreen extends ConsumerStatefulWidget {
  const ChapterScreen({super.key, required this.story, required this.index});
  final Story story;
  final int index;

  @override
  ConsumerState<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends ConsumerState<ChapterScreen> {
  late final Chapter chapter = widget.story.chapters[widget.index];
  final _currentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _currentKey.currentContext;
      if (c != null) Scrollable.ensureVisible(c, alignment: 0.4);
    });
  }

  bool _busy = false;

  /// Guarded so a double tap cannot open a step twice (a doubled reward scene would pop the map too).
  Future<void> _play(int i) async {
    if (_busy) return;
    _busy = true;
    try {
      await _run(i);
    } finally {
      _busy = false;
    }
  }

  Future<void> _run(int i) async {
    final node = chapter.nodes[i];
    final id = chapter.nodeId(i);
    final profile = ref.read(profileProvider.notifier);
    final replay = ref.read(profileProvider).storyDone.contains(id);
    final nav = Navigator.of(context);
    Route<T> route<T>(Widget page) => MaterialPageRoute<T>(builder: (_) => page);

    var ok = false;
    switch (node.type) {
      case NodeType.dialogue:
        ok = await nav.push<bool>(route(DialogueScene(node: node, chapter: chapter))) ?? false;
      case NodeType.lesson:
        ok = await context.push<bool>('/lesson/${node.lessonId}') ?? false;
      case NodeType.game:
        ok = await nav.push<bool>(route(GameNodeScreen(node: node, color: chapter.color))) ?? false;
      case NodeType.scenario:
        final wise = await nav.push<bool>(route(ScenarioScreen(node: node, color: chapter.color)));
        ok = wise != null;
        if (wise == true && !replay) {
          profile.reward(xp: 10);
          if (mounted) _toast('🧠  Wise choice! +10 XP');
        }
      case NodeType.reward:
        if (!replay) {
          profile
            ..reward(xp: node.xp, coins: node.coins)
            ..completeStoryNode(id);
        }
        final next = widget.index + 1 < widget.story.chapters.length ? widget.story.chapters[widget.index + 1] : null;
        await nav.push(
          PageRouteBuilder<void>(
            transitionDuration: AppMotion.base,
            pageBuilder: (_, _, _) =>
                RewardScene(node: node, chapter: chapter, number: widget.index + 1, next: next, firstTime: !replay),
            transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
          ),
        );
        if (mounted) nav.pop(!replay);
        return;
    }
    if (ok) profile.completeStoryNode(id);
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.paperDeep,
      content: Text(msg, style: context.text.titleSmall),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final done = ref.watch(profileProvider).storyDone;
    final count = chapter.doneCount(done);
    final current = chapter.currentIndex(done);
    final complete = current == chapter.nodes.length;
    return AppScaffold(
      appBar: AppBar(title: Text('Chapter ${widget.index + 1}')),
      body: Column(
        children: [
          const SizedBox(height: kToolbarHeight),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.sm),
            child: Panel(
              accent: chapter.color,
              child: Row(
                children: [
                  Badge3D(emoji: chapter.emoji, color: chapter.color, size: 64),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(chapter.title, style: context.text.headlineSmall),
                        Text(chapter.subtitle, style: context.text.bodyMedium),
                        const SizedBox(height: AppSpace.sm),
                        Row(
                          children: [
                            Expanded(
                              child: FatProgress(value: count / chapter.nodes.length, color: chapter.color),
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Text('$count/${chapter.nodes.length}', style: context.text.titleSmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.md),
              itemCount: chapter.nodes.length,
              itemBuilder: (_, i) => _StepRow(
                key: i == current ? _currentKey : null,
                node: chapter.nodes[i],
                color: chapter.color,
                state: i < current || done.contains(chapter.nodeId(i))
                    ? _StepState.done
                    : i == current
                    ? _StepState.current
                    : _StepState.locked,
                first: i == 0,
                last: i == chapter.nodes.length - 1,
                onTap: () => _play(i),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.md),
            child: ChunkyButton(
              label: complete ? 'Back to map' : (count == 0 ? 'Start chapter' : 'Continue'),
              icon: complete ? Icons.map_rounded : Icons.play_arrow_rounded,
              color: complete ? AppColors.paperDeep : chapter.color,
              onPressed: () => complete ? Navigator.of(context).pop() : _play(current),
            ),
          ),
        ],
      ),
    );
  }
}

enum _StepState { done, current, locked }

class _StepRow extends StatelessWidget {
  const _StepRow({
    super.key,
    required this.node,
    required this.color,
    required this.state,
    required this.first,
    required this.last,
    required this.onTap,
  });
  final StoryNode node;
  final Color color;
  final _StepState state;
  final bool first, last;
  final VoidCallback onTap;

  (String, String) get _kind => switch (node.type) {
    NodeType.dialogue => ('💬', 'STORY'),
    NodeType.lesson => ('📘', 'LESSON'),
    NodeType.game => ('🎮', 'GAME · GOAL ${node.target} ${gameUnit(node.gameId)}'.toUpperCase()),
    NodeType.scenario => ('🤔', 'YOUR DECISION'),
    NodeType.reward => ('🏆', 'REWARD · +${node.xp} XP'),
  };

  @override
  Widget build(BuildContext context) {
    final (emoji, label) = _kind;
    final isDone = state == _StepState.done, isCurrent = state == _StepState.current;
    final dotColor = isDone ? AppColors.green : (isCurrent ? color : AppColors.paperDeep);
    final line = AppColors.track;
    return Semantics(
      button: state != _StepState.locked,
      label: '${node.title}, ${isDone ? 'done, tap to replay' : (isCurrent ? 'up next' : 'locked')}',
      excludeSemantics: true,
      onTap: state == _StepState.locked ? null : onTap, // excludeSemantics drops the Panel's own tap action
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Expanded(child: Container(width: 4, color: first ? Colors.transparent : line)),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.ink, width: 3),
                      boxShadow: isCurrent ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 14)] : null,
                    ),
                    child: Icon(
                      isDone ? Icons.check_rounded : (isCurrent ? Icons.play_arrow_rounded : Icons.lock_rounded),
                      size: isCurrent ? 22 : 16,
                      color: isDone || isCurrent ? AppColors.ink : AppColors.inkDim,
                    ),
                  ),
                  Expanded(child: Container(width: 4, color: last ? Colors.transparent : line)),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Opacity(
                  opacity: state == _StepState.locked ? 0.5 : 1,
                  child: Panel(
                    accent: isCurrent ? color : null,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    onTap: state == _StepState.locked ? null : onTap,
                    child: Row(
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: context.text.labelSmall!.copyWith(
                                  color: isCurrent ? color : AppColors.inkDim,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(node.title, style: context.text.titleMedium),
                            ],
                          ),
                        ),
                        if (isDone) const Icon(Icons.replay_rounded, color: AppColors.inkDim, size: 20),
                        if (isCurrent) Icon(Icons.chevron_right_rounded, color: color),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
