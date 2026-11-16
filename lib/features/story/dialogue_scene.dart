import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'story_art.dart';
import 'story_data.dart';

/// Full-screen visual-novel scene on a paper-cutout diorama. Tap finishes the typing, tap again advances.
/// Pops true when the last line is done or the player skips; false when closed.
class DialogueScene extends ConsumerStatefulWidget {
  const DialogueScene({super.key, required this.node, required this.chapter});
  final StoryNode node;
  final Chapter chapter;

  @override
  ConsumerState<DialogueScene> createState() => _DialogueSceneState();
}

class _DialogueSceneState extends ConsumerState<DialogueScene> with SingleTickerProviderStateMixin {
  late final _typing = AnimationController(vsync: this)..addListener(_tick);
  int _i = 0, _ticks = 0;
  bool _started = false;
  Offset _lean = Offset.zero; // pointer position, -1..1 from the centre

  List<DialogueLine> get _lines => widget.node.lines;
  String get _text => _lines[_i].text.replaceAll('{name}', ref.read(profileProvider).name);
  int get _shown => (_text.characters.length * _typing.value).round();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _startLine();
    }
  }

  void _startLine() {
    _ticks = 0;
    if (context.reduceMotion) {
      _typing.value = 1;
    } else {
      _typing.duration = Duration(milliseconds: 24 * _text.characters.length);
      _typing.forward(from: 0);
    }
  }

  // A soft tick every few characters, not every one.
  void _tick() {
    if (!_typing.isAnimating) return;
    final n = _shown ~/ 5;
    if (n > _ticks) {
      _ticks = n;
      Sound.play(Sfx.tick, volume: 0.25);
    }
  }

  void _tap() {
    if (_typing.isAnimating) {
      _typing.value = 1;
    } else if (_i == _lines.length - 1) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _i++);
      _startLine();
    }
  }

  void _look(Offset global) {
    if (context.reduceMotion) return;
    final size = MediaQuery.sizeOf(context);
    setState(
      () => _lean = Offset(
        (global.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
        (global.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
      ),
    );
  }

  @override
  void dispose() {
    _typing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = _lines[_i];
    final sp = Speaker.of(line.speaker);
    final name = line.speaker == 'you' ? ref.watch(profileProvider).name : sp.name;
    final narrator = sp.name.isEmpty;
    final right = line.speaker == 'you';
    final palette = _Palette.of(widget.chapter.color);
    final text = _text;
    final calm = context.reduceMotion;

    final words = AnimatedBuilder(
      animation: _typing,
      builder: (context, _) {
        final chars = text.characters;
        final shown = _shown;
        final style = narrator
            ? context.text.bodyLarge!.copyWith(fontSize: 18, fontStyle: FontStyle.italic)
            : context.text.bodyLarge!.copyWith(fontSize: 19, height: 1.45);
        // The hidden remainder keeps the bubble at full size, so it doesn't grow while typing.
        return Text.rich(
          TextSpan(
            style: style,
            children: [
              TextSpan(text: chars.take(shown).toString()),
              TextSpan(
                text: chars.skip(shown).toString(),
                style: const TextStyle(color: Colors.transparent),
              ),
            ],
          ),
          textAlign: narrator ? TextAlign.center : TextAlign.start,
          semanticsLabel: '${narrator ? '' : '$name: '}$text',
        );
      },
    );

    return Scaffold(
      backgroundColor: palette.sky,
      body: Semantics(
        button: true,
        label: 'Tap to continue',
        child: MouseRegion(
          onHover: (e) => _look(e.position),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _look(d.globalPosition),
            onTap: _tap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _Diorama(palette: palette, lean: calm ? Offset.zero : _lean),
                SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: AppSpace.maxWidth),
                      child: Column(
                        children: [
                          _topBar(context, palette),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.sm),
                            child: narrator
                                ? _pop(calm, Alignment.center, _caption(words))
                                : Column(
                                    crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      _bust(line.speaker, sp, calm),
                                      _pop(
                                        calm,
                                        right ? Alignment.topRight : Alignment.topLeft,
                                        _Bubble(name: name, color: sp.color, right: right, child: words),
                                      ),
                                    ],
                                  ),
                          ),
                          _hint(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Each line's bubble pops in from its tail.
  Widget _pop(bool calm, Alignment from, Widget child) => AnimatedSwitcher(
    duration: calm ? Duration.zero : const Duration(milliseconds: 300),
    switchInCurve: Curves.easeOutBack,
    layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
    transitionBuilder: (child, a) =>
        ScaleTransition(scale: Tween(begin: 0.7, end: 1.0).animate(a), alignment: from, child: child),
    child: KeyedSubtree(key: ValueKey(_i), child: child),
  );

  /// The speaker rises from behind the bubble when they take over.
  Widget _bust(String id, Speaker sp, bool calm) {
    final who = switch (id) {
      'asha' => Cast.asha,
      'kabir' => Cast.kabir,
      _ => Cast.you,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipRect(
        child: SizedBox(
          width: 120,
          height: 128,
          child: AnimatedSwitcher(
            duration: calm ? Duration.zero : const Duration(milliseconds: 380),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (child, a) => SlideTransition(
              position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(a),
              child: child,
            ),
            child: _Bob(
              key: ValueKey(id),
              child: AnimatedBuilder(
                animation: _typing,
                builder: (_, _) => CustomPaint(
                  size: const Size(120, 128),
                  painter: BustPainter(who, sp.color, talking: _typing.isAnimating && (_shown ~/ 3).isOdd),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, _Palette palette) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpace.sm, AppSpace.sm, AppSpace.sm, 0),
    child: Column(
      children: [
        Row(
          children: [
            _SmallPiece(
              label: 'Close',
              onTap: () => Navigator.of(context).pop(false),
              child: const Icon(Icons.close_rounded, color: AppColors.ink),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: FatProgress(value: (_i + 1) / _lines.length, color: widget.chapter.color, height: 14),
            ),
            const SizedBox(width: AppSpace.sm),
            _SmallPiece(
              label: 'Skip',
              onTap: () => Navigator.of(context).pop(true),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Skip', style: context.text.titleSmall),
                  const Icon(Icons.fast_forward_rounded, size: 18, color: AppColors.ink),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: pieceDecoration(fill: AppColors.card, radius: 999, depth: 3),
          child: Text(
            widget.node.title.toUpperCase(),
            textAlign: TextAlign.center,
            style: context.text.labelSmall!.copyWith(color: AppColors.ink, letterSpacing: 1.5),
          ),
        ),
      ],
    ),
  );

  Widget _caption(Widget words) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpace.lg),
    decoration: pieceDecoration(fill: AppColors.tint(AppColors.yellow, 0.55), radius: 6),
    child: words,
  );

  Widget _hint(BuildContext context) => SizedBox(
    height: 44,
    child: Center(
      child: AnimatedBuilder(
        animation: _typing,
        builder: (context, _) => AnimatedOpacity(
          opacity: _typing.isAnimating ? 0 : 1,
          duration: AppMotion.fast,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: pieceDecoration(fill: AppColors.card, radius: 999, depth: 0),
            child: Text(
              _i == _lines.length - 1 ? 'Tap to finish  ✓' : 'Tap to continue  ▾',
              style: context.text.labelSmall!.copyWith(color: AppColors.ink, letterSpacing: 1),
            ),
          ),
        ),
      ),
    ),
  );
}

/// A small outlined button that sinks on touch-down. 48px tall.
class _SmallPiece extends StatelessWidget {
  const _SmallPiece({required this.label, required this.onTap, required this.child});
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Pressable(
    label: label,
    onTap: onTap,
    builder: (_, down) => SizedBox(
      height: 48,
      child: Align(
        alignment: Alignment.topCenter,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          transform: Matrix4.translationValues(0, down ? 4 : 0, 0),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: pieceDecoration(radius: 12, depth: down ? 0 : 4),
          child: child,
        ),
      ),
    ),
  );
}

/// Comic speech bubble: white, ink outline, hard shadow, a tail up at the speaker and a name tab.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.name, required this.color, required this.right, required this.child});
  final String name;
  final Color color;
  final bool right;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _BubblePainter(right: right)),
        ),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 110),
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
          child: child,
        ),
        Positioned(
          top: -16,
          left: right ? null : 150,
          right: right ? 150 : null,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: pieceDecoration(fill: color, radius: 8, depth: 3),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleMedium!.copyWith(color: AppColors.on(color)),
            ),
          ),
        ),
      ],
    ),
  );
}

