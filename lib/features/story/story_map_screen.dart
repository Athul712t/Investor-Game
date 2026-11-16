import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/profile.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'chapter_screen.dart';
import 'story_art.dart';
import 'story_data.dart';

/// Story Mode home: a board of stepping tiles with a chapter stop at each bend. Route /story.
class StoryMapScreen extends ConsumerWidget {
  const StoryMapScreen({super.key});

  Future<void> _open(BuildContext context, Story story, int i) async {
    final finished = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChapterScreen(story: story, index: i),
      ),
    );
    if (finished == true && context.mounted && i + 1 < story.chapters.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text('🔓  ${story.chapters[i + 1].title} unlocked!')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final story = ref.watch(storyProvider);
    final profile = ref.watch(profileProvider);
    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Story Mode'),
        actions: [
          StatPill(icon: Icons.bolt_rounded, value: '${profile.xp}', color: AppColors.blue, semantic: 'XP'),
          const SizedBox(width: AppSpace.md),
        ],
      ),
      body: story.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load the story', style: context.text.bodyLarge)),
        // The board is clipped at the toolbar so it never slides under the title.
        data: (s) => Padding(
          padding: const EdgeInsets.only(top: kToolbarHeight),
          child: ClipRect(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.xl),
              children: [
                Text(
                  'From Pocket Money\nto Portfolio',
                  textAlign: TextAlign.center,
                  style: context.text.headlineMedium,
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  '${profile.name}, your first job in the city starts now',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium,
                ),
                const SizedBox(height: AppSpace.sm),
                _Board(story: s, done: profile.storyDone, onOpen: (i) => _open(context, s, i)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.story, required this.done, required this.onOpen});
  final Story story;
  final Set<String> done;
  final ValueChanged<int> onOpen;

  static const _row = 236.0, _top = 40.0;
  static const _pieces = [
    (SetPiece.tree, SetPiece.stall),
    (SetPiece.bank, SetPiece.bush),
    (SetPiece.stall, SetPiece.tree),
    (SetPiece.bush, SetPiece.bank),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final w = c.maxWidth;
      final n = story.chapters.length;
      // Stops: start tile, one per chapter (zig-zag), then the construction sign.
      final points = [
        Offset(w * 0.5, _top),
        for (var i = 0; i < n; i++) Offset(w * (i.isEven ? 0.25 : 0.75), _top + (i + 1) * _row),
        Offset(w * 0.5, _top + (n + 1) * _row - 40),
      ];
      final unlocked = [for (var i = 0; i < n; i++) story.isUnlocked(i, done)];
      final current = unlocked.lastIndexWhere((u) => u);
      final allDone = story.chapters.last.isComplete(done);
      final colors = [for (final ch in story.chapters) ch.color, AppColors.green];
      // The pawn stands on the front-right of the stop's plinth top.
      Offset stand(int i) => i < 0 ? points.first + const Offset(0, 22) : points[i + 1] + const Offset(32, 8);
      return SizedBox(
        height: points.last.dy + 120,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: _TilePainter(points: points, colors: colors, lit: current + 1 + (allDone ? 1 : 0)),
                ),
              ),
            ),
            for (var i = 0; i <= n; i++) ..._scenery(i, w, points),
            Positioned(
              left: 0,
              right: 0,
              top: points.first.dy - 26,
              child: const Center(child: _StartTile()),
            ),
            for (var i = 0; i < n; i++)
              Positioned(
                left: 0,
                right: 0,
                top: points[i + 1].dy - _Stop.lift,
                child: _ChapterStop(
                  index: i,
                  chapter: story.chapters[i],
                  done: done,
                  unlocked: unlocked[i],
                  current: i == current && !story.chapters[i].isComplete(done),
                  leftSide: i.isEven,
                  width: w,
                  prevTitle: i == 0 ? '' : story.chapters[i - 1].title,
                  onTap: () => onOpen(i),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              top: points.last.dy - 30,
              child: const Center(child: _ComingSoonSign()),
            ),
            _Pawn(from: stand(current - 1), to: stand(current)),
          ],
        ),
      );
    },
  );

  // Two standees at the outer edges halfway along each stretch, where the path runs through the middle.
  // The one under the previous plinth sits higher; the other sits lower, clear of that stop's text.
  List<Widget> _scenery(int i, double w, List<Offset> points) {
    final mid = (points[i].dy + points[i + 1].dy) / 2;
    final (a, b) = _pieces[i % _pieces.length];
    final size = min(72.0, w * 0.19);
    final leftHigh = (i - 1).isEven;
    Widget stand(SetPiece p) => ExcludeSemantics(
      child: CustomPaint(size: Size.square(size), painter: SetPiecePainter(p)),
    );
    return [
      Positioned(top: mid + (leftHigh ? -70 : -20), left: w * 0.02, child: stand(a)),
      Positioned(top: mid + (leftHigh ? -20 : -70), right: w * 0.02, child: stand(b)),
    ];
  }
}

