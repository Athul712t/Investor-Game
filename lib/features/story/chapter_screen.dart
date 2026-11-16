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

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)));

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

/// One step as a board tile. Tiles are joined by a dotted line through their markers.
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

  (IconData, String) get _kind => switch (node.type) {
    NodeType.dialogue => (Icons.forum_rounded, 'STORY'),
    NodeType.lesson => (Icons.menu_book_rounded, 'LESSON'),
    NodeType.game => (
      Icons.sports_esports_rounded,
      'GAME · GOAL ${node.target} ${gameUnit(node.gameId)}'.toUpperCase(),
    ),
    NodeType.scenario => (Icons.call_split_rounded, 'YOUR DECISION'),
    NodeType.reward => (Icons.emoji_events_rounded, 'REWARD · +${node.xp} XP'),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, label) = _kind;
    final isDone = state == _StepState.done, isCurrent = state == _StepState.current;
    final locked = state == _StepState.locked;
    final fill = isCurrent ? color : (locked ? AppColors.paperDeep : AppColors.card);
    final fg = isCurrent ? AppColors.on(color) : (locked ? AppColors.inkDim : AppColors.ink);
    final depth = isCurrent ? 7.0 : (locked ? 0.0 : 4.0);
    final semantic = '${node.title}, ${isDone ? 'done, tap to replay' : (isCurrent ? 'up next' : 'locked')}';

    // Every tile takes the same height; a raised one gives up margin for its thicker edge.
    Widget tile(bool down) => Padding(
      padding: EdgeInsets.only(top: 6, bottom: 6 + 7 - depth),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: Matrix4.translationValues(0, down ? depth : 0, 0),
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        decoration: pieceDecoration(fill: fill, radius: 14, depth: down ? 0 : depth),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: pieceDecoration(
                fill: isCurrent ? AppColors.card : (locked ? AppColors.track : AppColors.tint(color, 0.6)),
                radius: 10,
                depth: 0,
              ),
              child: Icon(icon, size: 22, color: locked ? AppColors.inkDim : AppColors.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.text.labelSmall!.copyWith(color: fg, letterSpacing: 1)),
                  Text(node.title, style: context.text.titleMedium!.copyWith(color: fg)),
                ],
              ),
            ),
            if (isDone) const Icon(Icons.replay_rounded, color: AppColors.inkDim, size: 20),
            if (isCurrent) Icon(Icons.play_arrow_rounded, color: fg, size: 28),
          ],
        ),
      ),
    );

    final card = locked
        ? Semantics(label: semantic, excludeSemantics: true, child: tile(false))
        : Pressable(label: semantic, onTap: onTap, builder: (_, down) => tile(down));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DotsPainter(top: !first, bottom: !last),
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: pieceDecoration(
                    fill: isDone ? AppColors.green : (isCurrent ? color : AppColors.paperDeep),
                    radius: 9,
                    depth: locked ? 0 : 3,
                  ),
                  child: Icon(
                    isDone ? Icons.check_rounded : (isCurrent ? Icons.flag_rounded : Icons.lock_rounded),
                    size: locked ? 16 : 20,
                    color: isCurrent ? AppColors.on(color) : (locked ? AppColors.inkDim : AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: isCurrent ? _Pulse(child: card) : card),
        ],
      ),
    );
  }
}

/// Dotted line through the step markers: the stretch above and/or below the centre.
class _DotsPainter extends CustomPainter {
  _DotsPainter({required this.top, required this.bottom});
  final bool top, bottom;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = AppColors.ink;
    final x = size.width / 2, mid = size.height / 2;
    for (var y = 3.0; y < size.height; y += 11) {
      if ((y < mid && top) || (y > mid && bottom)) canvas.drawCircle(Offset(x, y), 2.6, p);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.top != top || old.bottom != bottom;
}

/// Gentle scale pulse for the step that is up next. Still under reduce motion.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.reduceMotion ? _c.stop() : _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) => Transform.scale(scale: 1 + 0.025 * Curves.easeInOut.transform(_c.value), child: child),
    child: widget.child,
  );
}