class _BubblePainter extends CustomPainter {
  _BubblePainter({required this.right});
  final bool right;

  @override
  void paint(Canvas canvas, Size size) {
    // Tail sits under the bust's chin (bust is 120 wide with 12 padding, so its centre is 72 in).
    final x = right ? size.width - 72 : 72.0;
    final body = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(22)));
    final tail = Path()
      ..moveTo(x - 16, 2)
      ..lineTo(x + (right ? 4 : -4), -20)
      ..lineTo(x + 14, 2)
      ..close();
    piece(canvas, Path.combine(PathOperation.union, body, tail), AppColors.card, shadow: 6);
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.right != right;
}

/// Gentle idle bob for the speaking character. Still when animations are off.
class _Bob extends StatefulWidget {
  const _Bob({super.key, required this.child});
  final Widget child;

  @override
  State<_Bob> createState() => _BobState();
}

class _BobState extends State<_Bob> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

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
    builder: (_, child) =>
        Transform.translate(offset: Offset(0, 6 - 6 * Curves.easeInOut.transform(_c.value)), child: child),
    child: widget.child,
  );
}

/// Solid shades for one chapter's backdrop, all derived from the theme tokens.
class _Palette {
  const _Palette({
    required this.sky,
    required this.cloud,
    required this.far,
    required this.near,
    required this.ground,
    this.hills = false,
  });
  final Color sky, cloud, far, near, ground;
  final bool hills; // the zoo has hills and trees instead of a skyline