/// Stepping tiles along the winding path. The first [lit] stretches are coloured, the rest paperDeep.
class _TilePainter extends CustomPainter {
  _TilePainter({required this.points, required this.colors, required this.lit});
  final List<Offset> points;
  final List<Color> colors;
  final int lit;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSpace.outline
      ..color = AppColors.ink;
    final shadow = Paint()..color = AppColors.ink;
    const tile = RRect.fromLTRBXY(-13, -11, 13, 11, 5, 5);
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1];
      final dy = (b.dy - a.dy) * 0.6;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, a.dy + dy, b.dx, b.dy - dy, b.dx, b.dy);
      final on = i < lit;
      // Leave room for the start tile and stops at both ends.
      final skipStart = i == 0 ? 40.0 : 58.0;
      final skipEnd = i == points.length - 2 ? 50.0 : 78.0;
      for (final m in path.computeMetrics()) {
        final usable = m.length - skipStart - skipEnd;
        final count = max(2, (usable / 34).floor());
        for (var k = 0; k <= count; k++) {
          final t = m.getTangentForOffset(skipStart + usable * k / count)!;
          final fill = !on
              ? AppColors.paperDeep
              : k.isEven
              ? colors[i]
              : AppColors.card;
          canvas
            ..save()
            ..translate(t.position.dx, t.position.dy + 4)
            ..rotate(-t.angle)
            ..drawRRect(tile, shadow)
            ..restore()
            ..save()
            ..translate(t.position.dx, t.position.dy)
            ..rotate(-t.angle)
            ..drawRRect(tile, Paint()..color = fill)
            ..drawRRect(tile, stroke)
            ..restore();
        }
      }
    }
  }

  @override
  bool shouldRepaint(_TilePainter old) => old.lit != lit || old.points != points || old.colors != colors;
}

class _StartTile extends StatelessWidget {
  const _StartTile();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
    decoration: pieceDecoration(fill: AppColors.card, radius: 14),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: pieceDecoration(fill: AppColors.green, radius: 9, depth: 0),
          child: const Icon(Icons.flag_rounded, size: 20, color: AppColors.ink),
        ),
        const SizedBox(width: AppSpace.sm),
        Text('START', style: context.text.titleLarge),
        Flexible(
          child: Text('  first job', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium),
        ),
      ],
    ),
  );
}