  static _Palette of(Color chapter) {
    if (chapter == AppColors.yellow || chapter == AppColors.orange) {
      // Dusk in the city.
      return _Palette(
        sky: AppColors.tint(AppColors.orange, 0.5),
        cloud: AppColors.tint(AppColors.yellow, 0.6),
        far: Color.lerp(AppColors.orange, AppColors.red, 0.55)!,
        near: Color.lerp(AppColors.red, AppColors.ink, 0.55)!,
        ground: Color.lerp(AppColors.orange, AppColors.ink, 0.3)!,
      );
    }
    if (chapter == AppColors.green) {
      // A sunny day at the zoo.
      return _Palette(
        sky: AppColors.tint(AppColors.teal, 0.62),
        cloud: AppColors.card,
        far: AppColors.tint(AppColors.green, 0.3),
        near: Color.lerp(AppColors.green, AppColors.ink, 0.35)!,
        ground: AppColors.tint(AppColors.yellow, 0.35),
        hills: true,
      );
    }
    // Calm blue morning.
    return _Palette(
      sky: AppColors.tint(AppColors.blue, 0.65),
      cloud: AppColors.card,
      far: AppColors.tint(AppColors.blue, 0.25),
      near: Color.lerp(AppColors.blue, AppColors.ink, 0.5)!,
      ground: Color.lerp(AppColors.teal, AppColors.ink, 0.25)!,
    );
  }
}

enum _Layer { sky, far, near, ground }

/// Four cut-paper layers that slide against each other a few pixels as the pointer moves.
class _Diorama extends StatelessWidget {
  const _Diorama({required this.palette, required this.lean});
  final _Palette palette;
  final Offset lean;

  static const _depth = {_Layer.sky: 2.0, _Layer.far: 5.0, _Layer.near: 9.0, _Layer.ground: 14.0};

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: TweenAnimationBuilder<Offset>(
      tween: Tween(end: lean),
      duration: const Duration(milliseconds: 500),
      curve: AppMotion.curve,
      builder: (_, l, _) => Stack(
        children: [
          for (final layer in _Layer.values)
            Positioned(
              left: -20,
              right: -20,
              top: -20,
              bottom: -20,
              child: Transform.translate(
                offset: -l * _depth[layer]!,
                // Each layer paints once; only its offset changes.
                child: RepaintBoundary(child: CustomPaint(painter: _LayerPainter(layer, palette))),
              ),
            ),
        ],
      ),
    ),
  );
}