/// A construction sign on two legs with a striped barrier.
class _ComingSoonSign extends StatelessWidget {
  const _ComingSoonSign();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Stack(
      children: [
        // Legs behind the board.
        const Positioned(left: 40, top: 30, bottom: 0, child: _Leg()),
        const Positioned(right: 40, top: 30, bottom: 0, child: _Leg()),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: pieceDecoration(fill: AppColors.card, radius: 12),
              child: Column(
                children: [
                  const SizedBox(
                    height: 14,
                    width: double.infinity,
                    child: CustomPaint(painter: _StripePainter()),
                  ),
                  Container(height: AppSpace.outline, color: AppColors.ink),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    child: Text(
                      'More chapters coming soon',
                      textAlign: TextAlign.center,
                      style: context.text.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Container(
              height: 18,
              clipBehavior: Clip.antiAlias,
              decoration: pieceDecoration(fill: AppColors.card, radius: 4, depth: 3),
              child: const SizedBox.expand(child: CustomPaint(painter: _StripePainter())),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ],
    ),
  );
}

class _Leg extends StatelessWidget {
  const _Leg();

  @override
  Widget build(BuildContext context) =>
      Container(width: 12, decoration: pieceDecoration(fill: AppColors.paperDeep, radius: 3, depth: 0));
}

class _StripePainter extends CustomPainter {
  const _StripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.yellow);
    final ink = Paint()..color = AppColors.ink;
    for (var x = -size.height; x < size.width; x += 22) {
      canvas.drawPath(
        Path()
          ..moveTo(x, size.height)
          ..lineTo(x + 10, size.height)
          ..lineTo(x + 10 + size.height, 0)
          ..lineTo(x + size.height, 0)
          ..close(),
        ink,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _ChapterStop extends StatelessWidget {
  const _ChapterStop({
    required this.index,
    required this.chapter,
    required this.done,
    required this.unlocked,
    required this.current,
    required this.leftSide,
    required this.width,
    required this.prevTitle,
    required this.onTap,
  });
  final int index;
  final Chapter chapter;
  final Set<String> done;
  final bool unlocked, current, leftSide;
  final double width;
  final String prevTitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = chapter.doneCount(done);
    final total = chapter.nodes.length;
    final complete = count == total;
    final c = chapter.color;
    final status = !unlocked
        ? 'Finish $prevTitle to unlock'
        : complete
        ? 'Complete · tap to replay'
        : '$count of $total steps';
    final align = leftSide ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    final textAlign = leftSide ? TextAlign.left : TextAlign.right;
    final text = Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Ribbon(
          color: unlocked ? c : AppColors.paperDeep,
          child: Column(
            crossAxisAlignment: align,
            children: [
              Text(
                'CHAPTER ${index + 1}',
                style: context.text.labelSmall!.copyWith(
                  color: unlocked ? AppColors.on(c) : AppColors.inkDim,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                chapter.title,
                textAlign: textAlign,
                style: context.text.titleLarge!.copyWith(color: unlocked ? AppColors.on(c) : AppColors.inkDim),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(chapter.subtitle, textAlign: textAlign, style: context.text.bodySmall),
        const SizedBox(height: 6),
        if (current)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 3, 8, 3),
            decoration: pieceDecoration(fill: AppColors.green, radius: 999, depth: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(count == 0 ? 'START' : 'CONTINUE', style: context.text.labelSmall!.copyWith(color: AppColors.ink)),
                const Icon(Icons.play_arrow_rounded, size: 16, color: AppColors.ink),
              ],
            ),
          )
        else
          Text(
            status,
            textAlign: textAlign,
            style: context.text.labelSmall!.copyWith(color: complete ? side(AppColors.green) : AppColors.inkDim),
          ),
      ],
    );
    void tap() {
      if (unlocked) return onTap();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text('🔒  $status')));
    }

    return Pressable(
      label: 'Chapter ${index + 1}, ${chapter.title}. ${unlocked ? '$count of $total steps done' : status}',
      onTap: tap,
      // Min, not fixed, height: large text may run below the plinth into the gap before the next stop.
      builder: (context, down) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _Stop.height),
        child: Row(
          textDirection: leftSide ? TextDirection.ltr : TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: width * 0.25 - _Stop.width / 2),
            _Stop(
              emoji: chapter.emoji,
              color: c,
              progress: count / total,
              unlocked: unlocked,
              complete: complete,
              down: down,
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Padding(padding: const EdgeInsets.only(top: 10), child: text),
            ),
          ],
        ),
      ),
    );
  }
}

/// The chapter stop: a drum plinth with the progress ring on its top and the emoji block standing on it.
class _Stop extends StatelessWidget {
  const _Stop({
    required this.emoji,
    required this.color,
    required this.progress,
    required this.unlocked,
    required this.complete,
    required this.down,
  });
  final String emoji;
  final Color color;
  final double progress;
  final bool unlocked, complete, down;

  static const width = 116.0, height = 128.0;

  /// Distance from the stop's top edge to its board point (the centre of the plinth top).
  static const lift = 92.0;