class _LayerPainter extends CustomPainter {
  _LayerPainter(this.layer, this.p);
  final _Layer layer;
  final _Palette p;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final horizon = h * 0.64;
    final rng = Random(layer.index + 11);
    switch (layer) {
      case _Layer.sky:
        canvas.drawRect(Offset.zero & size, Paint()..color = p.sky);
        piece(
          canvas,
          Path()..addOval(Rect.fromCircle(center: Offset(w * 0.78, h * 0.2), radius: 38)),
          AppColors.yellow,
        );
        for (final (cx, cy, s) in [(w * 0.22, h * 0.16, 1.0), (w * 0.6, h * 0.3, 0.75)]) {
          final cloud = Path.combine(
            PathOperation.union,
            Path()..addRRect(RRect.fromLTRBR(cx - 50 * s, cy, cx + 50 * s, cy + 22 * s, Radius.circular(11 * s))),
            Path()..addOval(Rect.fromCircle(center: Offset(cx - 8 * s, cy + 2 * s), radius: 22 * s)),
          );
          piece(canvas, cloud, p.cloud);
        }
      case _Layer.far:
        var path = Path()..moveTo(0, horizon + 4);
        if (p.hills) {
          // Rolling hills topped with round trees.
          double hill(double x) => horizon - 100 - 45 * sin(x / w * 2 * pi * 1.3 + 0.6);
          for (var x = 0.0; x <= w + 8; x += 8) {
            path.lineTo(x, hill(x));
          }
          path
            ..lineTo(w + 8, horizon + 4)
            ..close();
          for (var x = 24.0; x < w; x += 60 + rng.nextDouble() * 50) {
            final r = 14 + rng.nextDouble() * 8;
            final tree = Path()..addOval(Rect.fromCircle(center: Offset(x, hill(x) - r * 0.6), radius: r));
            path = Path.combine(PathOperation.union, path, tree);
          }
        } else {
          // Skyline of flat-topped towers, a few with an antenna.
          var x = 0.0;
          while (x < w) {
            final bw = 30 + rng.nextDouble() * 40;
            final top = horizon - 120 - rng.nextDouble() * 170;
            path.lineTo(x, top);
            if (rng.nextDouble() < 0.3) {
              path
                ..lineTo(x + bw / 2 - 2, top)
                ..lineTo(x + bw / 2 - 2, top - 26)
                ..lineTo(x + bw / 2 + 2, top - 26)
                ..lineTo(x + bw / 2 + 2, top);
            }
            path.lineTo(x + bw, top);
            x += bw;
          }
          path
            ..lineTo(x, horizon + 4)
            ..close();
        }
        piece(canvas, path, p.far);
      case _Layer.near:
        final lit = Paint()..color = AppColors.yellow;
        final dark = Paint()..color = Color.lerp(p.near, AppColors.ink, 0.35)!;
        final thin = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.ink;
        var x = -10.0;
        while (x < w) {
          final bw = 56 + rng.nextDouble() * 50;
          final bh = 70 + rng.nextDouble() * 110;
          final r = Rect.fromLTWH(x, horizon - bh, bw, bh + 4);
          piece(canvas, Path()..addRect(r), p.near);
          // Roof ledge.
          piece(canvas, Path()..addRect(Rect.fromLTWH(r.left - 3, r.top - 6, bw + 6, 8)), p.near);
          for (var wy = r.top + 14; wy < horizon - 18; wy += 22) {
            for (var wx = r.left + 10; wx < r.right - 16; wx += 18) {
              final win = Rect.fromLTWH(wx, wy, 9, 12);
              final on = rng.nextDouble() < 0.18;
              canvas.drawRect(win, on ? lit : dark);
              if (on) canvas.drawRect(win, thin);
            }
          }
          x += bw + 8;
        }
      case _Layer.ground:
        piece(canvas, Path()..addRect(Rect.fromLTRB(-4, horizon, w + 4, h + 4)), p.ground);
        // Kerb line and paving marks give the ground some depth.
        final mark = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = AppSpace.outline
          ..color = Color.lerp(p.ground, AppColors.ink, 0.25)!;
        canvas.drawLine(Offset(0, horizon + 14), Offset(w, horizon + 14), mark);
        for (var x = 20.0; x < w; x += 64) {
          canvas.drawLine(Offset(x, horizon + 34), Offset(x + 26, horizon + 34), mark);
        }
    }
  }

  @override
  bool shouldRepaint(_LayerPainter old) => old.layer != layer || old.p.sky != p.sky;
}