  @override
  Widget build(BuildContext context) {
    final sink = down ? 4.0 : 0.0;
    final block = Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: pieceDecoration(fill: unlocked ? color : AppColors.paperDeep, radius: 14, depth: unlocked ? 4 : 0),
      child: unlocked
          ? Text(emoji, style: const TextStyle(fontSize: 28))
          : const Icon(Icons.lock_rounded, size: 26, color: AppColors.inkDim),
    );
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _PlinthPainter(
                color: unlocked ? color : AppColors.paperDeep,
                progress: unlocked ? progress : 0,
                raised: unlocked,
                sink: sink,
              ),
            ),
          ),
          Positioned(left: (width - 56) / 2, top: lift - 56 + sink + (unlocked ? -4 : 2), child: block),
          if (complete)
            Positioned(
              left: width / 2 + 14,
              top: lift - 72 + sink,
              child: Container(
                width: 28,
                height: 28,
                decoration: pieceDecoration(fill: AppColors.green, radius: 999, depth: 2),
                child: const Icon(Icons.check_rounded, size: 18, color: AppColors.ink),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlinthPainter extends CustomPainter {
  _PlinthPainter({required this.color, required this.progress, required this.raised, required this.sink});
  final Color color;
  final double progress, sink;
  final bool raised;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final top = _Stop.lift + sink;
    final thick = raised ? 18.0 - sink : 4.0;
    const rx = 54.0, ry = 18.0;
    final topOval = Rect.fromCenter(center: Offset(cx, top), width: rx * 2, height: ry * 2);
    final bottomOval = topOval.shift(Offset(0, thick));
    // Drum: hard shadow, side wall, top face.
    final body = Path()
      ..addOval(bottomOval)
      ..addRect(Rect.fromLTRB(cx - rx, top, cx + rx, top + thick));
    final ink = Paint()..color = AppColors.ink;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSpace.outline
      ..color = AppColors.ink;
    if (raised) canvas.drawOval(bottomOval.shift(Offset(0, 5 - sink)), ink);
    canvas.drawPath(body, Paint()..color = raised ? side(color) : AppColors.track);
    canvas.drawOval(bottomOval, stroke);
    canvas.drawLine(Offset(cx - rx, top), Offset(cx - rx, top + thick), stroke);
    canvas.drawLine(Offset(cx + rx, top), Offset(cx + rx, top + thick), stroke);
    canvas.drawOval(topOval, Paint()..color = raised ? AppColors.tint(color, 0.45) : color);
    canvas.drawOval(topOval, stroke);
    if (!raised) return;
    // Progress ring set into the top face: ink groove, white track, coloured arc.
    final ring = topOval.deflate(7);
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..color = AppColors.ink;
    canvas.drawOval(ring, groove);
    canvas.drawOval(
      ring,
      groove
        ..strokeWidth = 4.5
        ..color = AppColors.card,
    );
    if (progress > 0) {
      canvas.drawArc(
        ring,
        pi / 2,
        2 * pi * progress,
        false,
        groove
          ..color = side(color)
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_PlinthPainter old) =>
      old.color != color || old.progress != progress || old.raised != raised || old.sink != sink;
}

/// The player's pawn. Hops from the previous stop to the current one with a bouncy spring, then bobs.
class _Pawn extends StatefulWidget {
  const _Pawn({required this.from, required this.to});
  final Offset from, to;

  @override
  State<_Pawn> createState() => _PawnState();
}

class _PawnState extends State<_Pawn> with TickerProviderStateMixin {
  static const _size = Size(36, 52);
  // Softer than AppMotion.bouncy so the hop reads as a hop, with a visible landing bounce.
  static const _spring = SpringDescription(mass: 1, stiffness: 90, damping: 9);
  late final _hop = AnimationController.unbounded(vsync: this);
  late final _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _go();
    }
  }

  @override
  void didUpdateWidget(_Pawn old) {
    super.didUpdateWidget(old);
    if (old.to != widget.to) _go();
  }

  void _go() {
    if (context.reduceMotion) {
      _hop.value = 1;
      _bob.stop();
      return;
    }
    _hop.value = 0;
    _bob.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      Sound.play(Sfx.jump, volume: 0.5);
      _hop.animateWith(SpringSimulation(_spring, 0, 1, 0));
    });
  }

  @override
  void dispose() {
    _hop.dispose();
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Speaker.of('you').color;
    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: Listenable.merge([_hop, _bob]),
            builder: (_, _) {
              final p = _hop.value;
              final ground = Offset.lerp(widget.from, widget.to, p)!;
              final air = sin(pi * p.clamp(0.0, 1.0)) * 90 + Curves.easeInOut.transform(_bob.value) * 4;
              // Squash a little when the spring pushes past the landing point.
              final squash = 1 - (p - 1).clamp(0.0, 0.2);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Hard shadow stays on the ground and shrinks as the pawn rises.
                  Positioned(
                    left: ground.dx - 14 * (1 - air / 180),
                    top: ground.dy - 4,
                    child: Container(
                      width: 28 * (1 - air / 180),
                      height: 9,
                      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(99)),
                    ),
                  ),
                  Positioned(
                    left: ground.dx - _size.width / 2,
                    top: ground.dy - _size.height - air + 2,
                    child: Transform(
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.diagonal3Values(2 - squash, squash, 1),
                      child: CustomPaint(size: _size, painter: PawnPainter(color)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
